# PRD — Extensión: Monetización y Módulo de Inspección

**Proyecto:** App Flutter para JK Smart BMS (solo lectura)
**Extiende a:** PRD v1.0 (`PRD-jkbms-app.md`)
**Versión:** 1.0
**Estado:** propuesta, lista para incorporar al PRD principal
**Audiencia:** el autor y el agente de codificación (Claude Code)

---

## 0. Cómo usar este documento

Este documento **no reemplaza** el PRD v1.0. Asume que su arquitectura ya existe (BleTransport → FrameAssembler → JkParser → Stream → MetricsEngine/Repository → UI) y define qué se construye encima para que la app sea un producto vendible en Cuba.

Donde diga **VERIFICAR**, no asumir: confirmar contra hardware real, contra el mercado, o contra el usuario.

Las reglas del PRD v1.0 siguen vigentes, en especial: **ninguna escritura al BMS bajo ninguna circunstancia.** Todo lo descrito aquí es lectura, cálculo y presentación.

---

## 1. Tesis del producto

La app **no** se vende como "una app de BMS mejor que la oficial". La app oficial de JK es mala pero suficiente para ver números en vivo; nadie paga por ver lo mismo más bonito.

La app se vende como: **"No compres una batería a ciegas."**

### Por qué

En Cuba:

- Las baterías de litio para motorinas (ej. Yoazaky 72V 45Ah) son la opción accesible; no hay alternativa de celdas premium.
- El mercado de **baterías de uso** es grande. El comprador paga un dineral confiando en la palabra del vendedor sobre ciclos, kilómetros y estado.
- Hoy la verificación es: creerle al vendedor, o probarla "más o menos" y asumir.
- La reputación (y los timos) corren por grupos de Telegram/WhatsApp en horas.

El dolor real es **la salud de la batería y la confianza en una compra**, no la visualización de datos.

### Consecuencia de diseño

Todo lo gratis debe igualar o superar a la app de JK para que la gente migre. Todo lo de pago debe ser algo que la app de JK **no puede hacer por diseño**: persistencia, historial, diagnóstico, veredictos, inspección de terceros.

---

## 2. Qué ya cubre el PRD v1.0 (motor de lo cobrable)

Ya especificado y **no se repite aquí**:

- Paridad completa con la app oficial (20 celdas, pack, temperaturas, balanceo, MOSFET, alarmas, device info)
- Persistencia en SQLite (drift) con frames crudos guardados para reparseo
- Wh/km con GPS del teléfono
- Estimación de resistencia interna (IR) por celda
- Curvas delta-vs-SOC
- Capacidad por ciclo (degradación)
- Historial de balanceo como ranking de salud de celdas
- Reconexión estable, tabs como vistas del mismo stream

Lo que sigue es la **capa que convierte ese motor en producto**.

---

## 3. Lo que falta (resumen)

| # | Módulo | Estado en PRD v1.0 | Prioridad |
|---|---|---|---|
| A | Inspección: test rápido guiado | No existe | **Alta** (feature estrella) |
| B | Veredictos en lenguaje humano | Solo métricas | **Alta** |
| C | Sistema de licencias (gratis / Pro / Taller / chequeos) | No existe | **Alta** (sin esto no se cobra) |
| D | Reporte PDF y Certificado de vendedor | No existe | Alta |
| E | Onboarding con baseline | No existe | Media |
| F | Alertas en background | No existe | Media |
| G | Auditoría de configuración (solo lectura) | No existe | Media |
| H | Perfiles multi-batería + export/import de DB | No existe | Media (necesario para Taller) |

---

## 4. Módulo A — Inspección: test rápido guiado

### 4.1 Objetivo

Que **cualquier persona sin conocimiento técnico** pueda evaluar una batería ajena en ~2 minutos, en el taller o frente al vendedor, y salir con un veredicto claro y honesto de **baja fidelidad pero alta utilidad**: detecta la estafa obvia y la celda mala; no mide capacidad real.

### 4.2 Principio clave: la app detecta la carga, el usuario no toca "siguiente"

La pantalla muestra **una instrucción a la vez, en letras grandes** ("Ahora enciende las luces"). La app observa la corriente que reporta el BMS y **avanza sola** cuando detecta que el paso se cumplió. El usuario solo ejecuta.

Si la carga no aparece o es insuficiente, la app lo dice: "Muy poca corriente (3 A). Dale más" / "Carga detectada: 18 A, suficiente."

