# FutData Familia (Flutter)

App nativa de FutData Familia para Android (y iOS con una Mac). Los datos se guardan en el teléfono con SQLite.

| Carpeta | Qué es |
|---|---|
| `lib/modelo.dart` | Hijos, equipos, partidos, minutos y acciones |
| `lib/estado.dart` | Reglas (máx. 4 hijos, 2 adultos, prueba de 7 días por hijo, reloj del en vivo) y guardado en SQLite |
| `lib/semilla.dart` | Familia de ejemplo |
| `lib/pantallas/` | Términos, Inicio, Calendario, Partido, En vivo, Progreso, Familia |

```bash
flutter test
```

```bash
flutter build apk --release
```

El flujo `.github/workflows/apk-familia.yml` compila el APK en cada cambio y lo publica en Releases › **FutData Familia (Android)**.
