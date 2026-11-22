# FutData
Aplicación Móvil para Anotación de Partidos y Estadísticas

App en Flutter (Android + iOS) para registrar el historial de partidos de un equipo
(marcadores, goleadores, tarjetas, alineaciones, sedes, rivales), su calendario y
convocatorias, con análisis gratuitos y premium.

## Contenido

| Ruta | Qué es |
|---|---|
| `design/propuestas.html` | Direcciones de diseño A, B, C y la mezcla B+. **Elegida: B · Cancha (tema claro)** |
| `design/prototipo.html` | **Página principal** del sitio: elige entre las dos apps |
| `design/futdata.html` | Prototipo funcional de **FutData** (entrenadores y equipo) |
| `design/familia.html` | Prototipo funcional de **FutData Familia** (mamás y papás, hasta 4 hijos) |
| `tools/build_site.py` | Genera el sitio en `site/` para GitHub Pages |
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

## Sitio web (GitHub Pages)

```bash
python3 tools/build_site.py
```

Genera `site/index.html` (página principal), `site/futdata.html` y `site/familia.html`. El flujo
`.github/workflows/pages.yml` lo publica solo en cada push a `main` (Settings › Pages › Source: **GitHub Actions**).
