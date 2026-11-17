-- =====================================================================
-- FutData · Consultas de análisis (SQLite)
-- Parámetros con nombre (:equipo, :temporada, :rival) como los usa drift.
-- [G] = plan gratuito · [P] = Premium
-- =====================================================================

-- [G] Forma: últimos 5 resultados (más antiguo → más reciente)
-- name: forma_ultimos_5
SELECT resultado FROM (
  SELECT resultado, fecha_hora FROM v_resultados
  WHERE equipo_id = :equipo ORDER BY fecha_hora DESC LIMIT 5
) ORDER BY fecha_hora ASC;

-- [G] Cara a cara contra un rival
-- name: cara_a_cara
SELECT COUNT(*) AS pj,
       SUM(resultado='G') AS g, SUM(resultado='E') AS e, SUM(resultado='P') AS p,
       SUM(goles_favor) AS gf, SUM(goles_contra) AS gc
FROM v_resultados WHERE equipo_id = :equipo AND rival_id = :rival;

-- [P] Goles por franja de 15 minutos (a favor y en contra)
-- name: goles_por_franja
SELECT CASE WHEN e.minuto <= 15 THEN '00-15'
            WHEN e.minuto <= 30 THEN '16-30'
            WHEN e.minuto <= 45 THEN '31-45'
            WHEN e.minuto <= 60 THEN '46-60'
            WHEN e.minuto <= 75 THEN '61-75'
            ELSE '76-90' END AS franja,
       SUM(e.es_rival = 0) AS a_favor,
       SUM(e.es_rival = 1) AS en_contra
FROM eventos e
JOIN partidos p ON p.id = e.partido_id
WHERE p.equipo_id = :equipo AND e.tipo IN ('GOL','AUTOGOL') AND e.eliminado_en IS NULL
GROUP BY franja ORDER BY franja;

-- [P] Rendimiento por contexto: local/visita y superficie
-- (el corte por horario día/noche se hace en Dart con la zona_horaria del partido)
-- name: rendimiento_contexto
SELECT CASE r.es_local WHEN 1 THEN 'Local' ELSE 'Visita' END AS condicion,
       COALESCE(s.superficie,'?') AS superficie,
       COUNT(*) AS pj, ROUND(AVG(r.puntos), 2) AS pts_por_partido,
       ROUND(AVG(r.goles_favor), 2) AS gf_prom, ROUND(AVG(r.goles_contra), 2) AS gc_prom
FROM v_resultados r LEFT JOIN sedes s ON s.id = r.sede_id
WHERE r.equipo_id = :equipo
GROUP BY condicion, superficie
ORDER BY pts_por_partido DESC;

-- [P] Minutos jugados y goles por 90'
-- name: por_90
WITH minutos AS (
  SELECT a.jugador_id,
         SUM(COALESCE(a.minuto_salida, p.duracion_min) - a.minuto_entrada) AS minutos,
         COUNT(*) AS partidos, SUM(a.titular) AS titularidades
  FROM alineaciones a JOIN partidos p ON p.id = a.partido_id
  WHERE p.equipo_id = :equipo AND p.estado = 'FINALIZADO' AND a.eliminado_en IS NULL
  GROUP BY a.jugador_id
)
SELECT j.nombre, m.partidos, m.titularidades, m.minutos, g.goles, g.asistencias,
       ROUND(90.0 * g.goles / NULLIF(m.minutos,0), 2) AS goles_por_90,
       ROUND(90.0 * (g.goles + g.asistencias) / NULLIF(m.minutos,0), 2) AS ga_por_90
FROM minutos m
JOIN jugadores j  ON j.id = m.jugador_id
JOIN v_goleadores g ON g.jugador_id = m.jugador_id
ORDER BY goles_por_90 DESC;

-- [P] Rendimiento con / sin un jugador en cancha
-- name: con_sin_jugador
SELECT CASE WHEN EXISTS (SELECT 1 FROM alineaciones a
                          WHERE a.partido_id = r.id AND a.jugador_id = :jugador AND a.titular = 1)
            THEN 'Con' ELSE 'Sin' END AS jugador,
       COUNT(*) AS pj, ROUND(100.0*SUM(r.resultado='G')/COUNT(*),1) AS pct_victorias,
       ROUND(AVG(r.puntos),2) AS pts_por_partido
FROM v_resultados r WHERE r.equipo_id = :equipo
GROUP BY jugador;

-- [P] Insumos del pronóstico (Poisson). La probabilidad G/E/P se calcula en Dart:
--   λ_favor  = media_gf_mia * (media_gc_rival / media_gc_liga)
--   λ_contra = media_gc_mia * (media_gf_rival / media_gf_liga)
-- Sin datos de la liga se usa sólo el historial propio y el cara a cara.
-- name: insumos_pronostico
SELECT AVG(goles_favor) AS media_gf, AVG(goles_contra) AS media_gc, COUNT(*) AS n
FROM (SELECT goles_favor, goles_contra FROM v_resultados
      WHERE equipo_id = :equipo ORDER BY fecha_hora DESC LIMIT 15);

-- [P] Puntos acumulados por jornada (gráfica de progreso)
-- name: puntos_acumulados
SELECT fecha_hora, jornada, puntos,
       SUM(puntos) OVER (ORDER BY fecha_hora ROWS UNBOUNDED PRECEDING) AS acumulado
FROM v_resultados WHERE equipo_id = :equipo AND temporada_id = :temporada
ORDER BY fecha_hora;
