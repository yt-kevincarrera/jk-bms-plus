# Diseño: soporte para ANT BMS (protocolo 2021)

**Fecha:** 2026-09-28
**Estado:** aprobado en conversación (enfoque A, siete secciones)
**Audiencia:** el autor y el agente de codificación

---

## 0. El problema

La app lee un solo BMS, JK, y está acoplada a él en todas las capas: el
transporte escribe comandos JK, el ensamblador busca `55 AA EB 90` y 300 bytes,
`BmsSnapshot` lleva un `JkProtocolVariant` obligatorio, las alarmas son los bits
JK02, `JkSettings` alimenta `PackConfig`, la auditoría y el motor de consejos, y
las tramas crudas se guardan y exportan como "300 bytes JK". Lo único neutral
hoy es `BmsLink`, `SwitchableLink` y la licencia (atada al teléfono, no al BMS).

El autor tiene un ANT, probablemente de 2021 en adelante, **en su casa**. Cada
prueba real cuesta un día: prueba de noche, trae el resultado a la oficina al
día siguiente. No hay ida y vuelta posible.

## 1. Objetivo y criterio de éxito

- Un ANT 2021 funciona con todo lo que ya existe y se deriva de lecturas: vista
  en vivo, viajes, autonomía, alertas, prueba de capacidad, reportes,
  inspección, backup y export. Solo lectura, igual que con JK: la app nunca
  escribe ajustes ni conmuta nada en el BMS.
- Lo que es exclusivamente JK (ajustes, auditoría de configuración, selector de
  variante) no aparece con un ANT, o dice que ese BMS no lo expone.
- **Una sola sesión en casa basta.** O funciona a la primera, o deja un backup
  con todo lo necesario para corregir el decodificador en la oficina sin volver
  a tocar el BMS.

## 2. Decisiones tomadas

| Decisión | Valor | Por qué |
|---|---|---|
| Enfoque | **A: abstraer el protocolo** detrás de `BmsProtocol` | B (traducir ANT a tramas JK falsas) miente en la DB y el backup, que es justo lo que hace falta para diagnosticar a distancia. C (un servicio paralelo) duplica 2400 líneas. |
| Referencia | `syssi/esphome-ant-bms`, componente `ant_bms_ble` | Mismo autor que la referencia JK que ya usa la app, con tramas reales como tests. |
| Detección | Nombre anunciado, marca recordada por dispositivo, pregunta una vez, más detección pasiva | ANT y JK comparten FFE0/FFE1. Probar mandando comandos de las dos marcas a ciegas significaría mandarle a un BMS bytes que no son suyos. |
| Alarmas | La máscara JK02 sigue siendo el vocabulario de la app; ANT traduce a ella | Las filas viejas de `Snapshots.warningsMask` no se migran y `warning_labels.dart` sigue valiendo. |
| Campos que ANT no informa | Nullable en `BmsSnapshot` | "null = este BMS no lo informa". El compilador encuentra a todos los consumidores; mostrar 0 sería mentir. |
| Ajustes ANT | **Fuera de alcance** | Leerlos exige pedir registro por registro; nada de lo aprobado los necesita. |
| ANT viejo (`DB DB`, 140 bytes) | **Fuera de alcance**, pero se reconoce y se dice | Si el equipo del autor resulta ser viejo, la app lo dice en vez de quedarse esperando. |

## 3. El protocolo ANT 2021 (lo que el código debe respetar)

Fuente: `components/ant_bms_ble/ant_bms_ble.cpp` y
`tests/components/ant_bms_ble/*.h` en `syssi/esphome-ant-bms@main`, leídos el
2026-09-28. Los CRC de todos los ejemplos se recalcularon y coinciden.

### 3.1 GATT y nombres

- Servicio `0xFFE0`, característica `0xFFE1` para **notify y write** (write
  without response). Existe `0xFFE2`; no se usa. Idénticos a JK.
- Nombres vistos: `ANT-BLE16ZMUB`, `ANT-BLE24BHUB`, `ANT-BLE04DMUB`,
  `ANT@BLE22AAUB` (con `@`). Regla: `^ANT[-@]`.

### 3.2 Pedidos (los dos únicos que la app enviará)

Formato de 10 bytes: `7E A1 | func | addr_lo addr_hi | len | crc_lo crc_hi | AA 55`.
CRC-16/MODBUS (init 0xFFFF, poly reflejado 0xA001, sin XOR final) sobre los
bytes 1..5 (desde `A1`), guardado little-endian.

