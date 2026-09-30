"""Verifica DDL_vistas.sql antes de mandarlo a SSMS.

    python tools/check_ddl.py

No reemplaza al smoke test (BLOQUE 89): SQL Server guarda una vista aunque su cuerpo
sea invalido, y hay errores que solo salen al consultarla. Esto ataca la otra mitad —
los que revientan al DESPLEGAR y cuestan una ronda entera de ida y vuelta:

  Msg 102 «Incorrect syntax near '('»  -> a una tupla de VALUES le falta la coma
  Msg 102 «Incorrect syntax near ','»  -> a la ultima tupla le sobra la coma
  parentesis desbalanceados en una linea de tupla o en el cuerpo de la vista

Los tres aparecieron al ampliar listas de VALUES a mano (bloque D, 28/09): se pega una
entrada detras de la ultima, que no llevaba coma, y el error sale 10 lineas mas abajo.
"""
import pathlib
import re
import sys

DDL = pathlib.Path(__file__).resolve().parent.parent / "docs" / "arquitectura" / "DDL_vistas.sql"


def vistas(texto):
    """(nombre, cuerpo) de cada CREATE OR ALTER VIEW, hasta su GO."""
    for m in re.finditer(r"CREATE OR ALTER VIEW \[dbo\]\.\[(\w+)\]", texto):
        cuerpo = texto[m.start():]
        corte = cuerpo.find("\nGO")
        yield m.group(1), cuerpo[: corte if corte > 0 else len(cuerpo)]


def revisar(nombre, cuerpo):
    fallos = []
    if cuerpo.count("(") != cuerpo.count(")"):
        fallos.append(f"parentesis desbalanceados en la vista ({cuerpo.count('(')} abren, {cuerpo.count(')')} cierran)")

    lineas = cuerpo.split("\n")
    for i, linea in enumerate(lineas):
        s = linea.strip()
        if not s.startswith("(N'"):
            continue
        sig = lineas[i + 1].strip() if i + 1 < len(lineas) else ""
        if s.count("(") != s.count(")"):
            fallos.append(f"tupla con parentesis desbalanceados: {s[:60]}")
        if sig.startswith("(N'") and not s.endswith(","):
            fallos.append(f"falta la coma: {s[:60]}")
        if sig.startswith(")") and not sig.startswith("(N'") and s.endswith(","):
            fallos.append(f"sobra la coma: {s[:60]}")
    return fallos


def cte_multiples_lecturas(texto, umbral=2):
    """Cuenta cuantas veces se referencia cada CTE dentro de su propia vista.

    Los CTE de SQL Server NO se materializan: cada referencia se RE-EJECUTA, y con ella
    toda la cadena de vistas de la que cuelga. Es el anti-patron nº1 del proyecto: es lo
    que llevo vw_TriageMD a 113 780 ms y vw_DiagnosticoMD a 348 s (6 lecturas de 'base' =
    7 scans de LaboratoryData).

    ⚠ No es un error por si mismo -- a veces el optimizador hace spool y no cuesta nada --
    pero es SIEMPRE el primer sitio donde mirar cuando una vista va lenta. Por eso esto
    informa, no falla: la decision necesita una medicion, no una regla.
    """
    aviso = []
    for nombre, cuerpo in vistas(texto):
        limpio = re.sub(r"/\*.*?\*/", " ", cuerpo, flags=re.S)
        limpio = "\n".join(l for l in limpio.split("\n") if not l.strip().startswith("--"))
        for cte in re.findall(r"^(\w+) AS \(", limpio, re.M):
            n = len(re.findall(rf"\b(?:FROM|JOIN)\s+{cte}\b", limpio))
            if n >= umbral:
                aviso.append((nombre, cte, n))
    return aviso


def catalogo_vs_celdas(texto):
    """El unpivot de vw_DiagnosticoMD une el catalogo por Parametro con INNER JOIN.

    Si un parametro del catalogo '(CRUZADO)' no esta en la lista de celdas, su fila
    DESAPARECE de /diagcompleto sin ruido: ni error, ni hueco, simplemente no sale.
    Es la contrapartida de la cura de rendimiento del 28/09 (antes el catalogo mandaba
    y la celda faltante salia como guion). Compara las dos listas en los dos sentidos.
    """
    cat = set(re.findall(r"\(N'\(CRUZADO\)', N'([^']+)'", texto))
    md = texto[texto.index("CREATE OR ALTER VIEW [dbo].[vw_DiagnosticoMD]"):]
    md = md[: md.index("\nGO")]
    unpv = md[md.index("CROSS APPLY (VALUES"):]
    unpv = unpv[: unpv.index(") v(Parametro, cell")]
    celdas = set(re.findall(r"\(N'([^']+)',", unpv))

    fallos = []
    for q in sorted(cat - celdas):
        fallos.append(f"'{q}' esta en el catalogo y NO en las celdas -> su fila no saldra")
    for q in sorted(celdas - cat):
        fallos.append(f"'{q}' esta en las celdas y NO en el catalogo -> se calcula y se tira")
    return len(cat), len(celdas), fallos


