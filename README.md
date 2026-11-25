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
| `apps/familia/` | **App Flutter de FutData Familia** (Android). El APK se descarga en Releases › “FutData Familia (Android)” |
| `tools/build_site.py` | Genera el sitio en `site/` para GitHub Pages: cada app como app web instalable |
| `tools/make_icons.py` · `design/iconos/` | Íconos de cada app para Android, iPhone y navegador |
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

Genera `site/`:

| Ruta | Qué es |
|---|---|
| `site/index.html` | Página principal con las dos opciones |
| `site/futdata/` | FutData como **app web instalable**: manifest, service worker (funciona sin internet) e íconos |
| `site/familia/` | FutData Familia, igual pero independiente (se instala por separado) |
| `site/_plano/` | Las tres páginas sin instalación, para abrirlas como archivos sueltos |

En el celular cada app se abre a pantalla completa y muestra cómo instalarla: botón “Instalar” en Android,
o “Compartir › Agregar a inicio” en iPhone. Ya instalada, abre sin barra del navegador, con su ícono.

El flujo `.github/workflows/pages.yml` construye el sitio en cada push a `main` y lo sube a la rama **`gh-pages`**. En GitHub: Settings › Pages › Source: **Deploy from a branch** › `gh-pages` / `(root)`.
Para probarlo en tu computadora: `cd site && python3 -m http.server 8000` y abre `http://localhost:8000`
(o la carpeta `site/` con Live Server de VS Code).