### 4.3 Flujo propuesto

| Paso | Duración | Instrucción al usuario | Qué mide la app | Señal de alarma |
|---|---|---|---|---|
| 0. Conexión | — | "Pide al vendedor que cierre su app JK. Conecta." | Lectura de device info, firmware, config, alarmas guardadas | Alarmas activas o históricas relevantes |
| 1. Reposo | 30 s | "No toques nada" | Delta entre celdas en vacío, temperatura de sondas, SOC reportado, ciclos y capacidad configurada | Delta en reposo alto → rojo temprano |
| 2. Carga baja | 20 s | "Enciende las luces" | Corriente pequeña estable; que el BMS reporte corriente correctamente; celdas que ya caen con casi nada | Celda que cae con 1–2 A |
| 3. Carga fuerte | 5–10 s | Ver 4.4 | **Sag por celda → IR estimada.** Es donde sale la verdad | Celda que cae 80 mV+ más que las demás (umbral: VERIFICAR con datos reales) |
| 4. Recuperación | 45 s | "Suelta todo y espera" | Cuánto demora cada celda en volver al voltaje de reposo | Celdas cansadas rebotan lento. Indicador poco mirado y muy bueno |
| 5. Veredicto | — | — | Semáforo + 3 frases + fidelidad + botón "Guardar inspección" | — |

Los umbrales concretos de cada alarma se calibran con datos reales de la moto del autor y de baterías conocidas buenas/malas. **No inventarlos en abstracto.**

### 4.4 El problema de la carga fuerte

"Acelerar frenado" **no funciona** en muchas motorinas: el controlador corta el acelerador al detectar freno. Y las luces en 72 V son 1–2 A, no dicen casi nada.

La app debe aceptar **cualquiera** de estas tres formas de generar carga y validarla por la corriente medida:

1. **Rueda trasera al aire** (caballete central) y acelerar: corriente moderada, sin peligro.
2. **Dar ~50 metros en la moto** con el teléfono en el bolsillo: la app detecta la corriente y toma las muestras sola. Más carga real, más fidelidad.
3. **Cargador conectado 30 s** si hay uno a mano: las celdas altas se disparan y el desbalance se ve arriba.

**VERIFICAR:** comportamiento del controlador de la Yoazaky 707 con freno + acelerador; corriente típica de las luces; corriente típica a rueda libre.

### 4.5 Implementación

- El JK emite frames a ~1 Hz. Para ΔV/ΔI por celda se necesita el frame de reposo justo anterior y el frame de pico de corriente.
- **Guardar el buffer completo del test** (frames crudos, con timestamp del teléfono) y calcular al final, no en vivo. El cálculo en vivo con 1 Hz es frágil.
- El test corre sobre el mismo `Stream<BmsSnapshot>`; no tiene transporte propio.
- Modo **"Inspección" separado de "Mi batería"**: sesión temporal, con su propio device ID del BMS ajeno, que **no contamina el historial** del usuario. Los reportes de inspección se guardan en su propia tabla.

### 4.6 Los datos que no se pueden creer

**Ciclos y capacidad configurada son editables** desde la app oficial de JK. Un vendedor puede poner ciclos en 3 y capacidad en 45 Ah.

La app debe decirlo explícitamente en el veredicto:

> Ciclos reportados: 12 ⚠️ *dato editable por el usuario, no confiar.*
> IR y delta bajo carga: coherentes con una batería de ~200 ciclos.

Se confía en la **física** (IR, delta bajo carga, recuperación), no en los contadores. Esta honestidad es un diferenciador, no un defecto.

### 4.7 Honestidad del resultado

- La pantalla de veredicto dice **"Test rápido"** con letras claras.
- La capacidad real solo se conoce con una descarga completa; el rápido entrega una **estimación** y usa esa palabra.
- Ofrece: "Para capacidad real, haz el test completo (descarga controlada)."
- Una pantalla de "precio justo estimado según estado" es tentadora y **peligrosa**. Fuera de alcance por ahora. Si se equivoca una vez, la reputación se pierde en los grupos en una hora.

---

## 5. Módulo B — Veredictos en lenguaje humano

El PRD v1.0 produce métricas. El usuario no lee gráficas; lee **sentencias**.

Capa de interpretación sobre el MetricsEngine que produce frases del tipo:

