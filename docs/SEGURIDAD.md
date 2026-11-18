# FutData · Pruebas de seguridad de datos

Fecha: 18 nov 2026 · Alcance: prototipo (`design/prototipo.html`), base local SQLite (`db/schema.sql`)
y reglas de acceso de la nube (`db/supabase/esquema_rls.sql`).

## Cómo correrlas

```bash
python3 db/test_seguridad_sqlite.py          # base local
cd db/supabase && npm install && npm test    # nube (Postgres real en WASM)
node tests/seguridad_prototipo.js            # prototipo (requiere Playwright)
```

## Resultado

| Suite | Pruebas | Resultado |
|---|---|---|
| Reglas de acceso en la nube (RLS, Postgres) | 58 | 58 ✓ |
| Base local SQLite | 19 | 19 ✓ |
| Prototipo (navegador) | 21 | 21 ✓ después de corregir 5 hallazgos |

### Qué se probó

**Nube (lo que protege de verdad los datos):** se ejecutan consultas haciéndose pasar por cada rol.
- Aislamiento: el entrenador de otro equipo, un usuario sin equipo y un visitante sin sesión no ven ni modifican nada de nuestro equipo.
- Padre: ve solo a su hijo, su convocatoria y sus datos privados; responde solo por él; no marca asistencia real, no cambia marcadores, no borra, no se asciende a entrenador.
- Jugador: ve el plantel y la convocatoria completa; solo cambia su propia respuesta; no ve datos privados de compañeros.
- Cuerpo técnico: registra y corrige, publica la alineación; no borra partidos ni jugadores, no invita miembros, no ve la suscripción.
- Entrenador: único que ve la suscripción e invita; ni él puede activarse Premium desde la app (solo el servidor tras el pago).
- Alineación invisible para jugadores y padres hasta publicarse.
- Lesiones (dato de salud): solo cuerpo técnico, el jugador y su tutor.
- Integridad cruzada: no se puede colgar un evento en un partido de otro equipo ni escribir con el `equipo_id` de otro.
- Inyección SQL con consultas parametrizadas, y rechazo de minutos, goles y roles inválidos.

**Base local:** inyección SQL, 13 tipos de datos inválidos rechazados por la base, y borrados sin datos huérfanos.

**Prototipo:** código malicioso en 12 campos de texto con 3 variantes y vistas de los 4 roles; enlaces y colores manipulados;
textos gigantes; escudo SVG con código; 46 acciones y 11 formularios forzados por jugador y padre (y 18 + 2 por cuerpo técnico);
nombres de otros menores visibles para un padre; lesiones ajenas visibles.

### Hallazgos corregidos

| # | Hallazgo | Riesgo | Corrección |
|---|---|---|---|
| 1 | Un enlace con dominio que imita a Google (`https://www.google.com.evil.example/maps`) pasaba como enlace de Maps | Medio: “Cómo llegar” podía llevar a un sitio falso (phishing) | Validación por nombre de host exacto con `URL()` y lista de dominios permitidos |
| 2 | Un color manipulado (`red;background-image:url(...)`) se guardaba tal cual | Bajo: inyección de CSS, rastreo por imagen externa | Solo se aceptan colores `#rrggbb` |
| 3 | Sin límite de largo en textos | Bajo: llenar la base o romper pantallas | Límite en cada campo (80 caracteres, notas 500) en formulario y al guardar |
| 4 | El padre veía los nombres de los otros niños en la alineación publicada | Medio: contradice la regla de privacidad de menores | El padre ve solo el nombre y dorsal de su hijo; los demás lugares aparecen vacíos |
| 5 | Las lesiones (dato de salud) las veía todo el equipo | Alto (legal): dato sensible de menores | Solo cuerpo técnico, el jugador y su tutor; aplicado en app y en RLS |

## Recomendaciones para la app real (Flutter)

1. **La seguridad vive en el servidor.** La app oculta pantallas, pero quien decide es RLS en Supabase. Nunca usar la llave `service_role` en la app; solo en funciones del servidor (webhook de RevenueCat, borrado de cuenta).
2. **Base local cifrada.** Usar `sqlcipher_flutter_libs` con drift y guardar la llave en `flutter_secure_storage` (Keychain / Keystore). El teléfono guarda datos de menores.
3. **Sesión:** tokens de Supabase en almacenamiento seguro; cerrar sesión borra la base local de ese equipo.
4. **Respaldos del sistema:** excluir la base de los respaldos automáticos sin cifrar (`android:allowBackup="false"` o reglas de respaldo; en iOS, atributo de exclusión).
5. **Pagos:** el plan Premium solo se activa desde el webhook firmado de RevenueCat (verificar firma); la app nunca decide si eres Premium.
6. **Invitaciones:** por enlace de un solo uso con caducidad (por ejemplo 7 días) y rol fijo; el padre se vincula a un jugador específico.
7. **Imágenes:** redimensionar y convertir a PNG/JPG en el teléfono antes de subir (como hace el prototipo); Storage con políticas por equipo.
8. **Registro de cambios** (auditoría) para marcador, eventos y borrados: quién y cuándo.
9. **Borrado de cuenta y exportación** dentro de la app (lo exigen App Store y Google Play).
10. **Correr estas pruebas en CI** en cada cambio del esquema o de las políticas.