| Pedido | Bytes | Cuándo |
|---|---|---|
| Estado | `7E A1 01 00 00 BE 18 55 AA 55` | Cada 2 s, siempre, mientras haya enlace |
| Info del dispositivo | `7E A1 02 6C 02 20 58 C4 AA 55` | Al suscribirse a notify; se repite con el estado hasta recibir una respuesta |

El BMS **no envía nada por su cuenta**. Existen además auth (0x23), escritura
de registro (0x51) y lectura de ajustes (0x02 a otras direcciones): la app no
los implementa, no hay constantes para ellos.

### 3.3 Respuestas y ensamblado

- `7E A1 | func | addr(2, LE) | data_len | data | crc(2, LE) | AA 55`.
  Longitud total `10 + data_len`. CRC sobre bytes `1 .. len-5`.
- Función de respuesta = pedido + 0x10: estado `0x11`; info y ajustes `0x12`,
  distinguidos por addr (`0x026C` es info).
- **Excepción:** la trama de info declara `data_len = 0x20` pero mide 48 bytes.
  Su CRC válido está en 6+0x20 (bytes 38..39); los bytes 40..45
  (`FF 0B 00 00 41 F2`) son desconocidos y se ignoran.
- Ensamblado, como la referencia: una notificación que empieza con `7E A1`
  descarta el buffer y abre uno nuevo; el buffer se descarta si pasa de 192
  bytes; fin de trama = tamaño ≥ 10 y **los dos últimos bytes** `AA 55` (un
  solo `55` aparece dentro de texto ASCII, y eso ya rompió a esphome, issue
  #172); después se valida longitud (salvo info) y CRC. Se descarta en CRC malo
  y al desconectar.

### 3.4 Trama de estado (0x11)

Todo little-endian. `T` = byte 8 (sondas de temperatura), `N` = byte 9
(celdas). `data_len = 106 + 2(N+T)`, total `116 + 2(N+T)`. `o = 2N + 2T`.

| Offset | Ancho | Tipo | Escala | Campo | Destino en `BmsSnapshot` |
|---|---|---|---|---|---|
| 7 | 1 | u8 | enum | Estado: 0 desconocido, 1 reposo, 2 carga, 3 descarga, 4 standby, 5 error | (consola, texto) |
| 8 | 1 | u8 | | T | |
| 9 | 1 | u8 | | N | `cellCount` |
| 10 | 8 | bits | | Protecciones (sin nombres conocidos) | se guarda en la trama cruda |
| 18 | 8 | bits | | Avisos (sin nombres conocidos) | se guarda en la trama cruda |
| 34+2i | 2 | u16 | 0.001 V | Celda i | `cellVoltages` |
| 34+2N+2j | 2 | i16 | 1 °C | Sonda j | `temperatures` |
| 34+o | 2 | i16 | 1 °C | MOSFET | `mosfetTemp` |
| 36+o | 2 | i16 | 1 °C | Balanceador | (consola) |
| 38+o | 2 | u16 | 0.01 V | Pack | `packVoltage` |
| 40+o | 2 | i16 | 0.1 A | Corriente, **positiva al cargar** | `current` sin invertir |
| 42+o | 2 | i16 | % | SOC | `soc` |
| 44+o | 2 | u16 | % | SOH | `soh` |
| 46+o | 1 | u8 | enum | MOSFET de carga (1 = encendido; resto = motivo) | `chargeMosfetOn`, alarmas |
| 47+o | 1 | u8 | enum | MOSFET de descarga | `dischargeMosfetOn`, alarmas |
| 48+o | 1 | u8 | enum | Balanceador (0 apagado) | `balancerActive` = distinto de 0 |
| 50+o | 4 | u32 | 1e-6 Ah | Capacidad total | `nominalCapacityAh` |
| 54+o | 4 | u32 | 1e-6 Ah | Capacidad restante | `remainingCapacityAh` |
| 58+o | 4 | u32 | 0.001 Ah | Ah de ciclo acumulados | `cycleCapacityAh` |
| 62+o | 4 | i32 | 1 W | Potencia | (se deriva, no se guarda) |
| 66+o | 4 | u32 | s | Tiempo total | `totalRuntimeSeconds` |
| 70+o | 4 | u32 | | Celdas balanceando (bit por celda) | (consola) |
| 74+o..84+o | | | | Máx/mín/delta/promedio de celda | se derivan de `cellVoltages` |
| 94+o | 2 | u16 | enum | Tipo de batería 0xFAF1..4 | (consola) |

La convención de corriente coincide con la de la app: en el JK real la descarga
es negativa (backup 2026-09-02) y el fixture ANT de 16S da +0.3 A con estado
"carga". El parser **no invierte** el signo; un test lo fija.

Textos de los enums de MOSFET y balanceador: tablas completas en
`ant_bms_ble.cpp` (`CHARGE_MOSFET_STATUS`, `DISCHARGE_MOSFET_STATUS`,
`BALANCER_STATUS`); se copian a `ant_constants.dart` y se traducen en las `.arb`.

### 3.5 Trama de info (0x12, addr 0x026C)

Bytes 6..21: modelo, ASCII de 16 bytes relleno con NUL. Bytes 22..37: versión
de software, ASCII de 16. **No hay número de serie.**

### 3.6 El ANT viejo, para reconocerlo

Responde tramas fijas de 140 bytes que empiezan con `AA 55 AA FF`, big-endian,
sin marcador de fin. Un equipo 2021 puede responder también al protocolo viejo
si se le pregunta con `DB DB`; la app nunca le pregunta así, de modo que ver
`AA 55 AA FF` sin haberlo pedido no debería pasar, y si pasa se informa.

## 4. Arquitectura

### 4.1 `BmsProtocol`

Nuevo, en `lib/src/protocol/bms_protocol.dart`:

```dart
enum BmsBrand { jk, ant }

sealed class BmsRecord {}
class SnapshotRecord extends BmsRecord { final BmsSnapshot snapshot; }
class DeviceInfoRecord extends BmsRecord { final BmsDeviceInfo info; }
class JkSettingsRecord extends BmsRecord { final JkSettings settings; }
class IgnoredRecord extends BmsRecord { final String reason; }

abstract interface class BmsProtocol {
  BmsBrand get brand;
  /// Lo que se escribe al quedar suscripto a notify.
  List<List<int>> get onConnect;
  /// Pedido periódico y cada cuánto; null = el BMS habla solo (JK).
  List<int>? get pollCommand;
  Duration get pollInterval;
  /// Pedido para cuando el BMS se calla (JK: 0x96; ANT: el mismo estado).
  List<int> get nudgeCommand;
  FrameAssemblerFor<RawBmsFrame> newAssembler();
  List<BmsRecord> decode(RawBmsFrame frame);
}
```

Los nombres exactos se fijan en el plan; lo que el diseño fija es la forma:
comandos como datos (el transporte los ejecuta sin entenderlos) y un decodificador
que devuelve registros neutrales.

`RawBmsFrame { brand, recordType, counter?, bytes }` reemplaza a `JkFrame` fuera
del paquete JK. `recordType` es el byte 4 en JK y el byte de función en ANT.

- **`JkProtocol`** envuelve `FrameAssembler`, `JkParser`,
  `JkProtocolVariantDetector` y `probeVariant` **sin cambiar su comportamiento**.
  El estado de variante (`_variant`, `_override`, `_variantConfirmed`,
  `overrideVariant`, `variantCorrections`) se muda de `BmsService` a
  `JkProtocol`; el servicio lo expone igual que hoy para la pestaña Sistema.
- **`AntProtocol`**: `AntFrameAssembler`, `AntParser`, `ant_crc.dart`
  (CRC-16/MODBUS), `ant_constants.dart`. Solo existen las dos constantes de
  pedido de §3.2.

### 4.2 Transporte

`BleTransport` deja de escribir comandos JK por su cuenta:

- `_writeCommand` y las llamadas a `requestDeviceInfo`/`requestCellInfo`
  pasan a escribir `protocol.onConnect`, `protocol.pollCommand` y
  `protocol.nudgeCommand`. Con JK los bytes resultantes son idénticos a hoy.
- Con `pollCommand` no nulo, un temporizador escribe el pedido cada
  `pollInterval` (2 s en ANT) mientras el enlace esté arriba. Los umbrales de
  silencio (`quietBefore` 6 s, `muteBefore` 20 s) se mantienen: con pedidos
  cada 2 s, 6 s sin trama son tres pedidos sin respuesta.
- `_armCellInfoRequests` en `BmsService` (hoy llama a
  `_switchable.real.requestCellInfo()` saltándose `BmsLink`) pasa por el
  protocolo.
- `NotAJkBmsException` pasa a `NotABmsException`. `BmsLink.frameAccepted` deja
  de decir "JK" en su doc; el contrato no cambia.
- `BmsLink` gana `set protocol(BmsProtocol p)`; `SwitchableLink` lo reenvía al
  transporte real; `SimulatedLink` lo ignora (siempre JK).

### 4.3 Detección de marca

- `classifyAdvertisement` gana `brandHint`: `^ANT[-@]` es `ant`, un nombre con
  "JK" es `jk`, el resto `null`. ANT cuenta como `likelyBms`.
- Al conectar, la marca sale de: `Devices.brand` guardada; si no, `brandHint`;
  si no, la pantalla de conexión pregunta una vez con dos opciones y guarda la
  respuesta.
- **Detección pasiva**, sin escribir nada extra: el servicio mira los bytes que
  llegan. Con JK elegido y `7E A1` al principio de una notificación, o con ANT
  elegido y `55 AA EB 90`, cambia de protocolo, guarda la marca nueva y lo
  registra como `LinkEvent`. Con `AA 55 AA FF` informa "este ANT usa el
  protocolo anterior a 2021, aún no soportado" y no cambia nada.

## 5. Modelo neutral

### 5.1 `BmsSnapshot`

- Gana `required BmsBrand brand`.
- `variant` pasa a `JkProtocolVariant?` (null en ANT).
- Pasan a nullable, null = este BMS no lo informa: `frameCounter`,
  `cellResistances`, `enabledCellMask`, `temperatureSensorMask`,
  `balancingAction`, `balanceCurrent`, `wireResistanceWarningMask`,
  `heatingOn`, `heatingCurrent`, `cycleCount`.
- `Plausibility` deja de depender de `variant.cellSlots` cuando `variant` es
  null: para ANT el tope de celdas es 32 y de sondas 4, que es lo que la trama
  puede declarar.
- Cada consumidor que el compilador marque decide: ocultar la fila (UI),
  saltar el cálculo (métricas), o escribir null (DB). Nunca se sustituye por 0.

### 5.2 Alarmas

`BmsWarning` sigue definido por los bits JK02 y `BmsWarnings.raw` sigue siendo
esa máscara. `AntParser` traduce los motivos de los MOSFET con esta tabla
cerrada; cualquier otro código no produce bit (se ve como texto en Sistema y
queda en la trama cruda). No se agregan bits nuevos a la máscara.

| MOSFET | Código | Motivo ANT | `BmsWarning` |
|---|---|---|---|
| carga | 0x02 | Overcharge protection | `packOvervoltage` (JK02 no tiene bit de sobretensión de celda; es el más cercano) |
| carga | 0x03 | Over current protection | `chargeOvercurrent` |
| carga | 0x04 | Battery full | `batteryFullyCharged` (informativo, no falla) |
| carga | 0x05 | Total overpressure | `packOvervoltage` |
| carga | 0x06 | Battery over temperature | `chargeOvertemperature` |
| carga | 0x07 | MOSFET over temperature | `mosfetOvertemperature` |
| carga | 0x11 | Low temperature protection | `chargeUndertemperature` |
| descarga | 0x02 | Overdischarge protection | `cellUndervoltage` |
| descarga | 0x03 | Over current protection | `dischargeOvercurrent` |
| descarga | 0x04 | Two current exceeded | `dischargeOcpII` |
| descarga | 0x05 | Total pressure undervoltage | `packUndervoltage` |
| descarga | 0x06 | Battery over temperature | `dischargeOvertemperature` |
| descarga | 0x07 | MOSFET over temperature | `mosfetOvertemperature` |
| descarga | 0x0C | Short circuit protection | `dischargeShortCircuit` |
| descarga | 0x0D | Discharge MOSFET abnormality | `dischargingMosfetAbnormal` |
| descarga | 0x0E | Open failed | `dischargeOnFailed` |
| descarga | 0x11 | Low temperature protection | `dischargeUndertemperatureAlarm` |

Los códigos 0x00 (apagado) y 0x01 (encendido) no son alarmas. "Manually turned
off" (0x0F) tampoco: es una decisión del dueño y se ve como texto.

### 5.3 Info del dispositivo

- Nuevo `BmsDeviceInfo { brand, model, softwareVersion, hardwareVersion?, serialNumber? }`.
- `JkDeviceInfo` sigue existiendo dentro del paquete JK y se convierte a
  `BmsDeviceInfo`; sus extras (passcodes, `VariantDetection`) se leen de
  `BmsService.jkDeviceInfo`, null con ANT.
- `BmsService.deviceInfo`/`lastDeviceInfo` pasan a `BmsDeviceInfo`.
- ANT no tiene serie: `Devices.serialNumber` queda null, `inspection_series`
  ya busca primero por dirección, y el certificado y los PDF escriben "sin
  número de serie".

### 5.4 Ajustes y capacidad

- `lastSettings` sigue siendo `JkSettings?`; con ANT siempre null. Se verifica
  que cada consumidor ya tolere null (hoy lo es hasta la primera trama).
- `_adoptCapacityFromBms` gana una segunda fuente: con ANT toma
  `nominalCapacityAh` del primer snapshot plausible.
- Auditoría de configuración y línea base del pack, con ANT: "este BMS no
  expone su configuración", sin sección vacía.

## 6. Persistencia

- `schemaVersion` 14 → 15:
  - `Devices.brand` texto nullable. Null se lee como `jk`, así las filas
    existentes no se tocan.
  - `RawFrames.brand` texto nullable, misma regla. `recordType` en ANT es el
    byte de función; `bytes` ya es blob de longitud libre.
- Backup `formatVersion` 1 → 2: marca en dispositivos y tramas crudas. Un
  backup v1 se restaura como JK. Un v2 en una app vieja ya se rechaza por
  `format > formatVersion`.
- `exportRawFrames`: la cabecera deja de decir "JK, 300 bytes"; cada línea
  lleva la marca.

## 7. Diagnóstico para la sesión única en casa

1. Toda trama ANT con CRC válido se guarda en `RawFrames` **antes** de
   decodificarla, como hoy con JK.
2. Los buffers ANT rechazados (CRC malo, longitud que no cuadra, forma
   desconocida) también se guardan, con `recordType 0x00`, tope 200 por
   conexión.
3. Una lectura ANT que no pasa `Plausibility` no alimenta viajes, historial ni
   alertas; aparece como problema en la pantalla de conexión y sus tramas
   quedan guardadas.
4. La pantalla de conexión y la consola en vivo muestran: marca, tramas de
   estado, de info, rechazadas y el último error de decodificación.
5. Procedimiento para el autor: conectar, esperar un minuto, hacer backup con
   tramas crudas, traer el archivo.
6. `test/ant_backup_replay_test.dart` toma un backup JSON (fixture), extrae las
   tramas ANT y las pasa por `AntFrameAssembler` y `AntParser`. Nace con un
   backup sintético construido con los fixtures de §9; el día que llegue el
   backup real se agrega como segundo fixture.

## 8. UI

- **Conexión:** insignia de marca en cada fila; ANT entra en "probables BMS";
  hoja "¿Qué BMS es?" cuando la marca no se sabe; mensajes de fallo neutrales
  (`connectSilentJk` pasa a un texto sin marca fija, o uno por marca).
- **Sistema:** con ANT se oculta el selector de variante; se muestran marca,
  modelo, software, estado de batería, motivo de cada MOSFET y del
  balanceador en texto, temperatura del balanceador y el aviso de ajustes.
- **Celdas y Térmica:** filas null ocultas (resistencias, máscaras, corriente de
  balanceo, calefactor).
- **Ahora:** el nombre de variante se reemplaza por marca (y variante solo en
  JK); `WaitingReason.variantUnknown` solo aplica a JK.
- Textos: las `.arb` se editan de forma quirúrgica (se reformatean enteras si
  no), en español sin rayas largas.
- El simulador demo sigue siendo JK.

## 9. Tests

Fixtures nuevos en `test/fixtures/ant_frames.dart`, copiados de
`syssi/esphome-ant-bms` (`tests/components/ant_bms_ble/frames_16s_status.h`,
`docs/pdus/model2021-req-7ea1010000be1855aa55.txt`, issue #172):

Estado 16S/2T, 152 bytes. Esperado: 52.84 V, +0.3 A, SOC 91, 280 Ah,
restante 252.602 Ah, sondas 1 y 2 °C, MOSFET 2 °C, balanceador 7 °C, ambos
MOSFET encendidos.

```
7E A1 11 00 00 8E 05 01 02 10 00 00 00 00 00 00 00 00 80 00 80 01 00 00 00 00 00 00 00 00 00 00 00 00 E4 0C E4 0C E5 0C E5 0C E8 0C E7 0C E7 0C E6 0C E8 0C E7 0C E7 0C E7 0C E7 0C E7 0C E6 0C E9 0C 01 00 02 00 02 00 07 00 A4 14 03 00 5B 00 64 00 01 01 00 00 00 76 B0 10 D5 67 0E 0F BA 32 4A 00 0F 00 00 00 10 58 2E 02 00 00 00 00 E9 0C 10 00 E4 0C 01 00 05 00 E6 0C 00 00 80 00 7A 00 0F 02 F2 FA B9 8C 3B 00 BB D8 58 00 DA 2D 43 00 E8 B6 49 00 05 43 AA 55
```

Estado 14S/4T, 152 bytes, captura real. Esperado: 57.58 V, 0 A, SOC 96; una
sonda lee -40 °C (`D8 FF`).

```
7E A1 11 00 00 8E 05 01 04 0E 02 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 1C 00 1C 00 D8 FF 1C 00 1C 00 1C 00 7E 16 00 00 60 00 64 00 01 02 00 00 80 C3 C9 01 4F 55 B3 01 08 53 00 00 00 00 00 00 6B 28 12 00 00 00 00 00 11 10 01 00 11 10 01 00 00 00 11 10 02 00 70 00 03 00 AC 02 F1 FA 7D 2E 00 00 94 77 00 00 DE 07 00 00 77 76 00 00 35 E2 AA 55
```

Info "16ZM" / "16ZMUB00-211026A":

```
7E A1 12 6C 02 20 31 36 5A 4D 00 00 00 00 00 00 00 00 00 00 00 00 31 36 5A 4D 55 42 30 30 2D 32 31 31 30 32 36 41 72 08 FF 0B 00 00 41 F2 AA 55
```

Info "22PHB8TB130A" / "22AAUB00-241008A" (se parte después del byte 27 para
cubrir el caso de la "U"):

```
7E A1 12 6C 02 20 32 32 50 48 42 38 54 42 31 33 30 41 00 00 00 00 32 32 41 41 55 42 30 30 2D 32 34 31 30 30 38 41 EF 2F FF 0B 00 00 41 F2 AA 55
```

Casos:

- **CRC:** los cuatro fixtures y los dos pedidos de §3.2.
- **Ensamblador:** cada fixture entero, en trozos de 20 bytes y en trozos del
  MTU; el corte en la "U"; basura antes de `7E A1`; buffer que pasa de 192;
  CRC malo (se rechaza y se guarda como 0x00).
- **Parser:** campo por campo contra los valores esperados; sonda -40 °C se
  conserva como lectura (es plausible); corriente sin invertir.
- **Alarmas:** cada fila de la tabla de §5.2 produce su bit; 0x00, 0x01, 0x0F
  y un código fuera de la tabla no producen ninguno.
- **Servicio:** `FakeLink` en modo ANT hasta repository, historial y alertas;
  detección por nombre; detección pasiva en los dos sentidos; aviso del ANT
  viejo; capacidad nominal adoptada del snapshot.
- **Solo lectura:** en modo ANT, todo lo que llega a la escritura del transporte
  es uno de los dos pedidos de §3.2. Se verifica a lo largo de una conexión con
  pedidos periódicos, empujones y reconexión.
- **Datos:** migración 14 → 15 con filas existentes (marca null se lee JK);
  restaurar un backup v1; ida y vuelta de un backup v2 con tramas ANT.
- **Regresión JK:** toda la suite actual pasa. Los cambios permitidos en tests
  existentes son renombres de tipos y el nuevo `brand` en `snapshot_builder`.
  Un test verifica que con JK los bytes escritos por el transporte son
  idénticos a los de hoy.

## 10. Fuera de alcance

Leer ajustes ANT por registros; el protocolo ANT viejo; ANT en el simulador
demo; conteo de ciclos ANT (la app ya calcula ciclos equivalentes desde los Ah);
balanceo por celda en la UI; cualquier escritura al BMS.