VALID = pathlib.Path(__file__).resolve().parent.parent / "docs" / "arquitectura" / "VALIDACION_SSMS.sql"

# Vistas que SI existen en la base pero NO se versionan aqui: son del dashboard del area. Sin esta
# lista el control gritaria en falso, y un control que grita en falso se termina ignorando.
EXTERNAS = {"vw_RankingHistorico", "vw_RankingAtencion"}


def _borra_comentarios(s):
    """Sustituye cada comentario por espacios, conservando el largo -- asi las posiciones (y por
    tanto los numeros de linea) siguen valiendo."""
    def blanco(m):
        return "".join(c if c == "\n" else " " for c in m.group(0))
    s = re.sub(r"/\*.*?\*/", blanco, s, flags=re.S)
    return re.sub(r"--[^\n]*", blanco, s)


def validacion_vs_ddl(texto):
    """Comprueba que VALIDACION_SSMS.sql no nombre vistas inexistentes ni pida la columna MD a una
    vista que no la proyecta.

    Existe porque el 29/09 escribi mal un nombre DOS veces seguidas: 'vw_CondicionMTMD' por
    'vw_CondicionMT_MD', y 'vw_BarridoMD', que directamente no existe (es vw_ObservadosBarridoMD).
    Lo caro no es el Msg 208 -- es que el lote SE CORTA en el error, las consultas de abajo no
    corren, y un smoke test incompleto se lee como aprobado.
    El segundo caso es el Msg 207: las vistas del contrato *FilasMD exponen HeaderMD + Fila y NO
    tienen columna MD. vw_RankingMD es una de ellas.

    Se mira sentencia a sentencia y con los comentarios borrados: un 'MD' dentro de un '--', o un
    'AS MD' que es el alias de salida, no son referencias a la columna. Y solo se juzga la
    sentencia que nombra UNA sola vista, que es donde la atribucion es inequivoca.
    """
    if not VALID.exists():
        return []
    existentes = {n for n, _ in vistas(texto)} | EXTERNAS
    con_md = {n for n, c in vistas(texto) if re.search(r"AS MD\b", c)} | EXTERNAS
    limpio = _borra_comentarios(VALID.read_text(encoding="utf-8"))
    fallos = set()

    for m in re.finditer(r"\[dbo\]\.\[(vw_\w+)\]", limpio):
        if m.group(1) not in existentes:
            fallos.add((limpio.count("\n", 0, m.start()) + 1,
                        f"[{m.group(1)}] no existe en el DDL ni es una vista externa conocida"))

    pos = 0
    for sent in limpio.split(";"):
        ini, pos = pos, pos + len(sent) + 1
        refs = set(re.findall(r"\[dbo\]\.\[(vw_\w+)\]", sent))
        if len(refs) != 1:
            continue
        vista = refs.pop()
        if vista in con_md or vista not in existentes:
            continue
        # Si la sentencia se define su PROPIO alias MD -- tipico: una subconsulta que arma el
        # MD a partir de HeaderMD + Fila y la de fuera lo mide -- el MD que usa es ese, no el
        # de la vista. Delatarlo es un falso positivo: me paso con el BLOQUE 152.1, que es
        # correcto, y al 'corregirlo' rompi una consulta que funcionaba.
        if re.search(r"\bAS\s+MD\b", sent):
            continue
        if re.search(r"\bMD\b", sent):
            fallos.add((limpio.count("\n", 0, ini) + 1,
                        f"[{vista}] existe pero NO proyecta columna MD (Msg 207)"))

    return [f"linea ~{n}: {m}" for n, m in sorted(fallos)]



def _select_final(cuerpo):
    """La region del SELECT final de una vista. En este archivo el SELECT final empieza en la
    COLUMNA 0 y los de los CTE van indentados dentro de 'WITH ... AS ('. Se toma el ultimo."""
    ini = None
    for m in re.finditer(r"(?m)^SELECT\b", cuerpo):
        ini = m.start()
    return cuerpo[ini:] if ini is not None else cuerpo


