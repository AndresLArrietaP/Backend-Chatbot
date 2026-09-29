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
    print(f"\n{total} vistas revisadas, {con_fallo} con problemas")
    return 1 if con_fallo else 0


if __name__ == "__main__":
    sys.exit(main())