- "La celda 11 lleva 3 semanas separándose del resto. Revísala antes de que el pack se apague en la calle."
- "Tu batería está al 78 % de la capacidad con la que llegó."
- "Te quedan ~23 km con cómo tú manejas."
- "Delta bajo carga normal. Nada que hacer."

Reglas:

- Cada veredicto tiene **un dato que lo respalda** visible con un toque ("por qué").
- Nunca afirmar lo que no se midió. Preferir "coherente con" a "es".
- Los umbrales son configurables internamente y se calibran con datos reales.

---

## 6. Módulo C — Licencias y modelo de cobro

### 6.1 Niveles

| Nivel | Qué incluye | Cómo se cobra |
|---|---|---|
| **Gratis** | Visor completo en vivo (paridad total con JK, sin recortes), historial de 24 h, baseline del día 1 | — |
| **Trial** | Pro completo durante 7 días desde la instalación, luego cae a Gratis | — |
| **Pro individual** | Historial ilimitado, degradación, SOH, autonomía real, veredictos, alertas en background, auditoría de config, PDF de mi batería, export/import de DB | **Pago único, de por vida, por dispositivo** |
| **Pack de chequeos** | N inspecciones rápidas con reporte (ej. 3) | Pago único, barato. Para el que va a comprar una batería una vez |
| **Certificado de vendedor** | Inspección + PDF con QR/firma "verificada el día X" para publicar la batería | Pago único por certificado |
| **Pro Taller** | Todo lo Pro + perfiles multi-batería sin límite + PDF con logo del taller + inspecciones ilimitadas | **Anual** (no mensual) |

### 6.2 Razonamiento

- **Sin suscripción individual.** En Cuba las suscripciones mueren: inflación, fricción de pago, desconfianza. Pago único.
- **Lo gratis no recorta datos en vivo.** Si el visor gratis es peor que JK, nadie migra.
- **El trial es de Pro completo**, no un demo capado. Probar el historial y perderlo engancha más que nunca haberlo tenido.
- **Dos lados pagan** en el mercado de uso: el comprador (chequeos) y el vendedor serio (certificado, porque vende más rápido y más caro).
- **Taller anual** porque su volumen justifica y porque 10 talleres pagando > 1000 motoristas pidiendo gratis.

### 6.3 Precio

**No fijado en este documento.** Anclaje propuesto: el Pro individual alrededor de un **2–3 % del precio de calle de un pack nuevo**, en CUP. Alguien que ya gastó eso en la batería no siente ese monto. Pro Taller ≈ 5–10× el individual, anual.

**VERIFICAR:** precio actual de calle de una Yoazaky 72V 45Ah nueva y de uso.

### 6.4 Activación offline (sin servidor)

1. La app muestra un **ID de dispositivo** (derivado de identificadores estables del teléfono; VERIFICAR qué usar en Android moderno).
2. El usuario paga y manda **comprobante + ID** por Telegram/WhatsApp.
3. El autor genera una **clave de licencia firmada** (Ed25519: clave privada del autor; clave pública embebida en la app). La clave codifica: nivel, ID de dispositivo, fecha, y para Taller la caducidad.
4. El usuario pega la clave. La app valida la firma **100 % local, sin internet**.
5. Al inicio el proceso es manual. Con volumen, un **bot de Telegram** lo automatiza.

Piratería: va a existir. La clave es por dispositivo y se sigue adelante. **No sobre-ingenierizar** la protección; el tiempo va al producto.

### 6.5 Cobro

- **Transfermóvil** (transferencia a tarjeta) o **EnZona**.
- Si el autor se registra como TCP/actor económico, puede usar el pago en línea de Transfermóvil, cuya comisión al receptor bajó a 0,8 % (agosto 2026). Si no, transferencia P2P normal.
- Aceptar además **Zelle / USD** desde familia en el exterior; medio país se paga así.
- **VERIFICAR:** requisitos vigentes para registrarse como TCP y contratar pago en línea.

### 6.6 Distribución

- **APK directo** por Telegram, grupos de motorinas, Revolico.
- **Apklis** (tienda cubana; permite pago por descarga con Transfermóvil, pero el cobro real se hace por licencia, no por descarga, porque el APK se comparte igual).
- Play Store: **no**.
- Tamaño del APK importa: se comparte por datos móviles.

---

## 7. Módulo D — Reporte PDF y Certificado

