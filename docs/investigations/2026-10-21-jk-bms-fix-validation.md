# Corrección de autonomía, enlace JK e inicio automático

Fecha: 21 de octubre de 2026. Rama local: `fix/jk-readings-range-autostart`.
Base: `f0f7a3e` / 2.30.0. La investigación original está en [diagnóstico](2026-10-21-jk-bms-diagnostics.md).

## Comportamiento corregido

- Las dos autonomías comparten una referencia: capacidad medida confiable, después configuración BMS y por último catálogo. El porcentaje mostrado no fabrica Ah que el contador no reportó. Las bandas usan la misma energía que la cifra central.
- Caso reproducido de 20S NMC, 100 %, BMS 40 Ah, catálogo 45 Ah y consumo 20 Wh/km: **149,28 km actuales y 149,28 km con carga completa**. Con una capacidad medida confiable de 38 Ah, ambas pasan a **141,816 km**.
- Se conservan los contadores originales y el cálculo de energía histórica. La capacidad de catálogo introducida por el usuario tampoco se sobrescribe.
- Si la química sigue desconocida, se conserva la estimación actual conservadora y se explica que hace falta indicar la química para estimar la autonomía llena, en lugar de mezclar curvas distintas.
- La vista guardada y la comparación aplican la misma política a la evidencia disponible. Los snapshots antiguos no guardan nominal Ah: solo se recupera desde lecturas útiles recientes del mismo pack o de una capacidad explícitamente tomada del BMS. Sin esa evidencia, el catálogo sigue identificado como respaldo; no se inventa una configuración.
- El JK admite características GATT separadas para escritura y notificación, además del módulo combinado. La conexión no se anuncia antes de completar los pedidos iniciales. Una escritura inicial fallida libera el intento y permite reintentar.
- Mensajes de identificación, configuración o tramas indecodificables no equivalen a lecturas de batería. Solo una lectura decodificada reinicia el reloj de datos útiles y perdona la racha de fallos. La recuperación se rearma por intento/reconexión y deja quieto un stream sano.
- Un enlace que permanece sin lecturas agota su recuperación hacia un estado de fallo explícito, incluida la última tentativa, en vez de quedar desconectado físicamente y anunciado como conectado.
- El evento persistido `readingsResumed` se escribe cuando llega una lectura, no cuando vuelve GATT. La tarjeta de conexión distingue ausencia de lecturas actuales y evita mostrar como actual un porcentaje congelado.
- Antes del viaje, un GPS silencioso se recupera tras 90 s de descarga suficiente. Errores y cierre del stream también se recuperan; los reintentos quedan separados dos minutos y se mantiene el requisito de movimiento.
- Desconectar retira la apertura GPS pendiente. Su retorno, error o callback posterior no puede bloquear ni modificar el GPS del siguiente pack. No se inicia un viaje a partir de velocidad antigua.
- Activar/desactivar auto-start cambia el tipo realmente aplicado del servicio. Sus operaciones se serializan, agrupan actualizaciones de texto y respetan el cierre del servicio, evitando reinicios simultáneos o posteriores a `dispose`.
- La pantalla explica cuando el inicio automático espera posiciones GPS o está intentando recuperarlas.

## Verificación local anterior a la publicación

Se observaron los rojos antes de corregir autonomía, recuperación JK, GATT separado/arranque, GPS sin posiciones/error y cambio de tipo del servicio. Las regresiones permanentes ejercitan parser y servicio, y los casos de transporte usan FlutterBluePlus real con radio falsa y tramas capturadas del pack.

| Comprobación | Resultado |
| --- | --- |
| Lote integrado autonomía/BLE: siete archivos | 51/51 pasan |
| Suite Flutter completa | 1496/1496 pasan, 8 min 20 s |
| Consola diagnóstica y autonomía guardada: dos archivos | 10/10 pasan |
| `flutter analyze --no-pub` | Sin problemas, ejecución final de 196,3 s |
| Compilación Android arm64 release local | Correcta, Gradle 722,7 s, APK 25,8 MiB |
| Firma y contenido del APK | `apksigner verify` correcto (v2); paquete y ABI verificados con `aapt` |
| `git diff --check` | Sin errores |
| CI | No ejecutado |
| Instalación y recorrido con el JK físico | Pendientes |
| Publicación GitHub | No realizada |

Primera compilación local: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, generada el 21/10/2026 a las 14:38:42 (America/Havana), 27.022.752 bytes. Paquete `dev.selector.jk_bms`, ABI `arm64-v8a`, Android mínimo 24 y target 36. Conservaba la versión base `2.30.0` / `4075`, antes de preparar la nueva release. La compilación de publicación reemplaza este archivo.

SHA-256 de aquella primera compilación local: `EE7C33C31B168146C5534319182D0EC16626505F5431E487EC4D7B9E53B8EE00`.

Comandos de cierre:

```powershell
flutter test --no-pub --concurrency 4 --reporter expanded
flutter analyze --no-pub
flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub
git diff --check
```

## Cobertura añadida

- [Autonomía desde el servicio real](../../test/range_service_test.dart) y [referencia/energía operacional](../../test/operational_range_test.dart).
- [Autonomía guardada y comparación](../../test/pack_summary_range_test.dart).
- [Recuperación JK por enlace/intento](../../test/jk_reading_recovery_test.dart) y [registro de lecturas reanudadas](../../test/link_liveness_test.dart).
- [GATT combinado/separado, arranque y datos útiles](../../test/ble_transport_gatt_test.dart), incluido ANT, y [agotamiento de enlace sin lecturas](../../test/ble_transport_mute_limit_test.dart).
- [Recuperación y generaciones GPS](../../test/auto_trip_gps_recovery_test.dart), [tipo del servicio](../../test/foreground_service_test.dart) y [concurrencia/cierre](../../test/foreground_service_concurrency_test.dart).
- [Consola diagnóstica](../../test/live_console_screen_test.dart): constructor y ciclo del servicio comparten la zona real del test. Evita un bloqueo del harness sin relajar la sincronización de cierre del servicio.

## Límite de la validación

Los resultados locales verifican las correcciones lógicas. No equivalen a haber instalado y probado la app corregida con el JK real. El cierre físico requiere comprobar lecturas nuevas tras conectar/reconectar y el inicio con pantalla apagada durante movimiento real, conservando los eventos del intento. No se modificaron los ajustes del BMS.

## Preparación de v2.30.1

Tras autorizarse la publicación, la versión pasa a `2.30.1+2076`. El tag de release y el `versionName` de Android deben coincidir en `2.30.1`: el actualizador compara la versión semántica e ignora el número de build.

Se generan y firman los tres paquetes mediante `flutter build apk --release --split-per-abi --no-pub`. Los códigos esperados son `3076` para `armeabi-v7a`, `4076` para `arm64-v8a` y `6076` para `x86_64`; todos superiores a los publicados en 2.30.0. Se verifica su firma frente a la release anterior y la selección del APK con el parser real del actualizador. La disponibilidad final se comprueba en `/releases/latest` tras publicar los tres archivos.
