"""Pruebas de seguridad e integridad de la base local SQLite.

Uso:  python3 db/test_seguridad_sqlite.py
"""
import pathlib
import sqlite3
import uuid

AQUI = pathlib.Path(__file__).parent
ok = fallos = 0


def caso(desc, fn, espera_error):
    global ok, fallos
    try:
        fn()
        paso = not espera_error
        obtenido = "permitido"
    except sqlite3.DatabaseError as e:
        paso = espera_error
        obtenido = f"bloqueado ({e.__class__.__name__}: {e})"
    print(f"  {'✓' if paso else '✗'} {desc}  [{obtenido}]")
    if paso:
        ok += 1
    else:
        fallos += 1


def main():
    db = sqlite3.connect(":memory:")
    db.executescript((AQUI / "schema.sql").read_text(encoding="utf-8"))
    u = lambda: str(uuid.uuid4())
    yo, rv, j = u(), u(), u()
    db.execute("INSERT INTO equipos(id,nombre,es_propio) VALUES (?,?,1)", (yo, "Halcones FC"))
    db.execute("INSERT INTO equipos(id,nombre) VALUES (?,?)", (rv, "Real Arenal"))
    db.execute("INSERT INTO jugadores(id,equipo_id,nombre,dorsal,posicion) VALUES (?,?,?,?,?)", (j, yo, "Marco Rivas", 9, "DEL"))
    pid = u()
    db.execute("INSERT INTO partidos(id,equipo_id,rival_id,fecha_hora) VALUES (?,?,?,?)", (pid, yo, rv, "2026-11-22T17:00:00Z"))

    print("\n1 · Inyección SQL (consultas parametrizadas, como las usa drift)")
    malicioso = "Robert'); DROP TABLE partidos; --"
    caso("Nombre malicioso se guarda como texto", lambda: db.execute(
        "INSERT INTO jugadores(id,equipo_id,nombre) VALUES (?,?,?)", (u(), yo, malicioso)), False)
    caso("La tabla partidos sigue existiendo", lambda: db.execute("SELECT 1 FROM partidos").fetchone() or (_ for _ in ()).throw(sqlite3.DatabaseError("no existe")), False)
    guardado = db.execute("SELECT nombre FROM jugadores WHERE nombre=?", (malicioso,)).fetchone()[0]
    caso("El texto quedó idéntico, sin interpretarse", lambda: None if guardado == malicioso else (_ for _ in ()).throw(sqlite3.DatabaseError("cambió")), False)
    caso("Búsqueda con comodín malicioso no devuelve todo", lambda: None if db.execute(
        "SELECT COUNT(*) FROM jugadores WHERE nombre = ?", ("' OR '1'='1",)).fetchone()[0] == 0 else (_ for _ in ()).throw(sqlite3.DatabaseError("devolvió filas")), False)

    print("\n2 · Datos inválidos que la base debe rechazar")
    caso("Goles negativos", lambda: db.execute("UPDATE partidos SET goles_favor=-1 WHERE id=?", (pid,)), True)
    caso("Finalizar partido sin marcador", lambda: db.execute("UPDATE partidos SET estado='FINALIZADO' WHERE id=?", (pid,)), True)
    caso("Estado inventado", lambda: db.execute("UPDATE partidos SET estado='HACKEADO' WHERE id=?", (pid,)), True)
    caso("Partido contra sí mismo", lambda: db.execute("INSERT INTO partidos(id,equipo_id,rival_id,fecha_hora) VALUES (?,?,?,?)", (u(), yo, yo, "2026-11-22")), True)
    caso("Minuto negativo en evento", lambda: db.execute("INSERT INTO eventos(id,partido_id,tipo,minuto) VALUES (?,?,?,?)", (u(), pid, "GOL", -5)), True)
    caso("Tipo de evento inventado", lambda: db.execute("INSERT INTO eventos(id,partido_id,tipo,minuto) VALUES (?,?,?,?)", (u(), pid, "BORRAR_TODO", 5)), True)
    caso("Evento de un partido que no existe", lambda: db.execute("INSERT INTO eventos(id,partido_id,tipo,minuto) VALUES (?,?,?,?)", (u(), u(), "GOL", 5)), True)
    caso("Jugador de un equipo que no existe", lambda: db.execute("INSERT INTO jugadores(id,equipo_id,nombre) VALUES (?,?,?)", (u(), u(), "X")), True)
    caso("Posición inventada", lambda: db.execute("INSERT INTO jugadores(id,equipo_id,nombre,posicion) VALUES (?,?,?,?)", (u(), yo, "X", "CAPITAN")), True)
    caso("Coordenadas de sede fuera de rango", lambda: db.execute("INSERT INTO sedes(id,nombre,latitud) VALUES (?,?,?)", (u(), "X", 200)), True)
    caso("Respuesta de convocatoria inventada", lambda: db.execute("INSERT INTO convocatorias(id,partido_id,jugador_id,respuesta) VALUES (?,?,?,?)", (u(), pid, j, "SIEMPRE")), True)
    caso("Convocatoria duplicada del mismo jugador", lambda: [db.execute("INSERT INTO convocatorias(id,partido_id,jugador_id) VALUES (?,?,?)", (u(), pid, j)) for _ in range(2)], True)
    caso("Calificación fuera de 1–10", lambda: db.execute("INSERT INTO alineaciones(id,partido_id,jugador_id,calificacion) VALUES (?,?,?,?)", (u(), pid, j, 99)), True)

    print("\n3 · Integridad al borrar")
    db.execute("INSERT INTO eventos(id,partido_id,tipo,minuto,jugador_id) VALUES (?,?,?,?,?)", (u(), pid, "GOL", 10, j))
    caso("No se puede borrar un jugador con goles registrados", lambda: db.execute("DELETE FROM jugadores WHERE id=?", (j,)), True)
    db.execute("DELETE FROM partidos WHERE id=?", (pid,))
    huerfanos = db.execute("SELECT COUNT(*) FROM eventos WHERE partido_id=?", (pid,)).fetchone()[0]
    caso("Al borrar un partido no quedan eventos huérfanos", lambda: None if huerfanos == 0 else (_ for _ in ()).throw(sqlite3.DatabaseError(f"{huerfanos} huérfanos")), False)

    print(f"\n{ok}/{ok+fallos} pruebas pasaron.")
    raise SystemExit(1 if fallos else 0)


if __name__ == "__main__":
    main()