### 7.1 Reporte "Mi batería"

Estado actual, baseline vs hoy, degradación, ranking de celdas, últimas alertas. Para llevar al taller o para vender la moto.

### 7.2 Reporte de inspección

Resultado del test rápido: semáforo, frases, tabla de celdas (reposo / bajo carga / recuperación), datos del BMS con marca de "editable" donde aplique, fecha, ID de BMS, **fidelidad: test rápido**.

### 7.3 Certificado de vendedor

Reporte de inspección + QR/firma que permita a un comprador verificar que el PDF no fue editado (firma Ed25519 del contenido con la clave de la app o del autor). Texto claro: "Verificado con test rápido el día X. Capacidad estimada, no medida."

Implementación: generación local (paquete `pdf` de Flutter o equivalente), compartir con `share_plus`.

---

## 8. Módulo E — Onboarding con baseline

Al agregar una batería:

- Capacidad nominal declarada, química (NMC/LFP; VERIFICAR cómo inferirla del voltaje por celda como sugerencia), fecha de compra/instalación, nombre.
- **Snapshot completo del día 1** guardado como baseline (celdas, IR inicial, delta, resistencias de balanceo, config del BMS).
- Todo lo que después se llama "degradación" se calcula contra este baseline. Hacerlo la app, no el usuario con screenshots.

---

## 9. Módulo F — Alertas en background

Sin esto no existe "carga completa", "celda caliente", "desbalance pasó el umbral".

- Android: **foreground service** con notificación persistente mientras hay conexión BLE (ej. `flutter_foreground_task`; VERIFICAR restricciones de la versión de Android objetivo y consumo de batería del teléfono).
- Alertas configurables: carga completa, temperatura, delta, corriente anómala, desconexión.
- Recordar la restricción de hardware: el BMS acepta **una sola** conexión BLE. Si el teléfono está conectado en background, la app de JK no puede conectarse (y viceversa). Mostrarlo claro en la UI.

---

## 10. Módulo G — Auditoría de configuración (solo lectura)

Leer los settings del BMS y compararlos con rangos seguros para la química declarada:

> "Tu OVP está en 4,25 V/celda para NMC. Eso es peligroso."
> "Capacidad configurada: 40 Ah. Vendida como 45 Ah."

**Solo lectura.** La app **nunca** propone escribir ni ofrece un botón de "corregir". Explica qué cambiar y dice que se hace desde la app oficial bajo responsabilidad del usuario.

**VERIFICAR:** qué campos de configuración expone el protocolo BLE del JK en lectura (referencia: `syssi/esphome-jk-bms`).

---

## 11. Módulo H — Multi-batería y portabilidad

- Perfiles por batería (por ID de BMS), cada uno con su baseline e historial. Necesario para Taller y para quien cambia de pack.
- **Export/import de la base de datos** completa (archivo drift/SQLite comprimido) para cambiar de teléfono sin perder historial. Compartir por `share_plus`.
- Las inspecciones viven aparte y no cuentan como perfiles.

---

## 12. Riesgos

| Riesgo | Mitigación |
|---|---|
| Prometer exactitud que el test rápido no tiene | La palabra "estimación" y "test rápido" en pantalla y PDF. Umbrales conservadores. |
| Confiar en ciclos/capacidad editables | Marcarlos como no confiables siempre. Veredicto basado en física. |
| Controlador corta acelerador con freno | Tres formas de carga aceptadas, validadas por corriente medida. |
| Mercado pequeño de JK *Smart* con BLE | **VERIFICAR** cuántas motorinas en Cuba traen JK con BLE vs BMS genérico. Determina si es negocio o side income. |
| Piratería del APK y de claves | Licencia por dispositivo firmada; aceptar fuga; no gastar tiempo ahí. |
| Pantalla de "precio justo" que se equivoque | Fuera de alcance. |
| Cualquier escritura al BMS | Prohibida. Sin excepciones. |

---

## 13. Fuera de alcance (explícito)

- Escritura o configuración del BMS desde la app.
- Estimación de precio de la batería.
- Suscripción mensual individual.
- Servidor/backend para licencias (la validación es local; el bot de Telegram es opcional y posterior).
- ESP32 / logging de carga en Home Assistant (sigue como extensión futura del PRD v1.0).
- Publicación en Play Store.

---

## 14. Orden de construcción sugerido

Se agrega después de los milestones del PRD v1.0 (transporte, persistencia, parser, UI base):

