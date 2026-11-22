# FutData
Aplicación Móvil para Anotación de Partidos y Estadísticas

App en Flutter (Android + iOS) para registrar el historial de partidos de un equipo
(marcadores, goleadores, tarjetas, alineaciones, sedes, rivales), su calendario y
convocatorias, con análisis gratuitos y premium.

## Contenido

| Ruta | Qué es |
|---|---|
| `design/propuestas.html` | Direcciones de diseño A, B, C y la mezcla B+. **Elegida: B · Cancha (tema claro)** |
| `design/prototipo.html` | Prototipo con **dos apps**: al abrir eliges **FutData** (entrenador y equipo) o **FutData Familia** (mamá y papá registran a hasta 4 hijos). Todo funciona en memoria |
| `design/prototipo.html` (detalle) | Prototipo interactivo de B (abrir en el navegador): CRUD de partidos, eventos en vivo, convocatorias, rivales, sedes, plantel y análisis; datos en memoria |
| `docs/ARQUITECTURA.md` | Planes gratis/premium, catálogo de análisis, almacenamiento SQLite + nube, stack Flutter, roadmap |
| `db/schema.sql` | Esquema SQLite local (preparado para sincronizar con Postgres/Supabase) |
| `db/consultas_analisis.sql` | Consultas de análisis gratuitas y premium |
| `db/test_schema.py` | Prueba del esquema con datos de ejemplo |
| `db/supabase/` | Esquema de la nube con reglas de acceso por rol (RLS) y sus pruebas |
| `docs/SEGURIDAD.md` | Pruebas de seguridad, hallazgos corregidos y recomendaciones |
| `docs/CREDENCIALES.md` | Cómo se crean y entregan los accesos (invitaciones) |
| `docs/legal/` | Borrador de Términos y Condiciones y Aviso de Privacidad (para revisión legal) |

## Probar el esquema

```bash
python3 db/test_schema.py
```

## Pruebas de seguridad

```bash
python3 db/test_seguridad_sqlite.py
```

```bash
cd db/supabase && npm install && npm test
```

```bash
node tests/seguridad_prototipo.js
```
