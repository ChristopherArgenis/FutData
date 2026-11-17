# FutData
Aplicación Móvil para Anotación de Partidos y Estadísticas

App en Flutter (Android + iOS) para registrar el historial de partidos de un equipo
(marcadores, goleadores, tarjetas, alineaciones, sedes, rivales), su calendario y
convocatorias, con análisis gratuitos y premium.

## Contenido

| Ruta | Qué es |
|---|---|
| `design/propuestas.html` | Tres direcciones de diseño (A Pizarra, B Cancha, C Marcador) con 4 pantallas cada una |
| `docs/ARQUITECTURA.md` | Planes gratis/premium, catálogo de análisis, almacenamiento SQLite + nube, stack Flutter, roadmap |
| `db/schema.sql` | Esquema SQLite local (preparado para sincronizar con Postgres/Supabase) |
| `db/consultas_analisis.sql` | Consultas de análisis gratuitas y premium |
| `db/test_schema.py` | Prueba del esquema con datos de ejemplo |

## Probar el esquema

```bash
python3 db/test_schema.py
```