1. **M7 — Licencias:** ID de dispositivo, validación Ed25519 local, gating de features por nivel, trial de 7 días. *Sin esto no se cobra nada.*
2. **M8 — Veredictos:** capa de interpretación sobre métricas existentes.
3. **M9 — Inspección:** modo separado, flujo guiado con detección de carga por corriente, buffer del test, cálculo posterior, veredicto.
4. **M10 — PDF:** reporte de mi batería, reporte de inspección, certificado firmado.
5. **M11 — Onboarding/baseline y multi-batería.**
6. **M12 — Alertas en background.**
7. **M13 — Auditoría de configuración.**

Se puede empezar a cobrar al terminar **M7–M9**. Lo demás es Pro más gordo.

**Prerrequisito:** los cambios de la sección 16 se aplican **antes de M2** del PRD v1.0. Después de M2 duelen.

---

## 15. Preguntas abiertas

- ¿Cuántas motorinas en Cuba tienen JK Smart con BLE? (tamaño real del mercado)
- ¿Precio actual de calle de un pack nuevo y de uso? (ancla de precio)
- ¿Qué hace el controlador de la Yoazaky 707 con freno + acelerador?
- ¿Qué números mira hoy el autor, y en qué orden, cuando prueba una batería de uso con la app de JK? Ese orden es literalmente el flujo de la pantalla de inspección.
- ¿Registrarse como TCP para pago en línea, o transferencia P2P al inicio?
- ¿Qué proporción de baterías de uso en el mercado traen Daly vs ANT vs JK? (lo responde el contador de la sección 16.5)

---

## 16. Cambios al PRD v1.0 — Abstracción multi-BMS (Daly / ANT)

### 16.1 Decisión

**No se implementan Daly ni ANT ahora.** Se termina JK completo, se cobra (M7–M9), se consiguen los primeros ~20 pagos reales, y **entonces** se agrega el segundo protocolo (probablemente Daly, según lo que diga el contador de 16.5), después ANT.

Razones:
- Tres protocolos antes de un producto que funcione es el camino a no terminar ninguno (misma lógica que dejó el ESP32 fuera del PRD v1.0).
- Cada protocolo son semanas de prueba contra hardware real. **VERIFICAR:** ¿hay un Daly y un ANT accesibles para probar? Sin hardware no se implementa, punto.
- Daly y ANT exponen **menos datos** que JK (Daly no da resistencia de balanceo ni IR por celda; ANT varía por modelo). La inspección se apoya justo en eso; cada protocolo requiere ajustar el veredicto, no solo parsear.

### 16.2 Por qué sí importa ahora

Cuando se compra una batería de uso, **el comprador no elige el BMS**. Si la mayoría de las baterías en venta traen Daly, la inspección solo sirve para una minoría y el feature estrella se muere. Por tanto, el código de JK se escribe **desde el día 1 como si fueran tres protocolos**, aunque solo exista uno.

Costo estimado: medio día de decisiones antes de M2. Costo de hacerlo después de M2: reescribir MetricsEngine, Repository y UI.

### 16.3 Estado actual del PRD v1.0 (lo que se toca)

El PRD v1.0 tiene las capas bien separadas y el parser es una clase sin estado — eso está bien. Pero:

- `BmsSnapshot` tiene `List<double> cellVoltages; // 20 elementos` y campos no nullables que otros BMS no dan.
- No existe noción de "qué protocolo es" ni de "qué datos existen y cuáles no".
- `FrameAssembler` es una capa compartida pero es 100 % JK (frames de 300 bytes, paquetes de 20).
- Los no-objetivos dicen "Soporte para otras marcas de BMS" y "multi-BMS o multi-pack".

### 16.4 Cambios concretos

**a) `BmsSnapshot`**

- Eliminar el comentario "20 elementos". `cellCount` = `cellVoltages.length`, **nunca una constante**.
- Volver nullable lo que Daly/ANT no siempre reportan: `cycleCount`, `remainingCapacityAh`, `balancingCells`, `balanceCurrent`.
- Agregar `List<double>? cellResistances` — el JK lo envía en el frame `0x03` (es el dato de ~0,38 Ω visto en la Yoazaky). Hoy no está en el snapshot y es central para la inspección.
- Agregar `String protocolId` y `String deviceId`.

