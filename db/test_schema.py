"""Prueba rápida del esquema y las consultas de análisis.

Uso:  python3 db/test_schema.py
Crea una base en memoria, carga datos de ejemplo (la temporada de los mockups)
y ejecuta cada consulta de consultas_analisis.sql.
"""
import pathlib
import re
import sqlite3
import uuid

AQUI = pathlib.Path(__file__).parent


def uid():
    return str(uuid.uuid4())


def cargar_ejemplo(db):
    hf, ra, dc, un, av = uid(), uid(), uid(), uid(), uid()
    db.executemany("INSERT INTO equipos(id,nombre,es_propio) VALUES (?,?,?)", [
        (hf, "Halcones FC", 1), (ra, "Real Arenal", 0), (dc, "Deportivo Costa", 0),
        (un, "Unión Norte", 0), (av, "Atlético Valle", 0)])
    comp, temp = uid(), uid()
    db.execute("INSERT INTO competiciones(id,nombre,tipo) VALUES (?,?,'LIGA')", (comp, "Liga Municipal"))
    db.execute("INSERT INTO temporadas(id,competicion_id,nombre) VALUES (?,?,?)", (temp, comp, "Apertura 2026"))
    norte, palmas = uid(), uid()
    db.execute("INSERT INTO sedes(id,nombre,cancha,superficie,latitud,longitud) VALUES (?,?,?,?,?,?)",
               (norte, "Unidad Deportiva Norte", "Cancha 3", "NATURAL", 32.53, -117.02))
    db.execute("INSERT INTO sedes(id,nombre,superficie) VALUES (?,?,?)", (palmas, "Campo Las Palmas", "SINTETICO"))

    jug = {n: uid() for n in ["Rivas", "Mora", "Pérez", "Salas", "Luna"]}
    for i, (n, j) in enumerate(jug.items()):
        db.execute("INSERT INTO jugadores(id,equipo_id,nombre,dorsal,posicion) VALUES (?,?,?,?,?)",
                   (j, hf, n, 9 + i, "DEL" if i < 3 else "DEF"))

    rivales = [av, dc, un, ra]
    # J1..J12: G E G P G E G G G P E G  -> 7G 3E 2P, 24 pts, GF 26, GC 13
    marcadores = [(3, 1), (1, 1), (3, 0), (0, 2), (3, 1), (2, 2), (3, 1), (3, 1), (3, 0), (0, 1), (2, 2), (3, 1)]
    partidos = []
    for k, (gf, gc) in enumerate(marcadores, start=1):
        pid = uid()
        rival = ra if k == 12 else (dc if k == 11 else (un if k == 10 else rivales[k % 4]))
        fecha = f"2026-{9 + (k - 1) // 4:02d}-{1 + ((k - 1) % 4) * 7:02d}T17:00:00Z"
        db.execute("""INSERT INTO partidos(id,equipo_id,rival_id,temporada_id,sede_id,fecha_hora,es_local,
                      jornada,estado,goles_favor,goles_contra) VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                   (pid, hf, rival, temp, norte if k % 2 else palmas, fecha, k % 2, f"J{k}",
                    "FINALIZADO", gf, gc))
        partidos.append(pid)
        for n in ("Rivas", "Mora", "Salas", "Luna"):
            db.execute("INSERT INTO alineaciones(id,partido_id,jugador_id,titular) VALUES (?,?,?,1)",
                       (uid(), pid, jug[n]))
        goleadores = ["Rivas", "Mora", "Pérez", "Rivas"]
        for g in range(gf):
            db.execute("""INSERT INTO eventos(id,partido_id,tipo,minuto,jugador_id,asistente_id)
                          VALUES (?,?,'GOL',?,?,?)""",
                       (uid(), pid, 10 + g * 25 % 80, jug[goleadores[g % 4]], jug["Mora"] if g == 0 else None))
        for g in range(gc):
            db.execute("INSERT INTO eventos(id,partido_id,tipo,minuto,es_rival,jugador_rival) VALUES (?,?,'GOL',?,1,'Rival')",
                       (uid(), pid, 80 + g))
    # partido programado (no debe contar)
    db.execute("""INSERT INTO partidos(id,equipo_id,rival_id,temporada_id,sede_id,fecha_hora,jornada)
                  VALUES (?,?,?,?,?,?,?)""", (uid(), hf, av, temp, norte, "2026-11-22T18:00:00Z", "J13"))
    return dict(equipo=hf, temporada=temp, rival=ra, jugador=jug["Rivas"])


def consultas(texto):
    for bloque in re.split(r"^-- name: ", texto, flags=re.M)[1:]:
        nombre, _, sql = bloque.partition("\n")
        sql = "\n".join(l for l in sql.splitlines() if not l.startswith("--")).strip()
        yield nombre.strip(), sql


def main():
    db = sqlite3.connect(":memory:")
    db.executescript((AQUI / "schema.sql").read_text(encoding="utf-8"))
    params = cargar_ejemplo(db)

    resumen = db.execute("SELECT pj,g,e,p,gf,gc,dg,pts,pct_victorias FROM v_resumen_temporada").fetchone()
    print("Resumen temporada:", resumen)
    assert resumen == (12, 7, 3, 2, 26, 13, 13, 24, 58.3), resumen

    # trigger de versión
    pid = db.execute("SELECT id FROM partidos WHERE jornada='J12'").fetchone()[0]
    db.execute("UPDATE partidos SET notas='Buen partido' WHERE id=?", (pid,))
    assert db.execute("SELECT version FROM partidos WHERE id=?", (pid,)).fetchone()[0] == 2

    # restricción: FINALIZADO sin marcador debe fallar
    try:
        db.execute("UPDATE partidos SET estado='FINALIZADO' WHERE jornada='J13'")
        raise AssertionError("debió fallar")
    except sqlite3.IntegrityError:
        pass

    for nombre, sql in consultas((AQUI / "consultas_analisis.sql").read_text(encoding="utf-8")):
        usados = set(re.findall(r":(\w+)", sql))
        filas = db.execute(sql, {k: params[k] for k in usados}).fetchall()
        assert filas, f"{nombre} sin resultados"
        print(f"\n[{nombre}]")
        for f in filas[:6]:
            print("  ", f)
    print("\nOK: esquema y consultas funcionan.")


if __name__ == "__main__":
    main()
