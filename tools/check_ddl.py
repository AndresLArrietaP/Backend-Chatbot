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

    print(f"\n{total} vistas revisadas, {con_fallo} con problemas")
    return 1 if con_fallo else 0


if __name__ == "__main__":
    sys.exit(main())