```dart
class BmsSnapshot {
  final DateTime timestamp;             // del TELÉFONO
  final String protocolId;              // 'jk', 'daly', 'ant'...
  final String deviceId;
  final List<double> cellVoltages;      // largo variable
  final List<double>? cellResistances;  // JK sí, Daly no
  final double packVoltage;
  final double current;
  final List<double> temperatures;
  final double? mosfetTemp;
  final double? soc;
  final double? remainingCapacityAh;
  final int? cycleCount;
  final List<bool>? balancingCells;
  final double? balanceCurrent;
  final bool? chargeMosfetOn;
  final bool? dischargeMosfetOn;
  final Set<BmsWarning> warnings;       // enum genérico; cada protocolo mapea sus bits
}
```

**b) Interfaz de protocolo con capabilities**

```dart
abstract class BmsProtocol {
  String get id;
  BmsCapabilities get capabilities;
  bool matches(ScanResult r);                        // UUID de servicio, prefijo de nombre, etc.
  Stream<BmsSnapshot> bind(Stream<List<int>> rawBytes); // assembler + parser adentro
}

class BmsCapabilities {
  final bool hasCellResistances;
  final bool hasBalanceState;
  final bool canReadConfig;
  final bool hasCycleCount;
  final bool hasMosfetTemp;
  final bool hasRemainingCapacity;
}
```

`JkProtocol` implementa todo en `true`. Un futuro `DalyProtocol` implementa la mitad y **no toca nada más**.

**c) El `FrameAssembler` se mueve dentro del protocolo**

Deja de ser capa compartida. Daly usa frames de 13 bytes; ANT otra estructura. La capa queda:

```
BleTransport (bytes crudos)
   ↓
BmsProtocol  (assembler + parser propios de cada marca)
   ↓ Stream<BmsSnapshot>
MetricsEngine → Repository ←→ UI
```

MetricsEngine, Repository y UI **no conocen la marca**. Solo conocen el snapshot y las capabilities.

**d) MetricsEngine y UI leen capabilities**

- Si `hasCellResistances == false`, la sección no aparece y el veredicto de inspección dice "fidelidad reducida: este BMS no expone resistencia por celda".
- La inspección (sección 4) se degrada sola: sin IR usa sag y recuperación, y lo declara.
- **Nunca** indexar `cells[19]` ni asumir 20S en ninguna parte del código.

**e) Base de datos**

- `cellVoltages` (y `cellResistances`) como blob/JSON de largo variable, **no** 20 columnas fijas.
- Columna `protocol` en `snapshots` y en `raw_frames`. El reparseo retroactivo del PRD v1.0 depende de saber con qué parser reinterpretar cada frame.

### 16.5 Descubrimiento y BMS no soportado

Al escanear, cada `BmsProtocol` registrado responde si el dispositivo es suyo. Si ninguno lo reconoce:

- La app **no falla**: muestra "BMS no soportado todavía".
- Guarda localmente: nombre BLE anunciado, UUIDs de servicio, fecha. Incrementa un contador.
- Botón "Reportar este modelo" que arma un mensaje (Telegram/WhatsApp) con esos datos.

Ese contador es **el dato de mercado** que decide si el segundo protocolo es Daly o ANT, con números y no con "creo que".

### 16.6 Redacción nueva de los no-objetivos del PRD v1.0

Reemplazar:

> ~~Soporte para otras marcas de BMS.~~
> ~~Soporte multi-BMS o multi-pack.~~

por:

> **No implementar otros protocolos en v1.** El diseño debe permitir agregarlos como una clase nueva que implemente `BmsProtocol`, sin modificar MetricsEngine, Repository ni UI. Cualquier asunción de "20 celdas" o "JK" fuera de `JkProtocol` es un bug.

Multi-pack (perfiles por batería) pasa a la sección 11 de este documento.

### 16.7 Fuentes de protocolo para el futuro (no ahora)

Cuando llegue el momento, mismo criterio que el PRD v1.0: **cero offsets de memoria**, todo desde implementaciones de referencia y verificado con hardware.

- Daly: `Louisvdw/dbus-serialbattery` (soporta Daly), y librerías dedicadas de Daly BLE/UART en GitHub. **VERIFICAR** variante (UART-over-BLE) y si el modelo concreto trae BLE de fábrica o necesita dongle.
- ANT: `syssi/esphome-ant-bms`. **VERIFICAR** versión de protocolo del modelo concreto.