def columnas_no_expuestas(texto):
    """Delata 'alias.Columna' cuando el alias apunta a una vista de este archivo que NO expone esa
    columna en su SELECT FINAL.

    Existe porque el 29/09 anadi COUNT(Valor) AS NMuestras al CTE interno de vw_TendenciaElemento
    y la use como te.NMuestras desde vw_TendenciaGraficoMD: el SELECT final de la vista enumera
    columnas y no la incluia -> Msg 207 al desplegar, con check_ddl dando 0 problemas.
    Es el mismo Msg 207 del contrato *FilasMD, pero un nivel mas adentro: la columna EXISTE en el
    texto de la vista, solo que no sale por la puerta.
    """
    vistas_txt = dict(vistas(texto))
    expuestas = {}
    for nombre, cuerpo in vistas_txt.items():
        fin = _select_final(cuerpo)
        if re.search(r"\bSELECT\s+\w*\.?\*", fin):   # SELECT * / d.* -> no se puede saber
            expuestas[nombre] = None
        else:
            expuestas[nombre] = set(re.findall(r"\b\w+\b", fin))

    fallos = set()
    for nombre, cuerpo in vistas_txt.items():
        # alias -> origen. Se recogen TODOS los origenes (vistas y CTE) porque el mismo alias
        # corto se reutiliza dentro de una vista: 'r' apunta a vw_Recomendaciones en un sitio y a
        # un CTE 'row_all' en otro. Un alias ambiguo NO se juzga -- preferible callar que gritar
        # en falso, que es como se termina ignorando un control.
        origenes = {}
        for m in re.finditer(r"(?:FROM|JOIN|APPLY)\s+(\[dbo\]\.\[vw_\w+\]|\w+)\s+(?:AS\s+)?([a-z][a-z0-9_]{0,4})\b",
                             cuerpo, re.I):
            alias = m.group(2)
            if alias.lower() in ("as", "on", "where", "group", "order", "with", "cross", "outer", "left", "join"):
                continue
            origenes.setdefault(alias, set()).add(m.group(1))
        # una tabla derivada '( ... ) r' tambien es un origen: sin esto, un alias reutilizado entre
        # una subconsulta y una vista (vw_DiagnosticoMD con sus CTE desplegados) se leia como de la vista
        for m in re.finditer(r"\)\s+(?:AS\s+)?([a-z][a-z0-9_]{0,4})\b(?=\s*(?:\n|JOIN|ON|GROUP|WHERE|,|CROSS|OUTER|LEFT|INNER|\)))", cuerpo):
            origenes.setdefault(m.group(1), set()).add("(derivada)")
        binds = {}
        for alias, orgs in origenes.items():
            if len(orgs) != 1:
                continue
            org = next(iter(orgs))
            mm = re.fullmatch(r"\[dbo\]\.\[(vw_\w+)\]", org)
            if mm:
                binds[alias] = mm.group(1)
        for alias, destino in binds.items():
            cols = expuestas.get(destino)
            if cols is None:
                continue
            for m in re.finditer(rf"\b{re.escape(alias)}\.(\w+)", cuerpo):
                if m.group(1) not in cols:
                    fallos.add((nombre, f"{alias}.{m.group(1)} -> [{destino}] no expone '{m.group(1)}' en su SELECT final"))
    return sorted(fallos)



def main():
    if not DDL.exists():
        print(f"no encuentro {DDL}")
        return 2
    texto = DDL.read_text(encoding="utf-8")
    total, con_fallo = 0, 0
    for nombre, cuerpo in vistas(texto):
        total += 1
        fallos = revisar(nombre, cuerpo)
        if fallos:
            con_fallo += 1
            print(f"\n{nombre}")
            for f in fallos:
                print(f"   {f}")
    n_cat, n_cel, huerfanos = catalogo_vs_celdas(texto)
    if huerfanos:
        con_fallo += 1
        print("\nvw_DiagnosticoMD - catalogo vs celdas")
        for h in huerfanos:
            print(f"   {h}")
    else:
        print(f"\ncatalogo (CRUZADO) {n_cat} parametros = celdas de vw_DiagnosticoMD {n_cel}  OK")

    multiples = cte_multiples_lecturas(texto)
    if multiples:
        print("\nCTE leidos mas de una vez (informativo -- mirar aqui si una vista va lenta):")
        for vista, cte, n in sorted(multiples, key=lambda x: -x[2]):
            print(f"   {vista}.{cte}  x{n}")

    ocultas = columnas_no_expuestas(texto)
    if ocultas:
        con_fallo += 1
        print("\nColumnas usadas que la vista de origen NO expone (Msg 207 al desplegar):")
        for vista, msg in ocultas:
            print(f"   {vista}: {msg}")

    malas = validacion_vs_ddl(texto)
    if malas:
        con_fallo += 1
        print("\nVALIDACION_SSMS.sql nombra vistas que no cuadran con el DDL:")
        for m in malas:
            print(f"   {m}")

    print(f"\n{total} vistas revisadas, {con_fallo} con problemas")
    return 1 if con_fallo else 0


if __name__ == "__main__":
    sys.exit(main())
