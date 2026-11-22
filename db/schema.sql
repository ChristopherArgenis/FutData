-- =====================================================================
-- FutData · Esquema SQLite local (fuente de verdad en el dispositivo)
-- Versión de esquema: 1
--
-- Convenciones
--  * id TEXT = UUID v7 generado en el dispositivo (evita choques al sincronizar).
--  * Fechas en texto ISO-8601 UTC ('2026-11-22T16:00:00Z').
--  * Todas las tablas sincronizables llevan:
--      creado_en, actualizado_en, eliminado_en (borrado suave), version.
--  * El mismo modelo se replica en Postgres (Supabase) para usuarios Premium.
-- =====================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- ---------------------------------------------------------------------
-- Catálogos
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS equipos (
  id              TEXT PRIMARY KEY,
  nombre          TEXT NOT NULL,
  nombre_corto    TEXT,
  es_propio       INTEGER NOT NULL DEFAULT 0 CHECK (es_propio IN (0,1)),  -- 1 = mi equipo, 0 = rival
  color_primario  TEXT,                     -- '#D8231A'
  escudo_ruta     TEXT,                     -- ruta local o URL en Storage
  categoria       TEXT,                     -- 'Libre', 'Sub-15', 'Veteranos'...
  notas           TEXT,
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS jugadores (
  id              TEXT PRIMARY KEY,
  equipo_id       TEXT NOT NULL REFERENCES equipos(id),
  nombre          TEXT NOT NULL,
  apodo           TEXT,
  dorsal          INTEGER,
  posicion        TEXT CHECK (posicion IN ('POR','DEF','MED','DEL')),
  pie             TEXT CHECK (pie IN ('D','I','A')),
  fecha_nacimiento TEXT,
  activo          INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0,1)),
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS competiciones (
  id              TEXT PRIMARY KEY,
  nombre          TEXT NOT NULL,             -- 'Liga Municipal', 'Copa Ciudad'
  tipo            TEXT NOT NULL CHECK (tipo IN ('LIGA','TORNEO','AMISTOSO')),  -- LIGA = tabla de puntos, TORNEO = llaves
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS temporadas (
  id              TEXT PRIMARY KEY,
  competicion_id  TEXT NOT NULL REFERENCES competiciones(id),
  nombre          TEXT NOT NULL,             -- 'Apertura 2026'
  inicio          TEXT,
  fin             TEXT,
  puntos_victoria INTEGER NOT NULL DEFAULT 3,
  puntos_empate   INTEGER NOT NULL DEFAULT 1,
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sedes (
  id              TEXT PRIMARY KEY,
  nombre          TEXT NOT NULL,             -- 'Unidad Deportiva Norte'
  cancha          TEXT,                      -- 'Cancha 3'
  direccion       TEXT,
  latitud         REAL CHECK (latitud BETWEEN -90 AND 90),
  longitud        REAL CHECK (longitud BETWEEN -180 AND 180),
  superficie      TEXT CHECK (superficie IN ('NATURAL','SINTETICO','TIERRA','DUELA')),
  techada         INTEGER NOT NULL DEFAULT 0 CHECK (techada IN (0,1)),
  notas           TEXT,                      -- estacionamiento, vestidores...
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1
);

-- ---------------------------------------------------------------------
-- Partidos
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS partidos (
  id              TEXT PRIMARY KEY,
  equipo_id       TEXT NOT NULL REFERENCES equipos(id),   -- mi equipo
  rival_id        TEXT NOT NULL REFERENCES equipos(id),
  temporada_id    TEXT REFERENCES temporadas(id),
  sede_id         TEXT REFERENCES sedes(id),
  fecha_hora      TEXT NOT NULL,                          -- ISO-8601 UTC
  zona_horaria    TEXT NOT NULL DEFAULT 'America/Tijuana',
  es_local        INTEGER NOT NULL DEFAULT 1 CHECK (es_local IN (0,1)),
  jornada         TEXT,                                   -- 'J13', 'Cuartos'
  estado          TEXT NOT NULL DEFAULT 'PROGRAMADO'
                  CHECK (estado IN ('PROGRAMADO','EN_JUEGO','FINALIZADO','SUSPENDIDO','CANCELADO')),
  goles_favor     INTEGER CHECK (goles_favor >= 0),
  goles_contra    INTEGER CHECK (goles_contra >= 0),
  penales_favor   INTEGER,                                -- tanda de penales (copas)
  penales_contra  INTEGER,
  duracion_min    INTEGER NOT NULL DEFAULT 90,
  clima           TEXT,
  temperatura_c   REAL,
  uniforme        TEXT,
  notas           TEXT,
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1,
  CHECK (equipo_id <> rival_id),
  CHECK (estado <> 'FINALIZADO' OR (goles_favor IS NOT NULL AND goles_contra IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS alineaciones (
  id              TEXT PRIMARY KEY,
  partido_id      TEXT NOT NULL REFERENCES partidos(id) ON DELETE CASCADE,
  jugador_id      TEXT NOT NULL REFERENCES jugadores(id),
  titular         INTEGER NOT NULL DEFAULT 1 CHECK (titular IN (0,1)),
  posicion        TEXT,
  minuto_entrada  INTEGER NOT NULL DEFAULT 0,
  minuto_salida   INTEGER,                                -- NULL = terminó el partido
  capitan         INTEGER NOT NULL DEFAULT 0 CHECK (capitan IN (0,1)),
  calificacion    REAL CHECK (calificacion BETWEEN 1 AND 10),
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1,
  UNIQUE (partido_id, jugador_id)
);

CREATE TABLE IF NOT EXISTS eventos (
  id              TEXT PRIMARY KEY,
  partido_id      TEXT NOT NULL REFERENCES partidos(id) ON DELETE CASCADE,
  tipo            TEXT NOT NULL CHECK (tipo IN
                    ('GOL','AUTOGOL','PENAL_FALLADO','TARJETA_AMARILLA','TARJETA_ROJA',
                     'CAMBIO','TIRO')),
  minuto          INTEGER NOT NULL CHECK (minuto >= 0),
  es_rival        INTEGER NOT NULL DEFAULT 0 CHECK (es_rival IN (0,1)),
  jugador_id      TEXT REFERENCES jugadores(id),          -- NULL si es rival sin registrar
  jugador_rival   TEXT,                                   -- nombre libre del rival
  asistente_id    TEXT REFERENCES jugadores(id),          -- GOL: quién asistió
  jugador_sale_id TEXT REFERENCES jugadores(id),          -- CAMBIO: quién sale
  forma           TEXT,                                   -- 'PIE_DER','CABEZA','PENAL','TIRO_LIBRE'...
  a_puerta        INTEGER CHECK (a_puerta IN (0,1)),      -- TIRO
  pos_x           REAL CHECK (pos_x BETWEEN 0 AND 1),     -- TIRO: coordenadas normalizadas
  pos_y           REAL CHECK (pos_y BETWEEN 0 AND 1),
  xg              REAL,                                   -- calculado (Premium)
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS estadisticas_partido (
  partido_id      TEXT PRIMARY KEY REFERENCES partidos(id) ON DELETE CASCADE,
  tiros_favor     INTEGER, tiros_contra     INTEGER,
  a_puerta_favor  INTEGER, a_puerta_contra  INTEGER,
  corners_favor   INTEGER, corners_contra   INTEGER,
  faltas_favor    INTEGER, faltas_contra    INTEGER,
  fueras_juego_favor INTEGER, fueras_juego_contra INTEGER,
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  version         INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS convocatorias (
  id              TEXT PRIMARY KEY,
  partido_id      TEXT NOT NULL REFERENCES partidos(id) ON DELETE CASCADE,
  jugador_id      TEXT NOT NULL REFERENCES jugadores(id),
  respuesta       TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (respuesta IN ('PENDIENTE','VOY','NO_VOY','DUDA')),
  asistio         INTEGER CHECK (asistio IN (0,1)),
  comentario      TEXT,
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1,
  UNIQUE (partido_id, jugador_id)
);

-- ---------------------------------------------------------------------
-- Competición: tabla de la liga y llaves de torneos
-- ---------------------------------------------------------------------
-- Tabla de posiciones capturada de la liga oficial (otros equipos).
-- La fila de mi equipo NO se guarda: se calcula con v_resultados.
CREATE TABLE IF NOT EXISTS tabla_posiciones (
  temporada_id    TEXT NOT NULL REFERENCES temporadas(id),
  equipo_id       TEXT NOT NULL REFERENCES equipos(id),
  g INTEGER NOT NULL DEFAULT 0 CHECK (g >= 0),
  e INTEGER NOT NULL DEFAULT 0 CHECK (e >= 0),
  p INTEGER NOT NULL DEFAULT 0 CHECK (p >= 0),
  gf INTEGER NOT NULL DEFAULT 0 CHECK (gf >= 0),
  gc INTEGER NOT NULL DEFAULT 0 CHECK (gc >= 0),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  version         INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (temporada_id, equipo_id)
);

-- Llaves de eliminación directa. ronda 0 = primera ronda; orden = posición en la llave.
-- Si el cruce es nuestro, partido_id apunta al partido y el marcador sale de ahí.
CREATE TABLE IF NOT EXISTS cruces (
  id              TEXT PRIMARY KEY,
  temporada_id    TEXT NOT NULL REFERENCES temporadas(id),
  ronda           INTEGER NOT NULL CHECK (ronda >= 0),
  nombre_ronda    TEXT NOT NULL,            -- 'Octavos', 'Cuartos', 'Semifinal', 'Final'
  orden           INTEGER NOT NULL CHECK (orden >= 0),
  equipo_a_id     TEXT REFERENCES equipos(id),
  equipo_b_id     TEXT REFERENCES equipos(id),
  goles_a INTEGER, goles_b INTEGER, penales_a INTEGER, penales_b INTEGER,
  partido_id      TEXT REFERENCES partidos(id),
  actualizado_en  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  eliminado_en    TEXT,
  version         INTEGER NOT NULL DEFAULT 1,
  UNIQUE (temporada_id, ronda, orden)
);

CREATE VIEW IF NOT EXISTS v_tabla_liga AS
SELECT temporada_id, equipo_id, g+e+p AS pj, g, e, p, gf, gc, gf-gc AS dg, 3*g+e AS pts FROM tabla_posiciones
UNION ALL
SELECT r.temporada_id, r.equipo_id, COUNT(*), SUM(r.resultado='G'), SUM(r.resultado='E'), SUM(r.resultado='P'),
       SUM(r.goles_favor), SUM(r.goles_contra), SUM(r.goles_favor)-SUM(r.goles_contra), SUM(r.puntos)
FROM v_resultados r JOIN temporadas t ON t.id = r.temporada_id JOIN competiciones c ON c.id = t.competicion_id
WHERE c.tipo = 'LIGA' GROUP BY r.temporada_id, r.equipo_id;

-- ---------------------------------------------------------------------
-- Sincronización (solo se usa con Premium)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cola_sync (
  seq             INTEGER PRIMARY KEY AUTOINCREMENT,
  tabla           TEXT NOT NULL,
  fila_id         TEXT NOT NULL,
  operacion       TEXT NOT NULL CHECK (operacion IN ('UPSERT','DELETE')),
  carga_json      TEXT,                     -- snapshot de la fila
  creado_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  intentos        INTEGER NOT NULL DEFAULT 0,
  ultimo_error    TEXT
);

CREATE TABLE IF NOT EXISTS meta_sync (
  tabla           TEXT PRIMARY KEY,
  ultimo_pull     TEXT                      -- mayor actualizado_en recibido del servidor
);

CREATE TABLE IF NOT EXISTS preferencias (
  clave           TEXT PRIMARY KEY,         -- 'plan', 'tema', 'equipo_activo'...
  valor           TEXT
);

-- ---------------------------------------------------------------------
-- Índices
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_partidos_equipo_fecha ON partidos(equipo_id, fecha_hora);
CREATE INDEX IF NOT EXISTS ix_partidos_rival        ON partidos(rival_id);
CREATE INDEX IF NOT EXISTS ix_partidos_sede         ON partidos(sede_id);
CREATE INDEX IF NOT EXISTS ix_partidos_temporada    ON partidos(temporada_id);
CREATE INDEX IF NOT EXISTS ix_eventos_partido       ON eventos(partido_id, minuto);
CREATE INDEX IF NOT EXISTS ix_eventos_jugador       ON eventos(jugador_id, tipo);
CREATE INDEX IF NOT EXISTS ix_alineaciones_jugador  ON alineaciones(jugador_id);
CREATE INDEX IF NOT EXISTS ix_jugadores_equipo      ON jugadores(equipo_id);
CREATE INDEX IF NOT EXISTS ix_cola_sync_tabla       ON cola_sync(tabla, fila_id);

-- ---------------------------------------------------------------------
-- Triggers: mantener actualizado_en / version al editar
-- (en la app, drift también lo hace; esto protege ediciones directas)
-- ---------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS tr_partidos_touch AFTER UPDATE ON partidos
WHEN NEW.version = OLD.version
BEGIN
  UPDATE partidos
     SET actualizado_en = strftime('%Y-%m-%dT%H:%M:%SZ','now'),
         version = OLD.version + 1
   WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS tr_eventos_touch AFTER UPDATE ON eventos
WHEN NEW.version = OLD.version
BEGIN
  UPDATE eventos
     SET actualizado_en = strftime('%Y-%m-%dT%H:%M:%SZ','now'),
         version = OLD.version + 1
   WHERE id = NEW.id;
END;

-- ---------------------------------------------------------------------
-- Vistas (análisis gratuitos)
-- ---------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS v_resultados AS
SELECT p.id, p.equipo_id, p.rival_id, r.nombre AS rival, p.temporada_id, p.sede_id,
       p.fecha_hora, p.es_local, p.jornada, p.goles_favor, p.goles_contra,
       CASE WHEN p.goles_favor > p.goles_contra THEN 'G'
            WHEN p.goles_favor = p.goles_contra THEN 'E'
            ELSE 'P' END AS resultado,
       CASE WHEN p.goles_favor > p.goles_contra THEN COALESCE(t.puntos_victoria,3)
            WHEN p.goles_favor = p.goles_contra THEN COALESCE(t.puntos_empate,1)
            ELSE 0 END AS puntos
FROM partidos p
JOIN equipos r ON r.id = p.rival_id
LEFT JOIN temporadas t ON t.id = p.temporada_id
WHERE p.estado = 'FINALIZADO' AND p.eliminado_en IS NULL;

CREATE VIEW IF NOT EXISTS v_resumen_temporada AS
SELECT equipo_id, temporada_id,
       COUNT(*)                                   AS pj,
       SUM(resultado = 'G')                       AS g,
       SUM(resultado = 'E')                       AS e,
       SUM(resultado = 'P')                       AS p,
       SUM(goles_favor)                           AS gf,
       SUM(goles_contra)                          AS gc,
       SUM(goles_favor) - SUM(goles_contra)       AS dg,
       SUM(puntos)                                AS pts,
       ROUND(100.0 * SUM(resultado = 'G') / COUNT(*), 1) AS pct_victorias
FROM v_resultados
GROUP BY equipo_id, temporada_id;

CREATE VIEW IF NOT EXISTS v_goleadores AS
SELECT j.equipo_id, j.id AS jugador_id, j.nombre,
       COALESCE(SUM(e.tipo = 'GOL'), 0)            AS goles,
       (SELECT COUNT(*) FROM eventos a
         WHERE a.asistente_id = j.id AND a.tipo = 'GOL' AND a.eliminado_en IS NULL) AS asistencias
FROM jugadores j
LEFT JOIN eventos e ON e.jugador_id = j.id AND e.es_rival = 0 AND e.eliminado_en IS NULL
WHERE j.eliminado_en IS NULL
GROUP BY j.id;
