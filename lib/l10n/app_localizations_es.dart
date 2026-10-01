// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppL10nEs extends AppL10n {
  AppL10nEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'JK BMS +';

  @override
  String get connectTitle => 'Conectar';

  @override
  String get connectOneConnectionWarning =>
      'El BMS acepta una sola conexión Bluetooth a la vez. Cierra la app oficial de tu BMS antes de conectar aquí.';

  @override
  String get connectScan => 'Buscar BMS';

  @override
  String get connectScanning => 'Buscando';

  @override
  String get connectScanFinished => 'Búsqueda terminada';

  @override
  String get connectLocationDenied =>
      'Android no entrega resultados de búsqueda Bluetooth si la app no tiene permiso de ubicación. Es una regla del sistema, no algo que necesite la app para rastrearte: la ubicación solo se usa cuando grabas un viaje. Sin ese permiso la búsqueda termina sin encontrar nada y sin decir por qué.';

  @override
  String get connectGrantLocation => 'Dar permiso';

  @override
  String connectSeenCount(String count) {
    return '$count dispositivos Bluetooth vistos';
  }

  @override
  String get connectNothingFoundHelp =>
      'No apareció nada. Casi siempre es una de estas:\n\n• La app oficial de tu BMS está conectada a él. Mientras lo está, el BMS deja de anunciarse y ningún otro teléfono lo ve. Ciérrala del todo.\n• El pack está dormido. Enciende la moto o muévela para despertarlo.\n• Estás lejos. Acércate al pack.';

  @override
  String get connectCancelScan => 'Cancelar búsqueda';

  @override
  String get connectNoDevices => 'Todavía no aparece ningún BMS';

  @override
  String get connectLocationOff =>
      'La ubicación del teléfono está apagada. Android no entrega resultados de búsqueda Bluetooth sin ella, aunque le hayas dado el permiso a la app: devuelve cero dispositivos sin avisar. Enciéndela y vuelve a buscar.';

  @override
  String get connectOtherDevices => 'Otros dispositivos cerca';

  @override
  String get connectOtherDevicesHint =>
      'La app no oculta nada. Si tu BMS tiene otro nombre, porque lo cambiaste en la app oficial o porque ese modelo no anuncia el suyo, va a salir en esta lista. Búscalo por la señal más fuerte y pruébalo.';

  @override
  String get connectLikelyBms => 'probable BMS';

  @override
  String get connectByService => 'anuncia el servicio JK';

  @override
  String get brandAskTitle => '¿Qué BMS es?';

  @override
  String get brandAskBody =>
      'El nombre no lo dice. Elige la marca una vez; la app la recuerda.';

  @override
  String get brandJk => 'JK (Jikong)';

  @override
  String get brandAnt => 'ANT';

  @override
  String get tapBusy =>
      'Ya hay un intento en marcha. Espera a que termine: tocar otra vez no lo acelera y sí puede dejar otra conexión colgada en el teléfono.';

  @override
  String tapCooling(String seconds) {
    return 'Espera $seconds s antes de reintentar con esta batería. La pausa no es un capricho: el BMS tarda unos segundos en soltar el enlace anterior, y cada intento dentro de esa ventana deja una conexión que el teléfono no cierra.';
  }

  @override
  String tapStackSaturated(String count) {
    return 'Van $count intentos fallidos seguidos. A estas alturas el problema es el Bluetooth del teléfono, no la batería, y otro intento solo lo empeora. Sigue los pasos de la tarjeta de arriba y después vuelve a buscar para reintentar.';
  }

  @override
  String get tileConnected => 'Conectada. Toca para volver a sus pantallas.';

  @override
  String tileCooling(String seconds) {
    return 'En pausa $seconds s tras un intento fallido';
  }

  @override
  String get tileStackSaturated =>
      'En espera: el Bluetooth del teléfono necesita reiniciarse';

  @override
  String get tilePillOpen => 'abierta';

  @override
  String get connectedCardNote =>
      'El enlace sigue abierto. Salir de las pantallas de la batería ya no lo corta, así que puedes entrar y salir sin reconectar.';

  @override
  String get connectedCardOpen => 'Ver la batería';

  @override
  String get connectedCardRelease => 'Desconectar';

  @override
  String get connectNoBle => 'Este teléfono no tiene Bluetooth LE.';

  @override
  String get connectBluetoothOff =>
      'El Bluetooth está apagado. Enciéndelo y vuelve a buscar.';

  @override
  String get connectDemoButton => 'Abrir modo demo';

  @override
  String get connectDemoHint =>
      'El modo demo corre un pack 20S simulado a través del parser real, para ver todas las pantallas sin ningún BMS cerca.';

  @override
  String get tabNow => 'Ahora';

  @override
  String get tabCells => 'Celdas';

  @override
  String get tabThermal => 'Térmico';

  @override
  String get tabHistory => 'Viajes';

  @override
  String get tabSystem => 'Sistema';

  @override
  String get demoBanner => 'DEMO: pack simulado, sin BMS conectado';

  @override
  String get demoTitle => 'Modo demo';

  @override
  String get demoExplanation =>
      'Un pack 20S simulado genera frames reales de 300 bytes. Pasan por el mismo checksum, ensamblado y parser que usará el hardware, así que estas pantallas están cableadas exactamente como estarán en la moto. Los valores en sí son modelados, no medidos.';

  @override
  String get demoScenarioRiding => 'Rodando';

  @override
  String get demoScenarioRidingDesc =>
      'Acelerador variable, caída de tensión bajo carga, SOC bajando';

  @override
  String get demoScenarioCharging => 'Cargando';

  @override
  String get demoScenarioChargingDesc =>
      'Carga estable, el delta se abre cerca del tope';

  @override
  String get demoScenarioIdle => 'Detenida';

  @override
  String get demoScenarioIdleDesc => 'Sin corriente, celdas relajadas';

  @override
  String get demoScenarioWeakCell => 'Celda débil';

  @override
  String get demoScenarioWeakCellDesc =>
      'La celda 7 cae fuerte, balanceador activo, alarmas encendidas';

  @override
  String get demoPackName => 'Pack demo';

  @override
  String get healthGood => 'Todo en orden';

  @override
  String get healthWatch => 'Vigilar';

  @override
  String get healthBad => 'Problema';

  @override
  String waitingFor(String what) {
    return 'Esperando $what';
  }

  @override
  String get waitingFirstReading => 'la primera lectura';

  @override
  String get waitingWhyLinkDown =>
      'El enlace Bluetooth no está conectado ahora mismo. La app sigue intentándolo sola; si no vuelve, arriba aparece el motivo.';

  @override
  String get waitingWhyNoFrames =>
      'Conectado, pero no ha llegado ni un frame del BMS. O la batería está callada con la app, o algo más tiene su sesión de datos.';

  @override
  String get waitingWhyOnlyDeviceInfo =>
      'Llegó la información del dispositivo, pero ninguna lectura de celdas. La app se la vuelve a pedir a la batería cada 3 segundos.';

  @override
  String get waitingWhyVariantUnknown =>
      'Llegan lecturas de celdas, pero la app no pudo determinar qué variante del protocolo habla esta batería y no las decodifica. Elige la variante a mano en Sistema.';

  @override
  String get waitingWhyDecodeFailing =>
      'Llegan lecturas de celdas, pero fallan al decodificar. El motivo exacto está en los avisos de abajo y en Sistema.';

  @override
  String get waitingWhyUnexplained =>
      'Llegan lecturas, se decodifican y se emiten, pero ninguna alcanzó esta pantalla. Eso es un fallo de la app: haz captura de esta pantalla y mándala.';

  @override
  String get waitingCellVoltages => 'los voltajes de celda';

  @override
  String get waitingTemperatures => 'las temperaturas';

  @override
  String get soc => 'Carga';

  @override
  String get range => 'Autonomía restante';

  @override
  String get rangeDisclaimer =>
      'Estimación aproximada desde la energía restante. El valor real sale del Wh/km medido con GPS.';

  @override
  String get power => 'Potencia';

  @override
  String get current => 'Corriente';

  @override
  String get packVoltage => 'Pack';

  @override
  String get cellDelta => 'Delta';

  @override
  String get average => 'Promedio';

  @override
  String get charging => 'cargando';

  @override
  String get discharging => 'descargando';

  @override
  String get resting => 'en reposo';

  @override
  String get sessionTitle => 'Esta sesión';

  @override
  String get sessionEnergy => 'Energía sacada del pack';

  @override
  String get sessionDistance => 'Distancia';

  @override
  String get sessionWhPerKm => 'Wh por km';

  @override
  String get sessionSamples => 'Muestras en memoria';

  @override
  String get needsGps => 'necesita un viaje activo';

  @override
  String get packTitle => 'Pack';

  @override
  String get packRemaining => 'Restante';

  @override
  String packRemainingValue(String remaining, String nominal) {
    return '$remaining de $nominal Ah';
  }

  @override
  String get packCycles => 'Ciclos';

  @override
  String get packSoh => 'Salud';

  @override
  String get packSag => 'Caída bajo carga';

  @override
  String get packSagNoBaseline => 'sin reposo reciente con qué comparar';

  @override
  String get packMosfets => 'MOSFETs';

  @override
  String get mosfetChargeOn => 'carga on';

  @override
  String get mosfetChargeOff => 'carga off';

  @override
  String get mosfetDischargeOn => 'descarga on';

  @override
  String get mosfetDischargeOff => 'descarga off';

  @override
  String cellsLowest(int index, String voltage) {
    return 'Más baja: celda $index con $voltage V';
  }

  @override
  String cellsHighest(int index, String voltage) {
    return 'Más alta: celda $index con $voltage V';
  }

  @override
  String get cellsSpreadTitle => 'Dispersión';

  @override
  String get cellsDeviationHint =>
      'Las barras muestran la desviación respecto del promedio, no el voltaje absoluto: a 3,9 V nominales veinte barras llenas idénticas no dirían nada.';

  @override
  String get balancingTitle => 'Balanceo';

  @override
  String get balancerState => 'Balanceador';

  @override
  String get balancerBadge => 'Balanceando';

  @override
  String get balancerWorking => 'trabajando';

  @override
  String get balancerIdle => 'en reposo';

  @override
  String get balanceCurrent => 'Corriente de balanceo';

  @override
  String get balanceDirection => 'Dirección';

  @override
  String get balanceDirectionCharge => 'moviendo carga hacia las celdas bajas';

  @override
  String get balanceDirectionDischarge => 'drenando las celdas altas';

  @override
  String get balanceDirectionOff => 'sin actividad';

  @override
  String get balanceActiveNote =>
      'Este BMS es un balanceador activo: mueve carga entre celdas en vez de quemarla en resistencias, así que puede trabajar con corrientes mucho mayores que un balanceador pasivo.';

  @override
  String get balanceWhichCells => 'Qué celdas';

  @override
  String get balanceWhichCellsValue => 'deducido, el BMS no lo informa';

  @override
  String get balanceRanking => 'Más veces la más baja';

  @override
  String get resistanceTitle => 'Cables de balanceo';

  @override
  String get resistanceSource => 'Origen';

  @override
  String get resistanceSourceValue =>
      'medición de cada cable de balanceo del propio BMS, no de la celda';

  @override
  String get resistanceWireWarnings => 'Alarmas de resistencia de cable';

  @override
  String get none => 'ninguna';

  @override
  String thermalProbe(int index) {
    return 'Sonda $index';
  }

  @override
  String get thermalMosfet => 'MOSFET';

  @override
  String thermalLastMinutes(int minutes) {
    return 'Últimos $minutes minutos';
  }

  @override
  String thermalSamples(int count) {
    return '$count muestras';
  }

  @override
  String get thermalCollecting => 'Juntando muestras';

  @override
  String get thermalLegendHottest => 'Sonda más caliente';

  @override
  String get thermalLegendCurrent => 'Corriente (|A|)';

  @override
  String get thermalSensorsTitle => 'Sensores';

  @override
  String get thermalProbesReported => 'Sondas informadas';

  @override
  String get thermalMosfetSensor => 'Sensor de MOSFET';

  @override
  String get reported => 'informado';

  @override
  String get notReported => 'no informado';

  @override
  String get thermalSensorMask => 'Máscara de sensores';

  @override
  String get thermalHeater => 'Calefactor';

  @override
  String get thermalHeaterCurrent => 'Corriente del calefactor';

  @override
  String get on => 'on';

  @override
  String get off => 'off';

  @override
  String get thermalMaskNote =>
      'La máscara se muestra cruda y no se oculta ninguna lectura por su causa. La implementación de referencia la llama máscara de sensores «ausentes», pero las capturas reales encienden bits de sondas que claramente funcionan. Ver docs/PROTOCOL.md.';

  @override
  String get historyItemCapacity =>
      'Capacidad medida en cada descarga completa, y cómo cambia con los meses';

  @override
  String get historyItemTrips => 'Lista de viajes con distancia, Wh y Wh/km';

  @override
  String get historyItemDelta =>
      'Delta contra el nivel de carga, que es donde una celda corta se delata';

  @override
  String get historyItemSag =>
      'Resistencia aparente de cada viaje, sacada de la caída de tensión para la corriente pedida';

  @override
  String get systemDeviceTitle => 'Equipo';

  @override
  String get systemModel => 'Modelo';

  @override
  String get systemHardware => 'Hardware';

  @override
  String get systemSoftware => 'Firmware';

  @override
  String get systemSerial => 'Número de serie';

  @override
  String get systemManufactured => 'Fabricado';

  @override
  String get systemPowerOnCount => 'Encendidos';

  @override
  String get systemUptime => 'Tiempo encendido';

  @override
  String get systemDeviceInfoMissing => 'todavía no llegó';

  @override
  String get systemBrand => 'Marca';

  @override
  String get systemVariantTitle => 'Variante de protocolo';

  @override
  String get systemVariantInUse => 'En uso';

  @override
  String get systemVariantUndecided => 'sin decidir';

  @override
  String get systemVariantAuto => 'Automático';

  @override
  String get systemVariantWarning =>
      'Cambia esto si los valores decodificados se ven mal. Elegir la variante equivocada no falla de forma ruidosa: decodifica en los offsets incorrectos y produce números creíbles pero falsos.';

  @override
  String get systemVariantProved =>
      'Comprobado contra una lectura real: los números que salen con este formato describen una batería posible.';

  @override
  String get systemVariantCorrected =>
      'La app cambió de formato por su cuenta. La versión del firmware apuntaba a otro, y con ese los números eran imposibles: este es el que cuadra con la lectura.';

  @override
  String get antStatusTitle => 'Estado ANT';

  @override
  String get antBatteryState => 'Estado de la batería';

  @override
  String get antChargeMosfet => 'MOSFET de carga';

  @override
  String get antDischargeMosfet => 'MOSFET de descarga';

  @override
  String get antBalancer => 'Balanceador';

  @override
  String get antBalancerTemp => 'Temperatura del balanceador';

  @override
  String antBatteryStateCode(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      '0': 'Desconocido',
      '1': 'Inactiva',
      '2': 'Cargando',
      '3': 'Descargando',
      '4': 'En espera',
      '5': 'Error',
      'other': 'Desconocido',
    });
    return '$_temp0';
  }

  @override
  String antChargeMosfetCode(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      '0': 'Apagado',
      '1': 'Encendido',
      '2': 'Protección por sobrecarga',
      '3': 'Protección por sobrecorriente',
      '4': 'Batería llena',
      '5': 'Sobretensión del pack',
      '6': 'Sobretemperatura de la batería',
      '7': 'Sobretemperatura del MOSFET',
      '8': 'Corriente anómala',
      '9': 'Cable de balanceo desconectado',
      '10': 'Sobretemperatura de la placa',
      '11': 'Reservado',
      '12': 'No se pudo encender',
      '13': 'Fallo del MOSFET de descarga',
      '14': 'En espera',
      '15': 'Apagado manualmente',
      '16': 'Sobretensión de segundo nivel',
      '17': 'Protección por baja temperatura',
      '18': 'Diferencia de voltaje excesiva',
      '19': 'Reservado',
      '20': 'Error de autodiagnóstico',
      'other': 'Desconocido',
    });
    return '$_temp0';
  }

  @override
  String antDischargeMosfetCode(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      '0': 'Apagado',
      '1': 'Encendido',
      '2': 'Protección por sobredescarga',
      '3': 'Protección por sobrecorriente',
      '4': 'Sobrecorriente de segundo nivel',
      '5': 'Subtensión del pack',
      '6': 'Sobretemperatura de la batería',
      '7': 'Sobretemperatura del MOSFET',
      '8': 'Corriente anómala',
      '9': 'Cable de balanceo desconectado',
      '10': 'Sobretemperatura de la placa',
      '11': 'MOSFET de carga encendido',
      '12': 'Protección por cortocircuito',
      '13': 'Fallo del MOSFET de descarga',
      '14': 'No se pudo encender',
      '15': 'Apagado manualmente',
      '16': 'Subtensión de segundo nivel',
      '17': 'Protección por baja temperatura',
      '18': 'Diferencia de voltaje excesiva',
      '19': 'Error de autodiagnóstico',
      'other': 'Desconocido',
    });
    return '$_temp0';
  }

  @override
  String antBalancerCode(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      '0': 'Apagado',
      '1': 'Balanceo por límite superado',
      '2': 'Balanceo por diferencia de voltaje en carga',
      '3': 'Sobretemperatura del balanceo',
      '4': 'Balanceo automático',
      '10': 'Sobretemperatura de la placa',
      'other': 'Desconocido',
    });
    return '$_temp0';
  }

  @override
  String antUnknownCode(String hex) {
    return 'Desconocido (0x$hex)';
  }

  @override
  String get systemConnectionTitle => 'Conexión';

  @override
  String get systemMtu => 'MTU';

  @override
  String systemMtuValue(int bytes) {
    return '$bytes bytes';
  }

  @override
  String get unknown => 'desconocido';

  @override
  String get systemFramesOk => 'Frames aceptados';

  @override
  String get systemFramesBadChecksum => 'Checksum inválido';

  @override
  String get systemFramesUnsupported => 'Tipo no soportado';

  @override
  String get systemAcceptRate => 'Tasa de aceptación';

  @override
  String get systemBytesReceived => 'Bytes recibidos';

  @override
  String get systemSettingsTitle => 'Configuración del BMS';

  @override
  String get settingsNotExposed =>
      'Este BMS no expone su configuración a la app.';

  @override
  String get systemNotices => 'Avisos';

  @override
  String get systemRawConsole => 'Consola de frames crudos';

  @override
  String get systemReadOnlyNote =>
      'Con el permiso de escritura apagado, la app no cambia nada en el BMS: todo lo de arriba es solo lectura.';

  @override
  String get systemLanguageTitle => 'Idioma';

  @override
  String get systemLanguageSpanish => 'Español';

  @override
  String get systemLanguageEnglish => 'English';

  @override
  String get systemLanguageSystem => 'Del sistema';

  @override
  String get settingCellCount => 'Cantidad de celdas';

  @override
  String get settingNominalCapacity => 'Capacidad nominal';

  @override
  String get settingCellOvp => 'Sobretensión de celda';

  @override
  String get settingCellOvpRecovery => 'Recuperación de sobretensión';

  @override
  String get settingCellUvp => 'Subtensión de celda';

  @override
  String get settingCellUvpRecovery => 'Recuperación de subtensión';

  @override
  String get settingPowerOff => 'Voltaje de corte';

  @override
  String get settingMaxCharge => 'Corriente máx. de carga';

  @override
  String get settingMaxDischarge => 'Corriente máx. de descarga';

  @override
  String get settingMaxBalance => 'Corriente máx. de balanceo';

  @override
  String get settingBalanceStart => 'Voltaje de inicio de balanceo';

  @override
  String get settingBalanceTrigger => 'Delta que dispara el balanceo';

  @override
  String get settingChargeOtp => 'Sobretemperatura en carga';

  @override
  String get settingDischargeOtp => 'Sobretemperatura en descarga';

  @override
  String get settingChargeUtp => 'Subtemperatura en carga';

  @override
  String get settingMosfetOtp => 'Sobretemperatura de MOSFET';

  @override
  String get settingSwitches => 'Interruptores';

  @override
  String get consoleTitle => 'Frames crudos';

  @override
  String get consoleFollow => 'Siguiendo';

  @override
  String get consolePaused => 'Pausado';

  @override
  String get consoleCopy => 'Copiar registro';

  @override
  String get consoleCopied => 'Registro copiado';

  @override
  String get consoleViewDecoded => 'Decodificado';

  @override
  String get consoleViewBytes => 'Bytes';

  @override
  String get consoleCopyAll => 'Copiar todo para diagnóstico';

  @override
  String get consoleCopiedAll =>
      'Copiado: contadores, avisos, registro y bytes';

  @override
  String get consoleLiveFromHere => '--- en vivo desde aquí ---';

  @override
  String get consoleNoBytes =>
      'Todavía no pasó ningún byte por el enlace desde que se abrió la app.';

  @override
  String get consoleBytesLegend =>
      '← recibido del BMS · → escrito por la app. Se conserva entre conexiones.';

  @override
  String get consoleThisConnection => 'Esta conexión';

  @override
  String consoleLastReading(int seconds) {
    return 'última lectura hace $seconds s';
  }

  @override
  String get consoleReportTitle => 'Consola de frames crudos';

  @override
  String get consoleReportNotices => 'Avisos, del más antiguo al más reciente';

  @override
  String get consoleReportDecoded => 'Registro decodificado';

  @override
  String get consoleReportBytes => 'Bytes, del más antiguo al más reciente';

  @override
  String get systemCountersThisConnection =>
      'Frames y bytes cuentan desde la última conexión. Caídas, tiempo desconectado e insistencias cuentan desde que se abrió la app.';

  @override
  String get tabHealth => 'Salud';

  @override
  String get healthTitle => 'Lo que el fabricante no te muestra';

  @override
  String get healthIntro =>
      'Estos números salen de lo que el BMS ya informa, cruzados entre sí. Ninguno es un dato que el fabricante publique.';

  @override
  String get healthRealCapacity => 'Capacidad real implícita';

  @override
  String get healthRealCapacityHint =>
      'Sin tests de capacidad, la cifra de arriba es la capacidad configurada en el BMS: el BMS calcula los Ah restantes como el SOC por esa capacidad, así que dividir una cosa por la otra la devuelve tal cual. No dice nada del desgaste; para eso hace falta medir una descarga completa.';

  @override
  String get healthClaimedCapacity => 'Nominal configurada en el BMS';

  @override
  String get healthSpecCapacity => 'Capacidad de catálogo';

  @override
  String get healthCapacityLoss => 'Pérdida frente a catálogo';

  @override
  String get healthEquivalentCycles => 'Ciclos completos equivalentes';

  @override
  String get healthEquivalentCyclesHint =>
      'Ah totales que el BMS contó pasar por el pack, divididos por su capacidad configurada. El contador de ciclos del propio BMS puede quedar por encima o por debajo de esta cifra: cuenta en números enteros y cada firmware decide qué es un ciclo.';

  @override
  String get healthReportedCycles => 'Ciclos que informa el BMS';

  @override
  String get healthCycleInflation => 'Inflación del contador';

  @override
  String get healthImbalanceLoss => 'Capacidad perdida por desbalance';

  @override
  String get healthImbalanceHint =>
      'El pack se corta cuando la celda más baja llega al límite, no cuando llega el promedio. Se mide con las celdas en reposo: el voltaje de la más baja y el de la media se pasan a nivel de carga con la curva típica de la química, y la diferencia se traduce a la energía que queda atrapada en las demás. Bajo carga o con el cargador puesto no se calcula, porque la caída o el empuje del cargador se confundirían con desequilibrio. En LFP, en la zona plana de la curva, el voltaje no dice cuánta carga hay, así que tampoco.';

  @override
  String get healthWeakestCell => 'Celda que manda';

  @override
  String healthWeakestCellValue(int index) {
    return 'celda $index';
  }

  @override
  String get healthWeakestCellHint =>
      'El pack vale lo que vale su peor celda. Es la que llega primero al corte y la que define la autonomía real.';

  @override
  String get healthResistanceSpread => 'Dispersión de resistencia';

  @override
  String healthResistanceSpreadValue(String percent) {
    return 'la peor está $percent% por encima de la mediana';
  }

  @override
  String get healthSohReported => 'Salud que informa el BMS';

  @override
  String get healthSohSuspect =>
      'Muchos firmwares dejan este número fijo y no lo recalculan nunca. Tratalo como decorativo hasta que lo veas moverse.';

  @override
  String get healthNeedsHistoryTitle => 'Necesita histórico';

  @override
  String get healthNeedsHistoryBody =>
      'La degradación medida necesita al menos dos descargas completas. La deriva de una celda y la evolución de la caída de tensión necesitan semanas de lecturas guardadas. Lo que sale de viajes y lecturas se va llenando solo; la capacidad no: cada punto es una descarga completa.';

  @override
  String get healthNotEnoughData => 'sin datos suficientes';

  @override
  String get healthCapacityUnavailable =>
      'Con el SOC muy bajo o muy alto este cálculo se vuelve ruido, así que no se muestra.';

  @override
  String get rangeLearning => 'aprendiendo';

  @override
  String get rangeEstimatorTitle => 'Autonomía adaptativa';

  @override
  String get rangeEstimatorIntro =>
      'La app mide los Wh que realmente salen del pack y los divide por los kilómetros del GPS del teléfono. Cada viaje corrige la estimación, así que el número se ajusta a cómo conduces tú, en tu terreno, con tu carga.';

  @override
  String get rangeConsumption => 'Consumo aprendido';

  @override
  String get rangeConsumptionDefault => 'valor inicial por defecto';

  @override
  String get rangeSamples => 'Kilómetros aprendidos';

  @override
  String get rangeConfidence => 'Confianza';

  @override
  String get rangeConfidenceLow => 'baja';

  @override
  String get rangeConfidenceMedium => 'media';

  @override
  String get rangeConfidenceHigh => 'alta';

  @override
  String rangeBand(String low, String high) {
    return 'entre $low y $high km';
  }

  @override
  String get rangeUsableEnergy => 'Energía utilizable';

  @override
  String get rangeUsableHint =>
      'La energía que queda son los Ah restantes que informa el BMS por el voltaje medio al que van a salir hasta el corte, leído de la curva típica de la química del pack. No por el voltaje de este momento, que sube con el cargador puesto y baja al acelerar. Después se descuenta lo que deja atrapado la celda más baja. Si no se sabe la química, se usa una cifra a la baja. Las curvas son las típicas de cada química, no medidas en este pack.';

  @override
  String get rangeNeedsGps =>
      'La distancia sale del GPS del teléfono durante un viaje. El BMS no informa posición: el protocolo tiene bits de bloqueo por GPS, pero ningún campo de coordenadas.';

  @override
  String get rangeDemoNote =>
      'En modo demo la distancia también es simulada, para que se pueda ver cómo se comporta el estimador.';

  @override
  String get systemPasscode => 'Contraseña que entrega el BMS';

  @override
  String get systemPasscodeHint =>
      'El BMS incluye su propia contraseña, en texto plano, dentro del frame de información de equipo. Cualquier cliente Bluetooth que se conecte puede leerla: no hay autenticación en ninguna parte de este protocolo. Esta app solo lee, pero conviene saberlo.';

  @override
  String get systemPasscodeEmpty => 'no la informa';

  @override
  String get linkIdle => 'en espera';

  @override
  String get linkScanning => 'buscando';

  @override
  String get linkConnecting => 'conectando';

  @override
  String get linkNegotiating => 'negociando';

  @override
  String get linkConnected => 'conectado';

  @override
  String get linkReconnecting => 'reconectando';

  @override
  String get linkFailed => 'falló';

  @override
  String variantReasonUnreadable(String version, String model) {
    return 'No se pudo leer una versión mayor de «$version» en el modelo $model.';
  }

  @override
  String variantReasonModern(String version, int major) {
    return 'Firmware $version (mayor $major ≥ 11).';
  }

  @override
  String variantReasonLegacy(String version, int major) {
    return 'Firmware $version (mayor $major < 11) implica JK02_24S, pero la familia de balanceadores JK04 también informa versiones por debajo de 11. Confirma que los valores decodificados tengan sentido antes de confiar en ellos.';
  }

  @override
  String get healthGaugeLabel => 'Salud';

  @override
  String get healthGaugeMeasured => 'medida';

  @override
  String get healthGaugeReported => 'la informa el BMS';

  @override
  String get healthVerdictGood => 'El pack está como debería';

  @override
  String get healthVerdictWatch => 'El pack perdió algo de capacidad';

  @override
  String get healthVerdictBad => 'El pack está bastante gastado';

  @override
  String get healthHowCalculated => 'Cómo se calcula esto';

  @override
  String get healthCardCapacity => 'Restante según el BMS';

  @override
  String get healthCardLoss => 'Pérdida';

  @override
  String get healthCardCycles => 'Ciclos equivalentes (según el BMS)';

  @override
  String get healthCardUsable => 'Energía utilizable';

  @override
  String get healthCardConsumption => 'Consumo';

  @override
  String get healthCardLearnedKm => 'Km aprendidos';

  @override
  String get tripTitle => 'Viaje';

  @override
  String get tripOpen => 'Modo viaje';

  @override
  String get tripStart => 'Empezar viaje';

  @override
  String get tripPause => 'Pausar';

  @override
  String get tripResume => 'Reanudar';

  @override
  String get tripStop => 'Terminar';

  @override
  String get tripRecording => 'grabando';

  @override
  String get tripPaused => 'en pausa';

  @override
  String get tripIdle => 'sin viaje';

  @override
  String get tripDistance => 'Distancia';

  @override
  String get tripSpeed => 'Velocidad';

  @override
  String get tripMaxSpeed => 'Máxima';

  @override
  String get tripAvgSpeed => 'Promedio';

  @override
  String get tripMoving => 'En movimiento';

  @override
  String get tripElapsed => 'Transcurrido';

  @override
  String get tripConsumption => 'Consumo';

  @override
  String get tripEnergyOut => 'Energía usada';

  @override
  String get tripEnergyIn => 'Recuperada';

  @override
  String get tripSocUsed => 'Carga gastada';

  @override
  String get tripSocPerKm => 'Carga por km';

  @override
  String get tripResistance => 'Resistencia del pack (aprox.)';

  @override
  String get tripMaxCurrent => 'Corriente máxima';

  @override
  String get tripMaxTemp => 'Temperatura máxima';

  @override
  String get tripMaxDelta => 'Delta máximo';

  @override
  String get tripClimb => 'Subida';

  @override
  String get tripDescent => 'Bajada';

  @override
  String get tripSummaryTitle => 'Viaje terminado';

  @override
  String get tripNotSaved =>
      'El viaje queda guardado con su recorrido. Puedes verlo después en la pestaña Viajes.';

  @override
  String get tripHowItLearns =>
      'Al terminar, los Wh medidos y los km recorridos se suman al estimador de autonomía. Cada viaje lo corrige un poco más.';

  @override
  String get tripPackDuring => 'Cómo se portó el pack';

  @override
  String get tripClose => 'Cerrar';

  @override
  String get locationDisabled =>
      'La ubicación del teléfono está apagada. Actívala para registrar distancia.';

  @override
  String get locationDenied =>
      'Sin permiso de ubicación no se puede medir distancia ni velocidad.';

  @override
  String get locationDeniedForever =>
      'El permiso de ubicación está bloqueado. Habilítalo desde los ajustes de Android.';

  @override
  String get historyTitle => 'Historial';

  @override
  String get historyEmpty => 'Todavía no hay viajes grabados';

  @override
  String get historyEmptyHint =>
      'Empieza un viaje desde la pestaña Ahora y al terminar queda guardado aquí, con su recorrido.';

  @override
  String get historyTrips => 'Viajes';

  @override
  String get historyTotals => 'Totales';

  @override
  String get historyTotalDistance => 'Distancia total';

  @override
  String get historyTotalEnergy => 'Energía total';

  @override
  String get historyTotalTrips => 'Viajes';

  @override
  String get historyAverage => 'Consumo promedio';

  @override
  String get historyDelete => 'Borrar viaje';

  @override
  String get historyDeleted => 'Viaje borrado';

  @override
  String get historyUndo => 'Deshacer';

  @override
  String get historyDetail => 'Detalle del viaje';

  @override
  String historyPoints(int count) {
    return '$count puntos de recorrido';
  }

  @override
  String get historyNoPoints => 'Sin recorrido guardado';

  @override
  String get historyProfile => 'Perfil del viaje';

  @override
  String get historyLegendSpeed => 'Velocidad';

  @override
  String get historyLegendAltitude => 'Altitud';

  @override
  String get historyStorage => 'Almacenamiento';

  @override
  String get historyStorageSnapshots => 'Lecturas guardadas';

  @override
  String get historyStorageFrames => 'Frames crudos';

  @override
  String get historyStorageSize => 'Tamaño en disco';

  @override
  String get historyStorageNote =>
      'Los frames crudos se guardan 30 días y después se borran solos. Están para poder reinterpretar el histórico si aparece que un offset del protocolo estaba mal leído.';

  @override
  String get adviceTitle => 'Qué haría yo con esto';

  @override
  String get adviceNone => 'Nada que señalar. El pack se está portando bien.';

  @override
  String get adviceImbalanceAtRestTitle =>
      'Las celdas están desparejas en reposo';

  @override
  String adviceImbalanceAtRestBody(String delta, int cell) {
    return 'Con la moto quieta el delta llega a $delta V, y la más baja entonces era la celda $cell. Sin corriente de por medio eso no es resistencia: son celdas que guardan cantidades distintas de carga. Déjala cargar hasta arriba y en reposo unas horas para que el balanceador trabaje; si en varias cargas no se cierra, esa celda tiene menos capacidad que el resto.';
  }

  @override
  String get adviceImbalanceUnderLoadTitle =>
      'El delta se abre solo con corriente';

  @override
  String adviceImbalanceUnderLoadBody(String delta, int cell) {
    return 'En reposo las celdas están parejas, pero bajo carga se separan $delta V más, en varias lecturas. Eso es resistencia: puede ser una conexión o una celda con más resistencia que las demás. Revisa primero la conexión de la celda $cell, que era la más baja con esa carga: es lo más barato de descartar.';
  }

  @override
  String get adviceWeakCellTitle => 'Siempre es la misma celda';

  @override
  String adviceWeakCellBody(int cell, String percent) {
    return 'La celda $cell fue claramente la más baja en el $percent% de las lecturas que cuentan: con las celdas separadas al menos 10 mV, sin empate y sin contar dos veces una lectura repetida. Esa celda es la que define tu autonomía real y la que llega primero al corte.';
  }

  @override
  String get adviceSocCounterAheadTitle =>
      'El porcentaje de carga va por delante del pack';

  @override
  String adviceSocCounterAheadBody(String gap, String soc) {
    return 'El BMS dice $soc %, pero la celda más alta está $gap V por debajo de donde termina una carga. Ese porcentaje no se mide: el BMS suma amperios por tiempo contra la capacidad que tiene configurada, y ese contador deriva. Se vuelve a anclar solo si dejas que una carga llegue hasta el corte de una sentada. Si el desajuste vuelve después de eso, la capacidad configurada no es la que tiene el pack: mídela con un test de capacidad antes de cambiarla.';
  }

  @override
  String get adviceSocCounterBehindTitle => 'Queda más carga de la que dice';

  @override
  String adviceSocCounterBehindBody(String gap, String soc) {
    return 'El BMS dice $soc %, pero la celda más baja está $gap V por encima de donde el propio BMS llama vacío. Hay batería aquí que la pantalla no está contando. Ese porcentaje no se mide: es amperios por tiempo contra la capacidad configurada, y ese contador deriva. Si se repite, la capacidad configurada se queda corta frente a la real: mídela con un test de capacidad antes de cambiarla.';
  }

  @override
  String get adviceHealthDecorativeTitle => 'El SOH del BMS no se mueve';

  @override
  String get adviceHealthDecorativeBody =>
      'Sigue clavado en 100% con ciclos reales encima. Muchos firmwares nunca lo recalculan. Ignóralo y guíate por la capacidad medida.';

  @override
  String get adviceCapacityBelowTitle => 'Da menos de lo que decía la etiqueta';

  @override
  String adviceCapacityBelowBody(String percent) {
    return 'Los números del BMS implican un $percent% menos de lo que se anunció. Eso no significa que la batería esté fallando: lo más común es que nunca fuera esa capacidad. Un test de capacidad completo separa las dos cosas, y a partir de ahí la degradación se mide contra lo que esta batería dio de verdad.';
  }

  @override
  String get adviceNoCapacityTestTitle =>
      'Todavía no hay una medición real de capacidad';

  @override
  String get adviceNoCapacityTestBody =>
      'No tienes que hacer nada especial: la app revisa las lecturas guardadas y toma como medición cualquier descarga completa que ocurra. Hace falta que sea completa porque el resto es circular: el porcentaje que reporta el BMS lo calcula contando amperios y dividiendo entre la capacidad que tiene configurada, así que medir una descarga parcial contra ese porcentaje devuelve la capacidad configurada otra vez, no la real. Solo una carga al tope y una descarga hasta el corte tienen los dos extremos anclados al voltaje.';

  @override
  String get adviceRunningHotTitle => 'El pack está caliente';

  @override
  String adviceRunningHotBody(String temp) {
    return 'Llegó a $temp °C. Afloja un poco y fíjate que no tenga el aire tapado. El calor es lo que más rápido envejece una celda de litio.';
  }

  @override
  String get adviceBalancerNeverSeenTitle => 'El balanceador nunca arrancó';

  @override
  String adviceBalancerNeverSeenBody(String voltage) {
    return 'Las celdas están desparejas en reposo pero el balanceador no ha trabajado desde que se conectó el pack. O está apagado, o su voltaje de arranque ($voltage V) está por encima de donde llegan tus celdas. El voltaje de arranque se cambia con la app oficial del BMS. El interruptor del balanceador se puede encender desde Sistema, en Configuración del BMS, si activas el permiso de escritura en Ajustes; con el permiso apagado, la app no cambia nada en el BMS.';
  }

  @override
  String get adviceOvervoltageHighTitle =>
      'El límite de sobretensión está alto';

  @override
  String adviceOvervoltageHighBody(String voltage) {
    return 'Está en $voltage V por celda. Para NMC, cada décima por encima de 4.20 se paga en ciclos. Bajarlo un poco cuesta algo de autonomía y devuelve bastante vida.';
  }

  @override
  String get adviceRangeLearningTitle =>
      'La autonomía todavía es una estimación';

  @override
  String adviceRangeLearningBody(String km) {
    return 'Lleva $km km aprendidos. Graba algunos viajes completos y el número se ajusta a cómo conduces tú.';
  }

  @override
  String get adviceImbalanceCostingTitle =>
      'El desbalance te está costando autonomía';

  @override
  String adviceImbalanceCostingBody(String percent) {
    return 'Un $percent% de la energía que el pack todavía guarda queda atrapada arriba del corte, porque la celda más baja llega antes que las demás. Si el delta es de desequilibrio y no de capacidad, balancear lo recupera; si la celda tiene menos capacidad, no.';
  }

  @override
  String get statusAllClear => 'Todo en orden';

  @override
  String get statusExplain =>
      'Esta franja mira tres cosas: que el BMS no tenga alarmas, que las celdas no estén muy separadas entre sí, y que nada esté demasiado caliente. No mira cuánta carga queda: una batería vacía no está enferma.';

  @override
  String statusSpreadWatch(String delta) {
    return 'Celdas separadas $delta V';
  }

  @override
  String statusSpreadBad(String delta) {
    return 'Celdas muy separadas: $delta V';
  }

  @override
  String statusTempWatch(String temp) {
    return 'Temperatura alta: $temp °C';
  }

  @override
  String statusTempBad(String temp) {
    return 'Demasiado caliente: $temp °C';
  }

  @override
  String get tripStartFromHistory => 'Empezar un viaje';

  @override
  String get tripDeleteConfirmTitle => '¿Borrar este viaje?';

  @override
  String get tripDeleteConfirmBody =>
      'Se borra el viaje y su recorrido. El consumo que aprendió el estimador de autonomía se vuelve a calcular sin él.';

  @override
  String get tripDeleteConfirm => 'Borrar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get tripSwipeHint =>
      'Desliza un viaje hacia la izquierda para borrarlo.';

  @override
  String rangeRelearned(int count) {
    return 'Autonomía recalculada con $count viajes';
  }

  @override
  String get tripLearnedTitle => 'Lo que aprendió este viaje';

  @override
  String tripLearnedFirst(String after) {
    return 'Es el primer viaje con datos, así que el consumo aprendido pasa a ser el de este recorrido: $after Wh/km.';
  }

  @override
  String tripLearnedChanged(String before, String after) {
    return 'El consumo aprendido pasó de $before a $after Wh/km.';
  }

  @override
  String tripLearnedUnchanged(String after) {
    return 'Este viaje confirmó lo que ya sabía: $after Wh/km.';
  }

  @override
  String tripLearnedTooShort(String m) {
    return 'No se aprendió nada de este viaje: hacen falta al menos $m metros con la energía medida.';
  }

  @override
  String get tripLearnedRange => 'Autonomía al terminar';

  @override
  String get tripLearnedTotalKm => 'Aprendido de';

  @override
  String get tripLearnedConfidence => 'Confianza';

  @override
  String get tripDeepDischargeTip =>
      'Este viaje bajó mucho la carga, y eso es justamente lo que más ayuda: cuanto más rango de la batería recorre un viaje, menos margen de error queda en el cálculo.';

  @override
  String get tripShallowTip =>
      'Consejo: un viaje que gasta poca carga deja más margen de error. Si quieres afinar la autonomía, un recorrido largo enseña mucho más que varios cortos.';

  @override
  String tripHotTip(String temp) {
    return 'El pack llegó a $temp °C en este viaje. Vale la pena mirar la pestaña Térmico si se repite.';
  }

  @override
  String tripDeltaTip(String delta) {
    return 'El delta máximo del viaje fue $delta V. Si en reposo las celdas están parejas, eso apunta a una conexión, no a una celda mala.';
  }

  @override
  String tripThirstyTip(String percent) {
    return 'Este viaje gastó $percent% más que tu promedio. Viento, cuestas, carga o mano derecha: si se repite, el promedio se ajustará solo.';
  }

  @override
  String get tripStopped => 'Detenido';

  @override
  String get tripNotificationTitle => 'Viaje en curso';

  @override
  String get tripNotificationChannel => 'Grabación de viaje';

  @override
  String get tripNotificationChannelDesc =>
      'Mantiene el viaje grabando con la pantalla apagada o con otra app abierta.';

  @override
  String get tripNotificationDenied =>
      'Sin permiso de notificaciones el viaje se detiene al salir de la app. Se puede activar en los ajustes de Android.';

  @override
  String get proximityTitle => 'Conectar solo al acercarme';

  @override
  String get proximityBody =>
      'Cuando esté activado, la app busca tu BMS cada medio minuto y se conecta sola en cuanto aparece. Pensado para dejarlo un tiempo mientras calibras una batería nueva, no para siempre: mientras está conectado la app oficial de tu BMS no puede entrar, y buscar consume algo de batería del teléfono.';

  @override
  String get proximityLimit =>
      'Funciona con la app abierta o en segundo plano. Si Android mata el proceso, deja de buscar hasta que la vuelvas a abrir.';

  @override
  String get proximityRemembered => 'Buscando';

  @override
  String get proximityNoDevice =>
      'Conecta una vez a tu BMS y quedará recordado aquí.';

  @override
  String get proximityFound => 'BMS encontrado, conectando';

  @override
  String get proximityScanning => 'buscando';

  @override
  String get capacityTitle => 'Test de capacidad';

  @override
  String get capacityIntro =>
      'La única medición real de la app. Cuenta los amperios-hora que salen desde que la celda más alta está arriba, con el cargador ya soltando, hasta que la celda más baja llega al corte o el BMS corta. Los dos extremos los marcan las celdas, no el porcentaje del BMS: ese porcentaje se calcula contra la capacidad configurada, y medir con él solo devolvería esa configuración.';

  @override
  String get capacityStart => 'Empezar test';

  @override
  String get capacityAbort => 'Cancelar test';

  @override
  String get capacityRunning => 'midiendo';

  @override
  String get capacityNotFull =>
      'Carga el pack al tope primero. El test arranca cuando la celda más alta está arriba y el cargador ya suelta poca corriente, no cuando el BMS dice 100 %. Empezar a media carga solo mediría un pedazo.';

  @override
  String get capacityNoReadings => 'Conecta el BMS primero.';

  @override
  String get capacityDrawn => 'Sacado hasta ahora';

  @override
  String get capacityProgress => 'Avance';

  @override
  String get capacityStartedAt => 'Empezó';

  @override
  String get capacityResult => 'Capacidad medida';

  @override
  String get capacityVsCatalogue => 'Frente a catálogo';

  @override
  String get capacityCharged =>
      'El pack se cargó a mitad del test, así que el total no sirve. Conviene repetirlo desde lleno sin enchufar nada.';

  @override
  String get capacityCost =>
      'Ojo: llevar el pack hasta el corte gasta ciclos. Vale la pena de vez en cuando para medir, no como costumbre.';

  @override
  String get capacityNone => 'Todavía no has medido la capacidad';

  @override
  String get capacityHistory => 'Mediciones';

  @override
  String get capacityAutoNote =>
      'No hace falta que te acuerdes de nada: la app revisa las lecturas guardadas y toma como medición cualquier descarga completa que ya haya ocurrido, de celdas arriba a celda en el corte, sin cargas ni huecos largos en medio. El botón es para hacerla a propósito y ver el avance en vivo.';

  @override
  String get capacityAutoTag => 'detectada';

  @override
  String capacityGapWarning(String minutes) {
    return '$minutes min sin ver la batería, así que no cuenta como medición de capacidad.';
  }

  @override
  String get chargeReportTitle => 'Última carga';

  @override
  String get chargeReportIntro =>
      'Arriba de 4,0 V por celda la curva se vuelve empinada, así que una diferencia pequeña de carga entre celdas se ve como una diferencia grande de voltaje. Es la mejor ventana que da el pack, y la que nadie mira porque se carga de noche.';

  @override
  String get chargeAdded => 'Metido';

  @override
  String chargeFrom(String start, String end) {
    return 'De $start% a $end%';
  }

  @override
  String get chargeDeltaStart => 'Delta al empezar';

  @override
  String get chargeDeltaTop => 'Delta arriba';

  @override
  String get chargeWorstDelta => 'Peor delta arriba';

  @override
  String get chargeWeakCell => 'Celda que se queda atrás';

  @override
  String get chargeBalancerTime => 'Balanceador trabajando';

  @override
  String get chargeNeverReachedTop =>
      'Esta carga no llegó arriba de 4,0 V por celda, así que no dice nada del desbalance. Para que sirva hay que cargar hasta el tope.';

  @override
  String chargeOpensAtTop(int cell, int weak) {
    return 'Las celdas iban parejas y se abrieron al final. Ese patrón es capacidad desigual, no una conexión floja: la celda $cell se llena antes que las demás, y la $weak es la que va más atrás.';
  }

  @override
  String get chargeNone =>
      'Todavía no hay ninguna carga grabada de esta batería. Se graba cuando la app está conectada mientras carga.';

  @override
  String get trendsTitle => 'Con el tiempo';

  @override
  String get trendsConsumption => 'Consumo por viaje';

  @override
  String get trendsCapacity => 'Capacidad medida';

  @override
  String get trendsSag => 'Resistencia aparente del pack';

  @override
  String get trendsDeltaVsCharge => 'Delta contra carga';

  @override
  String trendsSpan(int days) {
    return '$days días de histórico';
  }

  @override
  String get trendsNotEnough =>
      'Hace falta más histórico para que esto signifique algo. Se va llenando sola.';

  @override
  String trendsPerMonth(String value) {
    return '$value por mes';
  }

  @override
  String get trendsLegendLoaded => 'Bajo carga';

  @override
  String get trendsLegendResting => 'En reposo';

  @override
  String get trendsDeltaHint =>
      'A lo ancho va el nivel de carga, no el tiempo. Cada punto es la mediana del delta (la celda más alta menos la más baja) de las lecturas de los últimos 90 días a ese porcentaje de carga: una línea en reposo y otra descargando a más de 5 A. Las lecturas cargando no entran. Que se abra cerca de vacía y de llena es normal en casi cualquier pack, porque ahí la curva de voltaje es empinada. Lo que dice algo es la línea de reposo abriéndose en el medio, donde la curva es plana, o la de carga muy por encima de la de reposo: eso es resistencia, y casi siempre una conexión y no una celda.';

  @override
  String get trendsSagHint =>
      'Un punto por viaje: la resistencia aparente del pack, sacada de cómo se movió el voltaje en los tramos en que la corriente subía y bajaba deprisa, la mediana de esos tramos. Incluye el cableado y el BMS, y es aproximada, porque la corriente y el voltaje de una lectura no siempre son del mismo instante. Lo que vale es la tendencia: subiendo despacio con los meses es desgaste; un salto de golpe casi siempre es una conexión. Los viajes con pocos tramos así no tienen punto.';

  @override
  String get alertTitle => 'Aviso';

  @override
  String get alertBmsFault => 'El BMS levantó una alarma';

  @override
  String get alertCellSpread => 'Las celdas se separaron mucho';

  @override
  String get alertTemperature => 'El pack está demasiado caliente';

  @override
  String get alertLowCharge => 'Queda poca carga';

  @override
  String get alertCriticalCharge => 'La carga está casi agotada';

  @override
  String get alertCellNearCutoff => 'Una celda está cerca del corte';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsCatalogue => 'Capacidad de catálogo';

  @override
  String get settingsCatalogueHint =>
      'Lo que dice la etiqueta del pack. Se usa para dos cosas: compararlo con lo que el pack mide de verdad en un test de capacidad, y calcular la autonomía con el pack lleno mientras no haya ninguna medida. El desgaste no se mide contra este número, sino contra la mejor descarga completa del propio pack.';

  @override
  String get catalogueUnset => 'Sin definir';

  @override
  String get catalogueUnsetHint =>
      'Nadie ha dicho todavía con cuántos amperios-hora se vendió esta batería, y la app no se lo inventa. Sin él no hay comparación con lo anunciado, y la autonomía con el pack lleno espera a un test de capacidad. El desgaste no lo necesita: sale de las descargas completas medidas.';

  @override
  String get catalogueSetIt => 'Definir capacidad';

  @override
  String catalogueUseBms(String ah) {
    return 'Usar $ah Ah del BMS';
  }

  @override
  String get catalogueNotComparable => 'sin comparar';

  @override
  String settingsCatalogueForPack(String pack) {
    return 'Lo que te vendieron como $pack. Cada batería tiene la suya, así que cambiarla aquí no toca las demás.';
  }

  @override
  String get exportNoPack => 'Conecta un pack para exportar su historial.';

  @override
  String get settingsBmsConfigured => 'Configurada en el BMS';

  @override
  String settingsCapacityMismatch(String bms, String sold) {
    return 'El BMS está configurado para $bms Ah y el pack se vendió como $sold Ah. Ese número del BMS no es una medición: es lo que escribió quien armó el pack, y es contra lo que el BMS calcula el porcentaje de carga. La diferencia ya es un dato, así que la app no lo copia encima de lo tuyo.';
  }

  @override
  String get settingsHaptics => 'Vibrar con los avisos';

  @override
  String get settingsHapticsHint =>
      'Rodando nadie mira la pantalla. Con la app a la vista vibra el propio teléfono; con la pantalla apagada o el teléfono en el bolsillo vibra la notificación del aviso, así que para eso tienen que estar activados los avisos en la barra de notificaciones.';

  @override
  String get settingsRawFrames => 'Guardar frames crudos';

  @override
  String get settingsRawFramesHint =>
      'Déjalo encendido. Guarda 30 días de frames crudos para diagnosticar y reinterpretar lecturas recientes si aparece que un offset del protocolo estaba mal leído. Los más viejos se borran solos.';

  @override
  String get settingsSave => 'Guardar';

  @override
  String get exportTitle => 'Exportar';

  @override
  String get exportIntro =>
      'Los datos que no puedes sacar no son del todo tuyos.';

  @override
  String get exportTrips => 'Viajes (CSV)';

  @override
  String get exportReadings => 'Lecturas (CSV)';

  @override
  String get exportFrames => 'Frames crudos (hex)';

  @override
  String get exportTrack => 'Recorrido (GPX)';

  @override
  String exportDone(String path) {
    return 'Listo para compartir: $path';
  }

  @override
  String get exportFailed => 'No se pudo exportar';

  @override
  String get warnWireResistance => 'Resistencia de cable alta';

  @override
  String get warnMosfetOvertemp => 'MOSFET sobrecalentado';

  @override
  String get warnCellCountMismatch =>
      'Número de celdas distinto al configurado';

  @override
  String get warnFullyCharged => 'Pack cargado al tope';

  @override
  String get warnPackOvervoltage => 'Sobrevoltaje del pack';

  @override
  String get warnChargeOvercurrent => 'Sobrecorriente de carga';

  @override
  String get warnChargeShortCircuit => 'Cortocircuito en carga';

  @override
  String get warnChargeOvertemp => 'Temperatura alta cargando';

  @override
  String get warnChargeUndertemp => 'Temperatura baja cargando';

  @override
  String get warnCoprocessor => 'Fallo de comunicación interna del BMS';

  @override
  String get warnCellUndervoltage => 'Celda por debajo del mínimo';

  @override
  String get warnPackUndervoltage => 'Voltaje del pack por debajo del mínimo';

  @override
  String get warnDischargeOvercurrent => 'Sobrecorriente de descarga';

  @override
  String get warnDischargeShortCircuit => 'Cortocircuito en descarga';

  @override
  String get warnDischargeOvertemp => 'Temperatura alta descargando';

  @override
  String get warnChargeMosfet => 'MOSFET de carga con fallo';

  @override
  String get warnDischargeMosfet => 'MOSFET de descarga con fallo';

  @override
  String get warnGpsDisconnected => 'GPS desconectado';

  @override
  String get warnChangePassword => 'Cambia la contraseña del BMS';

  @override
  String get warnDischargeOnFailed => 'No se pudo activar la descarga';

  @override
  String get warnPackOvertemp => 'Pack sobrecalentado';

  @override
  String get warnTempSensor => 'Sensor de temperatura con fallo';

  @override
  String get warnPlModule => 'Módulo PL con fallo';

  @override
  String get warnScpRelease => 'No se liberó la protección de cortocircuito';

  @override
  String get warnDischargeOcp2 => 'Sobrecorriente de descarga (nivel 2)';

  @override
  String get warnDischargeOcp3 => 'Sobrecorriente de descarga (nivel 3)';

  @override
  String get warnDischargeUndertemp => 'Temperatura baja descargando';

  @override
  String get warnGpsRemoteLock => 'Bloqueo remoto por GPS';

  @override
  String get updateTitle => 'Actualizaciones';

  @override
  String get updateIntro =>
      'La app no está en ninguna tienda, así que se actualiza desde las releases de GitHub. Comprueba una vez al día si hay versión nueva y te pregunta; nunca descarga nada sin que lo pidas.';

  @override
  String get updateInstalled => 'Versión instalada';

  @override
  String get updatePublished => 'Última publicada';

  @override
  String updateReleasedOn(String date) {
    return 'Publicada el $date';
  }

  @override
  String get updateCheck => 'Buscar actualización';

  @override
  String get updateChecking => 'Buscando...';

  @override
  String get updateUpToDate => 'Estás en la última versión.';

  @override
  String updateAvailable(String version, String size) {
    return 'Hay una versión $version disponible ($size MB).';
  }

  @override
  String get updateDownload => 'Descargar';

  @override
  String updateDownloading(String percent) {
    return 'Descargando... $percent%';
  }

  @override
  String get updateInstall => 'Instalar';

  @override
  String get updateReady =>
      'Descargada. Al instalar, Android te va a pedir confirmación.';

  @override
  String updateNoAsset(String version) {
    return 'Hay una versión $version, pero no trae una build para el procesador de este teléfono.';
  }

  @override
  String updateFailed(String error) {
    return 'No se pudo comprobar: $error';
  }

  @override
  String get updateNeedsToken =>
      'GitHub no entregó la release. Suele ser porque el repositorio está privado, y entonces hace falta un token de lectura. Si está público, vuelve a intentarlo en un momento.';

  @override
  String get updateTokenLabel => 'Token de GitHub';

  @override
  String get updateTokenHint =>
      'Solo hace falta si el repositorio es privado. Se guarda en este teléfono y solo se manda a api.github.com; no está dentro del APK, justo para que no viaje con él.';

  @override
  String get updateTokenSave => 'Guardar';

  @override
  String get updateTokenSaved => 'Token guardado';

  @override
  String get updateNeedsPermission =>
      'Android no deja instalar paquetes a esta app todavía. Ábrele el permiso y vuelve.';

  @override
  String get updateOpenPermission => 'Abrir ajustes';

  @override
  String get updateNotes => 'Novedades';

  @override
  String get packsTitle => 'Baterías';

  @override
  String get packsIntro =>
      'Todo lo que la app mide (capacidad, degradación, qué celda se queda atrás, cuánto cuesta un kilómetro) es de una batería concreta. Cada pack guarda su historial aparte, así que puedes usar el mismo teléfono con varias sin que se mezclen.';

  @override
  String get packsCurrent => 'Conectada ahora';

  @override
  String get packsNone => 'Ninguna conectada';

  @override
  String get packsKnown => 'Baterías conocidas';

  @override
  String packsLastSeen(String date) {
    return 'Vista el $date';
  }

  @override
  String get packsRename => 'Cambiar nombre';

  @override
  String get packsRenameHint => 'Nombre de la batería';

  @override
  String get packsSave => 'Guardar';

  @override
  String get packsCancel => 'Cancelar';

  @override
  String get packsDelete => 'Borrar batería';

  @override
  String packsDeleteConfirm(String pack) {
    return 'Se borra $pack y todo lo grabado con ella: viajes, recorridos, lecturas, frames crudos y mediciones de capacidad. No se puede deshacer.';
  }

  @override
  String packsRides(String count) {
    return '$count viajes';
  }

  @override
  String get orphansTitle => 'Historial sin batería asignada';

  @override
  String orphansBody(String count) {
    return 'Hay $count filas guardadas antes de que la app separara por batería, así que no consta de cuál son. Puedes asignarlas a la batería conectada o descartarlas. La app no lo adivina sola: una procedencia inventada al lado de mediciones reales es peor que un hueco.';
  }

  @override
  String get orphansAdopt => 'Asignar a esta batería';

  @override
  String get orphansDiscard => 'Descartar';

  @override
  String get orphansDone => 'Listo';

  @override
  String get storedTitle => 'Baterías guardadas';

  @override
  String get storedOpen => 'Ver historial';

  @override
  String get storedNone => 'Todavía no has conectado ninguna batería.';

  @override
  String storedLastSeen(String when) {
    return 'Última lectura $when';
  }

  @override
  String get storedNever => 'sin lecturas guardadas';

  @override
  String get offlineTitle => 'Resumen guardado';

  @override
  String get offlineBanner =>
      'Sin conexión. Todo esto sale de lo que ya estaba guardado, no del BMS ahora mismo.';

  @override
  String get offlineLastReading => 'Última lectura';

  @override
  String get offlineStateOfCharge => 'Carga entonces';

  @override
  String get offlineTrips => 'Viajes';

  @override
  String offlineSeeTrips(String count) {
    return 'Ver los $count viajes';
  }

  @override
  String get offlineNoTrips =>
      'Todavía no hay viajes guardados de esta batería.';

  @override
  String offlineTripsCount(String count) {
    return '$count guardados';
  }

  @override
  String get offlineTotalKm => 'Distancia total';

  @override
  String get offlineRange => 'Autonomía aprendida';

  @override
  String get offlineRangeUnknown => 'aún sin aprender';

  @override
  String get offlineNoData =>
      'No hay lecturas guardadas de esta batería todavía. Conéctate una vez y quedará aquí.';

  @override
  String get appSettingsTitle => 'Ajustes';

  @override
  String get settingsSectionApp => 'Aplicación';

  @override
  String get settingsSectionPack => 'Esta batería';

  @override
  String get agoPrefix => 'hace';

  @override
  String get agoSuffix => '';

  @override
  String get catalogueFromBmsTag => 'del BMS';

  @override
  String get catalogueConfirm => 'Confirmar que se vendió así';

  @override
  String get catalogueFromBmsHint =>
      'Tomado de la configuración del BMS, que es un número sobre este pack pero lo escribió quien lo armó. Mientras venga de ahí, la app no lo trata como lo anunciado: no compara con él lo que mide, y la autonomía con el pack lleno dice de dónde sale. Si te lo vendieron con otra capacidad, ponla.';

  @override
  String get connectRetry => 'Reintentar búsqueda';

  @override
  String get storedManageHint =>
      'Mantén pulsada una batería para renombrarla o borrarla.';

  @override
  String get offlineHealthTitle => 'Salud guardada';

  @override
  String get offlineMeasuredHealth => 'Desgaste medido';

  @override
  String get offlineImplied => 'Capacidad configurada en el BMS';

  @override
  String get offlineImpliedHint =>
      'Es un ajuste dentro del BMS, no una medición de las celdas. Es contra lo que se escala cada porcentaje que reporta la batería, así que vale la pena verlo, y se queda igual por muy cansada que esté la batería.';

  @override
  String offlineImpliedUnusable(String min, String max) {
    return 'Solo se puede leer entre un $min % y un $max % de carga.';
  }

  @override
  String get offlineSoh => 'Salud que reporta el BMS';

  @override
  String get offlineCycles => 'Ciclos que cuenta el BMS';

  @override
  String get offlineWeakest => 'Celda más baja en reposo';

  @override
  String offlineWeakestValue(String index, String volts) {
    return 'celda $index, $volts V';
  }

  @override
  String get offlineMaxTemp => 'Temperatura';

  @override
  String get offlineHistorySince => 'Historial desde';

  @override
  String offlineReadings(String count) {
    return '$count lecturas guardadas';
  }

  @override
  String get offlineBestMeasured => 'Mejor medición real';

  @override
  String get connectWaitingFirst =>
      'Conectando y esperando la primera lectura...';

  @override
  String get connectNotABms =>
      'Se conectó, pero no llegó ninguna lectura de BMS. Casi seguro que ese dispositivo no es un BMS JK. Si crees que sí lo es, mira la consola de frames crudos en Ajustes.';

  @override
  String get connectLinkNeverCameUp =>
      'No se pudo levantar la conexión Bluetooth con la batería en 25 segundos, y la app lo intentó más de una vez. Comprueba que la batería esté encendida y cerca, y que la app oficial de tu BMS esté cerrada del todo, no solo en segundo plano.';

  @override
  String get connectSilent =>
      'Conectó pero no llegaron lecturas. Si elegiste la marca, prueba con la otra.';

  @override
  String get connectTalkingUndecoded =>
      'Se conectó y están llegando bytes, pero ninguno se decodifica como un frame JK. Abre la consola con el icono de terminal de arriba: lo que aparezca ahí es lo que hace falta para añadir soporte.';

  @override
  String antEvidence(int status, int info, int rejected) {
    return 'ANT: $status de estado, $info de info, $rejected rechazadas';
  }

  @override
  String storedCount(String count) {
    return '$count guardadas';
  }

  @override
  String updateBannerTitle(String version) {
    return 'Hay una versión $version';
  }

  @override
  String get updateBannerAction => 'Ver';

  @override
  String get updateBannerDismiss => 'Ahora no';

  @override
  String get thermalProbeAbsent => 'sin conectar';

  @override
  String get thermalAbsentNote =>
      'Las sondas sin conectar reportan valores imposibles, del orden de -200 °C. No son frío: no hay nada cableado a esa entrada. Se muestran aparte para que no ensucien ni el máximo ni los avisos.';

  @override
  String get backupTitle => 'Copia de seguridad';

  @override
  String get backupIntro =>
      'Toda la base de datos en un archivo, y de vuelta. Las exportaciones a CSV y GPX son para leer los datos en otro sitio; esto es para no perderlos. Trae de vuelta las baterías, los viajes con su recorrido, las pruebas de capacidad, el mantenimiento, las inspecciones, el registro de la conexión y las lecturas tal como están guardadas en el teléfono: completas las del último mes y una por minuto las más viejas. Los frames crudos solo se guardan 30 días, así que la copia lleva como mucho esos. También lleva tus ajustes de alertas, carga, viajes y pantalla. No lleva la licencia ni el token de actualizaciones, que son de este teléfono.';

  @override
  String get backupExport => 'Guardar copia de todo';

  @override
  String get backupExportLight =>
      'Guardar copia más pequeña, sin frames crudos';

  @override
  String get backupImport => 'Restaurar desde un archivo';

  @override
  String get backupImportMerge => 'Añadir a lo que ya hay';

  @override
  String get backupImportReplace => 'Reemplazar todo';

  @override
  String get backupImportChoose => '¿Qué hacer con lo que ya está guardado?';

  @override
  String get backupReplaceWarning =>
      'Reemplazar borra todo lo que hay ahora en el teléfono antes de restaurar. No se puede deshacer.';

  @override
  String backupDone(String trips, String readings, String packs) {
    return 'Restaurado: $trips viajes, $readings lecturas, $packs baterías.';
  }

  @override
  String backupFailed(String reason) {
    return 'No se pudo restaurar: $reason';
  }

  @override
  String get backupWorking => 'Trabajando...';

  @override
  String get chargeAlertsTitle => 'Objetivo de carga';

  @override
  String get chargeAlertsIntro =>
      'Se carga de noche y nadie lo mira. Estos avisos existen para eso. Parar antes del tope no es superstición: la parte alta del rango es donde una celda de litio envejece más, así que si mañana no necesitas el pack entero, te conviene quedarte antes.';

  @override
  String get chargeTarget => 'Avisar al llegar a';

  @override
  String get chargeTargetOff => 'Desactivado';

  @override
  String chargeAlertTargetReached(String soc) {
    return 'La batería llegó al $soc %, según el BMS';
  }

  @override
  String get chargeAlertComplete => 'Carga terminada';

  @override
  String get chargeAlertHot => 'Se está calentando cargando';

  @override
  String get chargeAlertSpread => 'Las celdas se separan arriba';

  @override
  String get compareTitle => 'Comparar baterías';

  @override
  String get compareIntro =>
      'Las mismas cifras de siempre, pero juntas. En verde la mejor de cada fila, y solo cuando hay diferencia de verdad.';

  @override
  String get compareNeedsTwo =>
      'Hace falta haberse conectado a por lo menos dos baterías para poder compararlas.';

  @override
  String get compareHealth => 'Salud medida';

  @override
  String get compareHonestCycles => 'Ciclos reales';

  @override
  String get compareConsumption => 'Consumo';

  @override
  String get compareWorstDelta => 'Peor delta visto';

  @override
  String get compareOpen => 'Comparar baterías';

  @override
  String get driftTitle => 'Celda que se está yendo';

  @override
  String get driftNone => 'Ninguna celda se está separando del resto.';

  @override
  String get driftNotEnough =>
      'Todavía no hay historial suficiente. Hacen falta unas semanas de lecturas en reposo para distinguir una celda que empeora de una que siempre estuvo algo baja.';

  @override
  String driftFound(String cell, String now, String rate) {
    return 'La celda $cell se está separando: $now V por debajo de la media, y baja unos $rate V al mes.';
  }

  @override
  String get driftWhy =>
      'Una celda que siempre estuvo baja es un pack que se armó así. Una que hace seis semanas iba a la par y ahora va por debajo es una celda en camino de irse, y esa es la diferencia entre cambiar una celda y cambiar un pack.';

  @override
  String updateDialogBody(String current, String size) {
    return 'Tienes la $current. La nueva pesa $size MB. No se descarga nada hasta que lo pidas.';
  }

  @override
  String get widgetJustNow => 'ahora mismo';

  @override
  String widgetMinutes(String n) {
    return 'hace $n min';
  }

  @override
  String widgetHours(String n) {
    return 'hace $n h';
  }

  @override
  String widgetDays(String n) {
    return 'hace $n d';
  }

  @override
  String get maintTitle => 'Mantenimiento';

  @override
  String get maintIntro =>
      'Lo que le has hecho al pack, con fecha. El historial guarda lo que la batería hizo y se olvida de lo que le hiciste tú, que es la otra mitad. Una capacidad que da un salto o un delta que se desploma parecen ruido hasta que ves que esa semana cambiaste una celda.';

  @override
  String get maintNone => 'Todavía no has anotado nada.';

  @override
  String get maintAdd => 'Anotar algo';

  @override
  String get maintDate => 'Fecha';

  @override
  String get maintKind => 'Qué hiciste';

  @override
  String get maintNote => 'Detalle (opcional)';

  @override
  String get maintSave => 'Guardar';

  @override
  String get maintDelete => 'Borrar';

  @override
  String get maintKindCellReplaced => 'Cambié una celda';

  @override
  String get maintKindManualBalance => 'Balanceé a mano';

  @override
  String get maintKindConnections => 'Limpié o apreté conexiones';

  @override
  String get maintKindCharger => 'Cambié de cargador';

  @override
  String get maintKindBmsSettings => 'Cambié ajustes del BMS';

  @override
  String get maintKindOther => 'Otra cosa';

  @override
  String maintSince(String date) {
    return 'Historial desde el cambio de celda: $date';
  }

  @override
  String get trendsMaintMarks =>
      'Las líneas de puntos son cosas que anotaste en el mantenimiento.';

  @override
  String get chargeWatchTitle => 'Vigilar la carga';

  @override
  String get chargeWatchHint =>
      'Mientras la app está en segundo plano Android corta la conexión Bluetooth a los pocos minutos. Con esto activado, en cuanto detecta que estás cargando levanta un servicio en primer plano y mantiene la conexión, y si se corta sigue intentando reconectar hasta que la carga termina, que es lo que hace falta para que los avisos lleguen de noche. No funciona si cierras la app deslizándola. Cuesta batería del teléfono mientras dura.';

  @override
  String get chargeWatchNotifTitle => 'Cargando';

  @override
  String chargeWatchNotifText(String soc, String volts, String amps) {
    return '$soc % · $volts V · $amps A';
  }

  @override
  String get alertSilence => 'Silenciar este aviso';

  @override
  String get alertSilenced =>
      'Silenciado. Puedes volver a activarlo en Ajustes.';

  @override
  String get alertsSectionTitle => 'Qué avisos quieres';

  @override
  String get alertsSectionHint =>
      'Cada uno por separado. Apagar el que te molesta no debería costarte los que sí quieres.';

  @override
  String get autoTripTitle => 'Grabar viajes solo';

  @override
  String get autoTripHint =>
      'Abre el viaje cuando el pack consume y el GPS dice que te mueves, las dos cosas durante unos 20 segundos (si sales a paso de peatón, espera a que pases de 6 km/h), y lo cierra tras unos tres minutos quieto. Lo que recorras antes de que se abra no se graba. Si lo apagas, la app solo aprende tu autonomía de los viajes que empieces a mano, y los que se olvidan no son al azar: son los cortos y los que llevabas prisa.';

  @override
  String get autoTripStarted => 'Viaje iniciado solo';

  @override
  String get autoTripStopped => 'Viaje guardado';

  @override
  String get degNowTitle => 'Capacidad ahora';

  @override
  String get degBaseline => 'La mejor que ha dado';

  @override
  String degBaselineOn(String date) {
    return 'medida el $date';
  }

  @override
  String get degLost => 'Degradación';

  @override
  String get degLostUnknown => 'aún no medible';

  @override
  String get degLostWhy =>
      'La degradación se mide contra lo mejor que ha dado esta batería, no contra lo que decía el anuncio. Hace falta más de una medición: con una sola tienes una capacidad, no una pérdida.';

  @override
  String get degImpliedNote =>
      'Estimada del contador del BMS, no medida. Un test de capacidad da la cifra de verdad.';

  @override
  String get degSoldTitle => 'Frente a lo anunciado';

  @override
  String degSoldShort(String sold, String real, String pct) {
    return 'Se vendió como $sold Ah y lo mejor que ha medido son $real Ah: alrededor de un $pct % menos de lo anunciado. Si esa medición se hizo con el pack nuevo, no es desgaste: es que nunca fueron $sold.';
  }

  @override
  String get degSoldOk =>
      'Lo mejor que ha medido está a la altura de lo que se anunció.';

  @override
  String get demoSetCharge => 'Poner la carga a';

  @override
  String get demoFull => 'Llenar al 100 %';

  @override
  String get demoEmpty => 'Vaciar al 10 %';

  @override
  String get demoSpeed => 'Velocidad del simulador';

  @override
  String get demoSpeedHint =>
      'Acelera el tiempo del pack simulado. Un test de capacidad es una descarga entera: a velocidad normal son horas, y una función que tarda una tarde en llegar no se puede juzgar. La distancia y el GPS no se aceleran, así que el consumo aprendido sigue siendo realista.';

  @override
  String get demoSpeedNormal => 'normal';

  @override
  String get etaFull => 'Lleno en aprox.';

  @override
  String get etaTapering => 'ya va bajando la corriente, y el final tarda más';

  @override
  String get etaDone => 'Está lleno';

  @override
  String get etaCannotSay => 'No puedo decirlo';

  @override
  String get etaCounterAhead =>
      'el contador va por delante de las celdas, así que no doy minutos';

  @override
  String get socNoteAhead => 'el contador va por delante de las celdas';

  @override
  String get socNoteBehind => 'queda más de lo que dice';

  @override
  String adviceDeepestSoFar(String from, String to) {
    return 'Lo más hondo hasta ahora: del $from % al $to %.';
  }

  @override
  String get adviceDeepestNone =>
      'Todavía no se ha registrado ninguna descarga.';

  @override
  String get linkLostTitle => 'Se perdió la conexión';

  @override
  String get linkLostBody =>
      'Estás fuera del alcance de la batería, o algo más tiene tomado el canal Bluetooth. Sigue reintentando solo; lo que ves en pantalla es la última lectura.';

  @override
  String get linkReconnectingTitle => 'Reconectando';

  @override
  String get linkConnectingTitle => 'Conectando';

  @override
  String get linkGaveUpTitle => 'No pude reconectar';

  @override
  String linkGaveUpBody(String attempts) {
    return 'Me detuve tras $attempts intentos. Cada intento fallido consume recursos Bluetooth de todo el teléfono, así que no sigue solo.';
  }

  @override
  String get linkRetryNow => 'Reintentar';

  @override
  String linkReadingAge(String age) {
    return 'Última lectura hace $age';
  }

  @override
  String get linkStaleTitle => 'Conectado, pero sin lecturas';

  @override
  String get linkStaleBody =>
      'El enlace está arriba y la batería no manda nada que la app pueda leer. Lo que ves es la última lectura, no la actual. Si sigue así unos segundos más, la app suelta la conexión y vuelve a entrar.';

  @override
  String get linkBack => 'Leyendo otra vez';

  @override
  String get linkDetails => 'Detalles';

  @override
  String get troubleBusy =>
      'Algo más ya está conectado a la batería. El BMS acepta una sola conexión Bluetooth a la vez, así que cierra la app oficial de tu BMS o cualquier otro registrador.';

  @override
  String get troubleOutOfRange =>
      'La batería no respondió. O está fuera de alcance o apagada, o algo más tiene tomada su única conexión Bluetooth: la app oficial de tu BMS, u otro registrador.';

  @override
  String get troubleBluetoothOff => 'El Bluetooth del teléfono está apagado.';

  @override
  String get troublePermission =>
      'La app no tiene permiso para usar Bluetooth. Concede Dispositivos cercanos en los ajustes de Android.';

  @override
  String get troubleLocationOff =>
      'La ubicación del teléfono está apagada. Android la necesita encendida para buscar dispositivos Bluetooth.';

  @override
  String get troubleGeneric =>
      'Problema de Bluetooth. Sigue reintentando solo.';

  @override
  String get troubleSlowFrames =>
      'El teléfono concedió un tamaño de paquete Bluetooth menor del pedido. Las lecturas llegan en más trozos, lo que es más lento pero igual de correcto.';

  @override
  String get troubleNotJkBms =>
      'Ese dispositivo no tiene el servicio Bluetooth que usan los BMS compatibles. No es un BMS compatible, o no uno con el que esta app pueda hablar.';

  @override
  String get troublePackMute =>
      'La batería estuvo conectada pero muda: en 20 segundos no mandó nada que la app pudiera leer, pese a pedírselo varias veces. La app soltó la conexión a propósito y vuelve a entrar en unos segundos; es la única forma de que el módulo Bluetooth del BMS suelte la sesión que se le quedó colgada. En Detalles dice cuántos bytes llegaron.';

  @override
  String get screenAwakeTitle => 'Mantener la pantalla encendida';

  @override
  String get screenAwakeHint =>
      'Antes se quedaba encendida todo el tiempo que esta pantalla estuviera abierta, lo cual está bien en un soporte de moto y mal en el sofá.';

  @override
  String get screenAwakeNever => 'Nunca';

  @override
  String get screenAwakeRiding => 'Mientras ruedas';

  @override
  String get screenAwakeAlways => 'Siempre';

  @override
  String get linkWatchNotifTitle => 'Leyendo la batería';

  @override
  String get linkWatchNotifWaiting => 'Esperando la primera lectura';

  @override
  String linkWatchNotifText(String soc, String volts, String amps) {
    return '$soc %  ·  $volts V  ·  $amps A';
  }

  @override
  String get linkWatchTitle => 'Seguir leyendo con la pantalla apagada';

  @override
  String get linkWatchHint =>
      'Android deja de entregarle lecturas Bluetooth a una app poco después de que la pantalla se apaga, a menos que la app mantenga un servicio en primer plano. Esto lo mantiene mientras la batería está conectada, y también mientras intenta recuperar la conexión si se corta, para que la app funcione igual con la pantalla encendida o apagada. Para eso es la notificación; no es la app anunciándose. Si cierras la app deslizándola, deja de leer.';

  @override
  String get screenAwakeReason =>
      'Con el ajuste de arriba encendido, la pantalla puede apagarse sin que las lecturas se detengan.';

  @override
  String backupScope(String packs, String trips, String readings) {
    return 'Todas las baterías, no solo la conectada: $packs baterías, $trips viajes, $readings lecturas.';
  }

  @override
  String get backupScopeEmpty =>
      'Todavía no hay nada guardado, así que no hay nada que copiar.';

  @override
  String get downloadNotifTitle => 'Descargando actualización';

  @override
  String downloadNotifText(String percent) {
    return '$percent %';
  }

  @override
  String get learnWhyTitle => 'Por qué no ha aprendido nada';

  @override
  String learnWhyCount(String used, String considered) {
    return '$used de $considered viajes grabados eran utilizables.';
  }

  @override
  String learnWhyShort(String n) {
    return '$n fueron de menos de 200 m, demasiado corto para dividir: un temblor del GPS en esa distancia produce un consumo de cientos de Wh/km.';
  }

  @override
  String learnWhyNoEnergy(String n) {
    return '$n se midieron, pero no salió energía neta de la batería. O fueron en remolque o casi todo cuesta abajo, o la batería reporta su corriente con el signo contrario al que esta app asume.';
  }

  @override
  String get learnWhySignWarning =>
      'Si es el signo, también estaría desactivando la energía de los viajes, el consumo y la detección de capacidad, mientras cada lectura en vivo sigue pareciendo correcta. Vale la pena comprobarlo: rodando, la corriente en la pantalla principal debería ser negativa.';

  @override
  String get learnWhyNeedMore =>
      'Aprende del primer viaje de más de 200 m que consuma energía. No hay nada más que hacer.';

  @override
  String get trendsIntro =>
      'Cuatro gráficas, y de cada una lo que sirve es la pendiente, no la altura. Un número que se queda quieto es una batería sana; uno que se va para un lado durante meses es la batería diciéndote algo.';

  @override
  String get trendsConsumptionHint =>
      'Un punto por viaje medido que cuenta para la autonomía: lo que costó por kilómetro. Lo mueven sobre todo la ruta, cómo manejas, el viento, la temperatura y las llantas, no la batería, así que no es una medida de desgaste: sirve para ver cómo vas gastando. Los viajes sin medir, los marcados como excepción y los de un consumo imposible no entran.';

  @override
  String get trendsCapacityHint =>
      'Un punto por descarga completa medida, la más vieja a la izquierda: de celdas arriba a celda en el corte, vigilada entera y sin carga en medio. La altura es los amperios-hora que salieron esa vez. Es la única medida real de desgaste que hay aquí, y la más lenta en llenarse: espera que baje un poco cada año, y desconfía de una caída de golpe.';

  @override
  String get trendsAxisTime =>
      'a lo ancho, el tiempo: del más viejo al más nuevo, con los huecos donde no hubo datos';

  @override
  String get trendsAxisCharge => 'de izquierda a derecha: de vacía a llena';

  @override
  String learnWhyImplausible(String n) {
    return '$n dieron un consumo que ninguna moto puede producir, así que se rechazaron. Eso fue un fallo de esta app y no algo del manejo, y está arreglado: los viajes grabados desde entonces deberían salir bien. Los viejos que conservan sus lecturas se pueden medir de nuevo con «Volver a medir» en su detalle.';
  }

  @override
  String get connectCouldNotSearch =>
      'La radio nunca confirmó que la búsqueda empezara, así que en realidad no se buscó nada. Normalmente es el Bluetooth despertando justo al abrir la app. Prueba otra vez.';

  @override
  String get backupShare =>
      'Enviar la copia pequeña, sin frames crudos, a otra app';

  @override
  String get backupSaveDialog => 'Dónde guardar la copia';

  @override
  String backupSaved(String name) {
    return 'Guardada como $name.';
  }

  @override
  String get rangeFull => 'Con la batería llena';

  @override
  String rangeFullBand(String low, String high) {
    return 'unos $low a $high km';
  }

  @override
  String get rangeFullUnknown =>
      'Hace falta una capacidad medida para poder decir esto.';

  @override
  String get rangeFullFromAdvert =>
      'Sale de la capacidad que pusiste tú, no de una medida.';

  @override
  String get rangeFullFromMeasured =>
      'Sale de una descarga completa medida en esta batería, de celdas arriba a celda en el corte.';

  @override
  String get rangeNoneLearned =>
      'Todavía no ha aprendido nada, así que no hay distancia que valga la pena decir, a ninguna carga.';

  @override
  String get offlineRangeAtLastSeen => 'Con la carga de la última lectura';

  @override
  String get offlineHealthNeedsTests =>
      'Hacen falta dos descargas completas para poder medir desgaste. Una da una capacidad; hacen falta dos para ver una caída.';

  @override
  String offlineHealthOneTest(String ah) {
    return 'Una medición hasta ahora: $ah Ah. La segunda, dentro de unos meses, es la que la convierte en desgaste.';
  }

  @override
  String get systemDrops => 'Caídas del enlace';

  @override
  String get systemTimeDisconnected => 'Tiempo desconectado';

  @override
  String get systemNudges => 'Veces que hubo que insistirle';

  @override
  String get systemNudgesHint =>
      'La app solo le escribe a la batería cuando lleva seis segundos sin hablar. Antes escribía cada cinco segundos sin importar nada, y eso es lo que parece interrumpir el flujo. Si esto se queda cerca de cero en un viaje con lecturas continuas, esa era la causa.';

  @override
  String get settingsSectionRides => 'Viajes';

  @override
  String get settingsSectionLink => 'Conexión y pantalla';

  @override
  String get settingsSectionLinkHint =>
      'Lo que mantiene a la app leyendo. Estos dos van juntos: si se mantiene la conexión abierta, la pantalla puede dormirse.';

  @override
  String offlineRangeStale(String age) {
    return 'Esa lectura tiene $age, así que esto es un recuerdo y no una cifra: la batería puede haberse usado o haber estado ahí parada desde entonces.';
  }

  @override
  String get licenseTitle => 'Licencia';

  @override
  String get licenseStatusFree => 'Gratis';

  @override
  String get licenseStatusTrial => 'Prueba Pro';

  @override
  String get licenseStatusPro => 'Pro';

  @override
  String get licenseStatusWorkshop => 'Pro Taller';

  @override
  String get licenseStatusWorkshopExpired => 'Taller vencido';

  @override
  String licenseTrialLeft(String days) {
    return 'Quedan $days días de prueba con todo lo Pro. Después la app sigue funcionando: el visor en vivo completo, gratis y para siempre.';
  }

  @override
  String get licenseFreeBody =>
      'Visor completo en vivo y las últimas 24 horas de historial, gratis. Lo demás (historial ilimitado, degradación, veredictos, vigilar la carga toda la noche, copia de seguridad) es Pro: un pago único, de por vida, para este teléfono.';

  @override
  String get licenseProBody =>
      'Pro activo en este teléfono. Pago único, sin caducidad.';

  @override
  String licenseWorkshopBody(String date) {
    return 'Pro Taller activo hasta el $date.';
  }

  @override
  String get licenseWorkshopNoEnd => 'Pro Taller activo.';

  @override
  String get licenseWorkshopExpiredBody =>
      'La licencia de Taller venció. La app volvió al nivel gratis; renueva para recuperar lo Pro.';

  @override
  String licenseCreditsLeft(String count) {
    return 'Chequeos disponibles: $count';
  }

  @override
  String licenseCertificatesLeft(String count) {
    return 'Certificados disponibles: $count';
  }

  @override
  String licenseLabel(String label) {
    return 'A nombre de $label';
  }

  @override
  String get licenseDeviceCode => 'Código de este teléfono';

  @override
  String get licenseDeviceCodeHint =>
      'La clave va atada a este código. Mándalo junto con el comprobante de pago y recibirás una clave para pegar aquí. Se comprueba en el teléfono, sin internet.';

  @override
  String get licenseCopyCode => 'Copiar código';

  @override
  String get licenseCopied => 'Copiado';

  @override
  String get licenseCopyRequest => 'Copiar mensaje de solicitud';

  @override
  String licenseRequestMessage(String code, String version) {
    return 'Hola, quiero activar JK BMS + Pro.\nCódigo del teléfono: $code\nVersión de la app: $version';
  }

  @override
  String get licensePasteTitle => 'Pegar clave';

  @override
  String get licensePasteHint =>
      'Pega la clave completa, desde JKB1 hasta el final. Los saltos de línea del chat no importan.';

  @override
  String get licenseActivate => 'Activar';

  @override
  String get licenseActivated => 'Clave activada.';

  @override
  String get licenseAlreadyActive =>
      'Esa clave ya estaba activada en este teléfono.';

  @override
  String get licenseRejectedMalformed =>
      'Eso no es una clave. Revisa que la copiaste completa, de JKB1 hasta el final.';

  @override
  String get licenseRejectedSignature =>
      'La clave no es válida: o le falta un carácter, o no fue emitida por el autor.';

  @override
  String get licenseRejectedDevice =>
      'Esta clave es de otro teléfono. Cada clave va atada al código del teléfono que la pidió.';

  @override
  String get licenseRejectedExpired => 'Esta clave ya venció.';

  @override
  String get licenseNotConfigured =>
      'Esta compilación no lleva clave pública de licencias y no puede activar ninguna. Es una compilación de desarrollo; ver docs/LICENSING.md.';

  @override
  String get licenseActiveKeys => 'Claves en este teléfono';

  @override
  String licenseKeyActivated(String date) {
    return 'Activada el $date';
  }

  @override
  String licenseKeyExpires(String date) {
    return 'Vence el $date';
  }

  @override
  String licenseKeyExpired(String date) {
    return 'Venció el $date';
  }

  @override
  String licenseKeyCredits(String inspections, String certificates) {
    return '$inspections chequeos, $certificates certificados';
  }

  @override
  String get licenseRemoveKey => 'Quitar';

  @override
  String get licenseRemoveConfirmTitle => '¿Quitar esta clave?';

  @override
  String get licenseRemoveConfirmBody =>
      'La app pierde lo que esta clave desbloquea. La clave sigue siendo válida: si la guardaste, puedes pegarla otra vez.';

  @override
  String get licenseWhyTitle => 'Por qué se cobra';

  @override
  String get licenseWhyBody =>
      'Lo gratis iguala a la app oficial de tu BMS y no se recorta nunca. Lo Pro es lo que esa app no puede hacer por diseño: recordar, comparar y concluir. Un pago único; nada de suscripciones. Sin cuenta, sin servidor y sin internet: la clave se comprueba en el teléfono con la firma del autor.';

  @override
  String get licenseOpen => 'Ver licencia';

  @override
  String get proBadge => 'PRO';

  @override
  String get proGateTitle => 'Función Pro';

  @override
  String proGateBody(String feature) {
    return '$feature es parte de Pro. Un pago único, de por vida, para este teléfono.';
  }

  @override
  String get proGateTrialEnded => 'La prueba de 7 días terminó.';

  @override
  String get proFeatureHistory => 'El historial de más de 24 horas';

  @override
  String get proFeatureDegradation =>
      'La degradación y las curvas a largo plazo';

  @override
  String get proFeatureVerdicts => 'Los veredictos sobre el estado del pack';

  @override
  String get proFeatureBackgroundAlerts =>
      'Vigilar la carga toda la noche, sin dejar de reconectar si la conexión se corta';

  @override
  String get proFeatureBackup => 'La copia de seguridad y su restauración';

  @override
  String get proFeatureConfigAudit =>
      'La auditoría de la configuración del BMS';

  @override
  String get proFeatureBatteryReport => 'El informe PDF de la batería';

  @override
  String get proFeatureInspection => 'La inspección rápida de otra batería';

  @override
  String get proFeatureCertificate => 'El certificado de vendedor';

  @override
  String get proFeatureWorkshop => 'Las funciones de taller';

  @override
  String historyOlderLocked(String count) {
    return '$count viajes de más de 24 horas no se muestran. Verlos es Pro.';
  }

  @override
  String get chargeWatchProHint =>
      'Es Pro: requiere licencia para vigilar la carga toda la noche, reconectando si se corta. Seguir leyendo con la pantalla apagada es gratis.';

  @override
  String get licenseStatusAdmin => 'Admin';

  @override
  String get licenseAdminBody =>
      'Acceso total en este teléfono: todo desbloqueado, sin límites ni caducidad.';

  @override
  String get adviceWhy => 'POR QUÉ';

  @override
  String get adviceWhyHide => 'OCULTAR';

  @override
  String get adviceHonestyNote =>
      'Cada frase se apoya en un dato: tócala para verlo. Los ciclos y la capacidad configurada del BMS se pueden editar desde su app oficial, así que aquí se contrastan con lo que la app mide por su cuenta siempre que puede.';

  @override
  String get verdictHealthMeasuredTitle =>
      'Capacidad frente a la mejor que ha dado';

  @override
  String verdictHealthMeasuredBody(String pct, String now, String best) {
    return 'Tu batería está al $pct % de la mejor medición que ha hecho: $now Ah en la última frente a $best Ah, la mejor. Medido en descargas completas, no estimado.';
  }

  @override
  String get verdictHealthNotMeasurableTitle =>
      'El desgaste todavía no se puede medir';

  @override
  String verdictHealthNotMeasurableBody(String count) {
    return 'Hay $count descarga(s) completa(s) medidas. Hacen falta dos para hablar de pérdida: una da una capacidad, no una caída. La app toma la siguiente sola cuando ocurra.';
  }

  @override
  String verdictCellDriftingTitle(String cell) {
    return 'La celda $cell se está separando del resto';
  }

  @override
  String verdictCellDriftingBody(String days, String dev, String rate) {
    return 'En $days días con lecturas en reposo se ha ido separando: va $dev V por debajo de la media del pack y la tendencia es de unos $rate V más al mes. Coherente con una celda en camino de irse. Revísala antes de que el pack se apague en la calle.';
  }

  @override
  String get verdictNoCellDriftingTitle => 'Ninguna celda se está yendo';

  @override
  String verdictNoCellDriftingBody(String days, String cell, String dev) {
    return 'En $days días con lecturas en reposo, todas entre el 40 y el 80 % de carga, ninguna celda se separa del resto. La más baja, la $cell, va $dev V bajo la media y no empeora. Nada que hacer.';
  }

  @override
  String verdictRangeNowTitle(String km) {
    return 'Te quedan ~$km km con cómo tú manejas';
  }

  @override
  String verdictRangeNowBody(String wh, String learned) {
    return 'Sale de $wh Wh/km aprendidos en $learned km tuyos, aplicados a la energía que el pack puede entregar ahora. Es una estimación: cambia con el terreno, la carga y el acelerador.';
  }

  @override
  String get verdictDeltaNormalTitle => 'Delta bajo carga normal';

  @override
  String verdictDeltaNormalBody(String loaded, String rest) {
    return 'Con carga fuerte el delta llega a $loaded V, contra $rest V en reposo. No hay nada resistivo que perseguir. Nada que hacer.';
  }

  @override
  String get evidenceRestingDelta =>
      'Delta en reposo (el más alto desde que se conectó)';

  @override
  String get evidenceLoadedDelta =>
      'Delta bajo carga (el que alcanzaron varias lecturas desde que se conectó)';

  @override
  String evidenceWeakCellShare(String cell) {
    return 'Lecturas en que la celda $cell fue la más baja';
  }

  @override
  String get evidenceReadingsInSession =>
      'Lecturas que cuentan desde que se conectó';

  @override
  String get evidenceReportedCycles => 'Ciclos según el BMS (dato editable)';

  @override
  String get evidenceEquivalentCycles =>
      'Ciclos equivalentes (Ah que contó el BMS entre la capacidad configurada)';

  @override
  String get evidenceReportedSoh => 'SOH según el BMS';

  @override
  String get evidenceReportedSoc => 'Carga según el BMS';

  @override
  String get evidenceSocFullAnchor => 'Donde termina la carga (por celda)';

  @override
  String get evidenceSocEmptyAnchor => 'Donde el BMS llama vacío (por celda)';

  @override
  String evidenceLowestCell(String cell) {
    return 'Celda más baja (celda $cell)';
  }

  @override
  String evidenceHighestCell(String cell) {
    return 'Celda más alta (celda $cell)';
  }

  @override
  String get evidenceImpliedCapacity =>
      'Capacidad configurada en el BMS (editable)';

  @override
  String get evidenceCatalogueCapacity => 'Capacidad anunciada';

  @override
  String get evidenceCapacityTests => 'Descargas completas medidas';

  @override
  String get evidenceHottestProbe => 'Sonda más caliente';

  @override
  String get evidenceBalanceStart => 'Voltaje de arranque del balanceador';

  @override
  String get evidenceCellOvp => 'Límite de sobretensión por celda';

  @override
  String get evidenceLearnedKm => 'Kilómetros aprendidos';

  @override
  String get evidenceWhPerKm => 'Consumo aprendido';

  @override
  String get evidenceUsableWh => 'Energía aprovechable ahora';

  @override
  String get evidenceStrandedFraction => 'Energía atrapada sobre el corte';

  @override
  String get evidenceRangeBand => 'Banda de la estimación';

  @override
  String evidenceBaselineCapacity(String date) {
    return 'Lo mejor que ha dado ($date)';
  }

  @override
  String evidenceCurrentCapacity(String date) {
    return 'Última medición ($date)';
  }

  @override
  String evidenceDriftDeviation(String cell) {
    return 'Celda $cell bajo la media del pack';
  }

  @override
  String get evidenceDriftRate => 'Ritmo de separación';

  @override
  String get evidencePerMonth => 'mes';

  @override
  String get evidenceDriftSamples => 'Lecturas en reposo analizadas';

  @override
  String get evidenceDriftDays => 'Días con lecturas en reposo';

  @override
  String get verdictTitle => 'Veredicto';

  @override
  String get demoScenarioInspection => 'Ensayo de inspección';

  @override
  String get demoScenarioInspectionDesc =>
      '35 s quieta, luces 20 s, tirón fuerte 8 s y suelta. La celda 7 es la débil.';

  @override
  String get inspectionEntry => 'Inspeccionar otra batería';

  @override
  String get inspectionModeTitle => 'Modo inspección';

  @override
  String get inspectionModeBanner =>
      'La batería que conectes ahora no se guarda en tu historial ni enseña nada a tu autonomía. Pide al vendedor que cierre su app JK y elige su BMS en la lista.';

  @override
  String get inspectionModeExit => 'Salir del modo inspección';

  @override
  String get inspectionRehearse => 'Ensayar con el pack demo';

  @override
  String get inspectionTitle => 'Inspección rápida';

  @override
  String get inspectionWaitingReadings => 'Esperando lecturas del BMS…';

  @override
  String get inspectionStepRestTitle => 'No toques nada';

  @override
  String get inspectionStepRestBody =>
      'La app toma la foto en reposo. Que nadie acelere ni encienda nada.';

  @override
  String get inspectionStepLightTitle => 'Enciende las luces';

  @override
  String get inspectionStepLightBody =>
      'Una carga pequeña y estable. La app avanza sola cuando la detecta.';

  @override
  String get inspectionStepHeavyTitle => 'Ahora una carga fuerte';

  @override
  String get inspectionStepHeavyBody =>
      'Tres formas, cualquiera sirve: rodar 50 metros acelerando de verdad, o apretar el freno trasero en el caballete y abrir gas, o enchufar el cargador medio minuto. La rueda girando libre al aire NO sirve: el motor no tiene contra qué empujar y la corriente se queda casi en cero por mucho que gires el puño.';

  @override
  String get inspectionStepRecoveryTitle => 'Suelta todo y espera';

  @override
  String get inspectionStepRecoveryBody =>
      'Sin corriente. La app mira cuánto tarda cada celda en volver a su voltaje de reposo.';

  @override
  String get inspectionStepDoneTitle => 'Listo';

  @override
  String get inspectionCurrentNow => 'Corriente ahora';

  @override
  String inspectionLoadEnough(String amps) {
    return 'Carga detectada: $amps A, suficiente.';
  }

  @override
  String inspectionLoadTooLow(String amps, String need) {
    return 'Veo $amps A y hacen falta $need A sostenidos.';
  }

  @override
  String inspectionNotQuiet(String amps) {
    return 'Hay corriente ($amps A). Hace falta reposo.';
  }

  @override
  String get inspectionQuietOk => 'En reposo.';

  @override
  String inspectionSecondsLeft(String seconds) {
    return '$seconds s';
  }

  @override
  String inspectionStepSkipHint(String seconds) {
    return 'Si esta carga no se puede generar, la app pasa al siguiente paso sola en $seconds s y lo dice en el veredicto.';
  }

  @override
  String get inspectionSkipStep => 'Saltar este paso';

  @override
  String get inspectionAbort => 'Terminar ahora';

  @override
  String get inspectionQuickTestLabel => 'TEST RÁPIDO · ESTIMACIÓN';

  @override
  String get inspectionLightGood => 'Nada grave a la vista';

  @override
  String get inspectionLightWatch => 'Hay algo que mirar';

  @override
  String get inspectionLightProblem => 'No compres a ciegas: hay un problema';

  @override
  String get inspectionLightUnmeasured =>
      'Sin veredicto: nunca se cargó el pack';

  @override
  String get inspectionUnmeasuredBody =>
      'Este test saca su respuesta de la caída por celda bajo carga, y nunca llegó una carga suficiente, así que aquí no hay nada sobre esta batería ni a favor ni en contra. Repítelo y dale una de estas: rodar cincuenta metros acelerando de verdad, o apretar el freno trasero en el caballete y abrir gas, o enchufar el cargador medio minuto. La rueda girando al aire no es carga: el motor no tiene contra qué empujar, así que la corriente se queda casi en cero por mucho que gires el puño.';

  @override
  String inspectionFidelityNote(String floor) {
    return 'Un test rápido detecta la celda que se aparta de las demás bajo carga (a la carga de esta prueba, desde unos $floor mΩ de resistencia de más) y la estafa obvia; no mide capacidad real. Para capacidad real hace falta una descarga completa.';
  }

  @override
  String get inspectionCaveatsTitle => 'Lo que este test no pudo ver';

  @override
  String get inspectionCaveatNoHeavyLoad =>
      'Sin carga fuerte: la caída por celda no se pudo medir.';

  @override
  String get inspectionCaveatHeavyWasCharge =>
      'La carga fue un cargador, así que las celdas subieron en vez de bajar. La cuenta es la misma; la dirección no.';

  @override
  String get inspectionCaveatNoLightLoad =>
      'Sin carga ligera: el paso de las luces no ocurrió.';

  @override
  String get inspectionCaveatRestNoisy =>
      'El pack nunca estuvo quieto del todo: la foto en reposo es aproximada.';

  @override
  String get inspectionCaveatNoRecovery =>
      'La carga no se soltó: la recuperación no se midió.';

  @override
  String get inspectionCaveatStepTooSmall =>
      'El salto de corriente fue pequeño: la resistencia estimada es ruido.';

  @override
  String get inspectionCaveatFewReadings =>
      'Pocas lecturas: el BMS habló poco.';

  @override
  String get inspectionCellsTitle => 'Celda por celda';

  @override
  String get inspectionCellHeaderRest => 'Reposo';

  @override
  String get inspectionCellHeaderSag => 'Caída';

  @override
  String get inspectionCellHeaderIr => 'R est.';

  @override
  String get inspectionCellHeaderRec => 'Recup.';

  @override
  String get inspectionReportedTitle => 'Lo que dice el BMS (editable)';

  @override
  String get inspectionReportedHint =>
      'Ciclos, capacidad configurada y SOH se cambian desde la app oficial en un minuto. Se muestran; no se creen.';

  @override
  String get inspectionReportedCycles => 'Ciclos';

  @override
  String get inspectionReportedCapacity => 'Capacidad configurada';

  @override
  String get inspectionReportedSoc => 'Carga';

  @override
  String get inspectionReportedSoh => 'SOH';

  @override
  String get inspectionReportedModel => 'Modelo';

  @override
  String inspectionSummaryLine(
    String cells,
    String amps,
    String seconds,
    String readings,
  ) {
    return '$cells celdas · pico $amps A · $seconds s · $readings lecturas';
  }

  @override
  String get inspectionSave => 'Guardar inspección';

  @override
  String get inspectionSaved => 'Inspección guardada.';

  @override
  String get inspectionDiscard => 'Descartar';

  @override
  String get inspectionNoteHint =>
      'Nota: vendedor, precio pedido, lo que dijo…';

  @override
  String get inspectionsTitle => 'Inspecciones';

  @override
  String get inspectionsIntro =>
      'Baterías ajenas que has mirado con el test rápido. No forman parte de tu historial.';

  @override
  String get inspectionsEmpty =>
      'Todavía no has inspeccionado ninguna batería.';

  @override
  String get inspectionsOpen => 'Ver inspecciones';

  @override
  String get inspectionDeleted => 'Inspección borrada.';

  @override
  String get inspectionDeleteConfirmTitle => '¿Borrar esta inspección?';

  @override
  String get inspectionDeleteConfirmBody =>
      'Se pierden el veredicto y las lecturas capturadas.';

  @override
  String inspectionCreditsLeft(String count) {
    return 'Esta inspección consume un chequeo. Te quedan $count.';
  }

  @override
  String get inspectionCreditsGone =>
      'No te quedan chequeos. Consigue más en Licencia.';

  @override
  String verdictInspCellSaggingTitle(String cell) {
    return 'La celda $cell cae mucho más que las demás';
  }

  @override
  String verdictInspCellSaggingBody(String excess, String ohms) {
    return 'Bajo la carga fuerte cayó $excess V más que la mediana del pack: unos $ohms mΩ de resistencia de más. Coherente con una celda gastada o con una conexión mala en esa celda. Es la razón principal para no pagar el precio pedido sin más pruebas.';
  }

  @override
  String get verdictInspSagUniformTitle => 'Todas las celdas caen parejo';

  @override
  String verdictInspSagUniformBody(String amps, String excess, String floor) {
    return 'Con la carga fuerte ($amps A) la peor celda cayó solo $excess V más que la mediana. A esta corriente ya se distinguiría una celda con unos $floor mΩ de resistencia de más, y ninguna se rinde antes que las demás.';
  }

  @override
  String get verdictInspRestDeltaWideTitle =>
      'Las celdas están desparejas en reposo';

  @override
  String verdictInspRestDeltaWideBody(String delta, String cell) {
    return 'Con la moto quieta el delta es de $delta V y la más baja es la celda $cell. Sin corriente eso no es resistencia: son celdas que guardan cantidades distintas de carga, o un balanceador que no trabaja.';
  }

  @override
  String get verdictInspRestDeltaOkTitle => 'Celdas parejas en reposo';

  @override
  String verdictInspRestDeltaOkBody(String delta) {
    return 'Delta de $delta V con la moto quieta. Bien.';
  }

  @override
  String verdictInspWeakLightTitle(String cell) {
    return 'La celda $cell cae con casi nada';
  }

  @override
  String verdictInspWeakLightBody(String amps, String extra) {
    return 'Con solo las luces ($amps A) cayó $extra V más que las demás. Una celda que se rinde con la carga de las luces (menos de un amperio) es una celda muy cansada.';
  }

  @override
  String verdictInspSlowRecoveryTitle(String cell) {
    return 'La celda $cell rebota lento';
  }

  @override
  String verdictInspSlowRecoveryBody(String extra) {
    return 'Tardó $extra s más que la mediana en volver a su voltaje de reposo tras soltar la carga, o no volvió. Las celdas cansadas rebotan lento.';
  }

  @override
  String get verdictInspRecoveryOkTitle => 'Recuperación pareja';

  @override
  String verdictInspRecoveryOkBody(String seconds) {
    return 'Tras soltar la carga las celdas volvieron a su reposo en unos $seconds s, todas al mismo paso. Después de un tirón así de fuerte, la recuperación es un indicador poco mirado y muy bueno.';
  }

  @override
  String get verdictInspHotTitle => 'El pack estaba caliente';

  @override
  String verdictInspHotBody(String temp) {
    return 'Llegó a $temp °C durante el test. Para una prueba de unos minutos es mucho: pregunta de dónde viene ese calor.';
  }

  @override
  String get verdictInspAlarmsTitle => 'El BMS tuvo alarmas durante el test';

  @override
  String verdictInspAlarmsBody(String count) {
    return '$count alarma(s) activas en algún momento. Pregunta por qué: un BMS que protesta en dos minutos protesta en la calle.';
  }

  @override
  String get verdictInspCountersTitle =>
      'Ciclos y capacidad según el BMS: no confiar';

  @override
  String verdictInspCountersBody(String cycles) {
    return 'El BMS reporta $cycles ciclos. Ese dato y la capacidad configurada se editan desde la app oficial en un minuto. El veredicto se apoya en la física de arriba, no en estos contadores.';
  }

  @override
  String get verdictInspNoHeavyLoadTitle =>
      'Sin carga fuerte: fidelidad reducida';

  @override
  String verdictInspNoHeavyLoadBody(String amps) {
    return 'La corriente máxima vista fue $amps A. Sin un tirón fuerte sostenido unos segundos no se puede medir cuánto cae cada celda, que es donde sale la verdad. Repite rodando con carga real (una cuesta o acelerar fuerte), o con el cargador.';
  }

  @override
  String evidenceCellSag(String cell) {
    return 'Caída de la celda $cell bajo carga';
  }

  @override
  String get evidenceMedianSag => 'Caída mediana del pack';

  @override
  String get evidenceCurrentStep => 'Salto de corriente (carga menos reposo)';

  @override
  String evidenceCellResistance(String cell) {
    return 'Resistencia estimada de la celda $cell';
  }

  @override
  String get evidenceMedianResistance => 'Resistencia estimada mediana';

  @override
  String evidenceLowestRestCell(String cell) {
    return 'Celda más baja en reposo (celda $cell)';
  }

  @override
  String get evidenceLightLoadAmps => 'Corriente con las luces';

  @override
  String evidenceRecoverySeconds(String cell) {
    return 'Recuperación de la celda $cell';
  }

  @override
  String get evidenceMedianRecoverySeconds => 'Recuperación mediana';

  @override
  String get evidenceAlarmCount => 'Alarmas vistas';

  @override
  String get evidencePeakCurrent => 'Corriente máxima vista';

  @override
  String get reportPackTitle => 'Informe de batería';

  @override
  String get reportInspectionTitle => 'Informe de inspección';

  @override
  String get reportCertificateTitle => 'Certificado de inspección';

  @override
  String reportGeneratedAt(String date) {
    return 'Generado el $date';
  }

  @override
  String reportAppVersion(String version) {
    return 'Versión $version';
  }

  @override
  String reportPageOf(String page, String total) {
    return 'Página $page de $total';
  }

  @override
  String get reportUnknownPack => 'Batería sin nombre';

  @override
  String get reportSectionNow => 'Cómo está ahora';

  @override
  String get reportLastReading => 'Última lectura';

  @override
  String get reportPackVoltage => 'Tensión del pack';

  @override
  String get reportCellCount => 'Celdas';

  @override
  String get reportDelta => 'Diferencia entre celdas';

  @override
  String get reportCellRange => 'Celda más baja y más alta';

  @override
  String get reportMaxTemperature => 'Temperatura máxima';

  @override
  String get reportSectionCapacity => 'Capacidad';

  @override
  String get reportConfiguredCapacity => 'Configurada en el BMS';

  @override
  String get reportAdvertisedCapacity => 'Anunciada al comprarla';

  @override
  String get reportCapacityTests => 'Tests de capacidad completados';

  @override
  String get reportCapacityNote =>
      'Solo la mejor medición real proviene de una descarga completa contada por la app. La capacidad configurada es un ajuste del BMS, no una medida, y se puede cambiar en un minuto.';

  @override
  String get reportSectionRange => 'Autonomía';

  @override
  String get reportConsumption => 'Consumo aprendido';

  @override
  String get reportRangeBasis => 'Calculada a partir de';

  @override
  String get reportRangeFromMeasured => 'capacidad medida';

  @override
  String get reportRangeFromCatalogue => 'capacidad anunciada';

  @override
  String get reportSectionCells => 'Celdas';

  @override
  String get reportCell => 'Celda';

  @override
  String get reportDeviation => 'Bajo la media';

  @override
  String get reportTrend => 'Tendencia';

  @override
  String get reportSpan => 'Medido sobre';

  @override
  String reportDays(String count) {
    return '$count días';
  }

  @override
  String get reportCellsNote =>
      'Una celda que siempre estuvo baja es un pack fabricado así. Una que se separa mes a mes es una celda que se va.';

  @override
  String get reportSectionHistory => 'Historial';

  @override
  String get reportReadings => 'Lecturas guardadas';

  @override
  String get reportSectionMaintenance => 'Mantenimiento registrado';

  @override
  String get reportDate => 'Fecha';

  @override
  String get reportEvent => 'Evento';

  @override
  String get reportNote => 'Nota';

  @override
  String get reportHonestyPack =>
      'Las cifras vienen de lo que informa el BMS y de lo que esta app ha contado durante el uso. La autonomía es una estimación aprendida de viajes reales, no una promesa. La capacidad medida requiere una descarga completa registrada por la app; sin ella, no hay medida, hay lo que dice el BMS.';

  @override
  String get reportSectionTest => 'El test';

  @override
  String get reportTestedAt => 'Realizado el';

  @override
  String get reportPeakCurrent => 'Corriente máxima alcanzada';

  @override
  String get reportRestDelta => 'Diferencia en reposo';

  @override
  String get reportMedianSag => 'Caída mediana bajo carga';

  @override
  String get reportMedianResistance => 'Resistencia mediana';

  @override
  String get reportMedianRecovery => 'Recuperación mediana';

  @override
  String get reportDuration => 'Duración';

  @override
  String reportReadingsInline(String count) {
    return '($count lecturas)';
  }

  @override
  String get reportRestVolts => 'Reposo (V)';

  @override
  String get reportSag => 'Caída (V)';

  @override
  String get reportResistance => 'Resistencia (mOhm)';

  @override
  String get reportRecovery => 'Recuperación (s)';

  @override
  String get reportNotRecovered => 'no volvió';

  @override
  String get reportCellTableNote =>
      'La caída es cuánto bajó cada celda bajo la carga fuerte. La resistencia se estima del salto de corriente, no se mide con instrumento.';

  @override
  String get reportSectionReported => 'Lo que dice el BMS de sí mismo';

  @override
  String get reportModel => 'Modelo';

  @override
  String get reportSerial => 'Número de serie';

  @override
  String get reportSoftware => 'Versión del firmware';

  @override
  String get reportCycles => 'Ciclos según el BMS';

  @override
  String get reportReportedSoh => 'Salud declarada';

  @override
  String get reportReportedNote =>
      'Estos valores son editables desde la app oficial del BMS en menos de un minuto. Se imprimen aparte a propósito: son una declaración, no una medida.';

  @override
  String get reportSectionCaveats => 'Lo que este test no pudo ver';

  @override
  String get reportSectionNote => 'Nota del inspector';

  @override
  String get reportSectionCertificate => 'Certificado';

  @override
  String get reportCertificateCode => 'Código del certificado';

  @override
  String get reportCertificateIssuer => 'Código de emisor';

  @override
  String get reportCertificateIssuedAt => 'Firmado el';

  @override
  String get reportCertificateExplain =>
      'La firma demuestra que estas cifras salieron de la app en el teléfono cuyo código de emisor aparece aquí, y que no se han cambiado desde entonces. No demuestra de quién es ese teléfono: compara el código con el que publica quien te dio el certificado. Tampoco demuestra qué batería se probó (el nombre y el número de serie los da el BMS y se pueden cambiar), ni la fecha, que es la del reloj de ese teléfono, ni que la batería esté bien. Escanea el QR o pega el código en la app para comprobarlo.';

  @override
  String reportHonestyInspection(String date) {
    return 'Test rápido del $date. Un test así detecta la celda que se aparta de las demás bajo carga, a la carga de esta prueba, y la estafa obvia; no sustituye a una revisión en taller. No mide capacidad: la capacidad que aparece es la configurada en el BMS, no una medida.';
  }

  @override
  String get reportPackButton => 'Informe PDF';

  @override
  String get reportInspectionPdfButton => 'Informe PDF';

  @override
  String get reportCertificateButton => 'Certificado firmado';

  @override
  String get reportBuilding => 'Preparando el PDF...';

  @override
  String get reportFailed => 'No se pudo crear el PDF.';

  @override
  String get reportShareText => 'Informe generado con JK BMS +';

  @override
  String get certificateVerifyTitle => 'Verificar certificado';

  @override
  String get certificateVerifyIntro =>
      'Pega aquí el código que acompaña a un certificado, o el texto del QR. La app comprueba la firma y te muestra las cifras que se firmaron, todas, con el veredicto que la app saca de ellas.';

  @override
  String get certificateVerifyHint => 'JKC1....';

  @override
  String get certificateVerifyButton => 'Comprobar';

  @override
  String get certificateVerifyOpen => 'Verificar un certificado';

  @override
  String certificateValid(String issuer) {
    return 'Firma válida para el emisor $issuer. Comprueba que ese código es el de quien te dio el certificado.';
  }

  @override
  String get certificateBadSignature =>
      'La firma no cuadra: el contenido se modificó después de firmarlo.';

  @override
  String get certificateMalformed => 'Eso no es un certificado válido.';

  @override
  String certificateCreditsLeft(String count) {
    return 'Firmar un certificado consume un crédito. Te quedan $count.';
  }

  @override
  String get certificateCreditsGone =>
      'No te quedan créditos de certificado. Consigue más en Licencia.';

  @override
  String verdictInspRepeatSameCellTitle(
    String cell,
    String times,
    String runs,
  ) {
    return 'La celda $cell vuelve a fallar: $times de $runs pruebas';
  }

  @override
  String get verdictInspRepeatSameCellBody =>
      'Repetida la prueba con una carga parecida, la misma celda vuelve a hundirse antes que las demás, y las dos veces por encima del umbral. Ya no parece una lectura rara: es esa celda o su conexión, y un taller puede decir cuál.';

  @override
  String verdictInspRepeatCellMovedTitle(String cell) {
    return 'Esta vez se hundió otra celda';
  }

  @override
  String verdictInspRepeatCellMovedBody(String before, String cell) {
    return 'La prueba anterior señaló la celda $before y esta señala la $cell. Cuando el dedo cambia de sitio entre pruebas, casi siempre es que no se tiró igual de la batería, no que haya dos celdas malas. Repite el test pidiendo el mismo acelerón que la vez anterior.';
  }

  @override
  String get verdictInspRepeatWorseTitle =>
      'Mide peor que en la prueba anterior';

  @override
  String get verdictInspRepeatWorseBody =>
      'Respecto a la prueba anterior el pack mide peor; las cifras de las dos están en el detalle. Las caídas solo se comparan cuando las dos cargas fueron parecidas, y el reposo solo cuando el pack estaba a una carga parecida. Dos pruebas apuntan a un cambio; una tercera lo confirmaría.';

  @override
  String get verdictInspRepeatSteadyTitle =>
      'Repite lo mismo que la vez anterior';

  @override
  String get verdictInspRepeatSteadyBody =>
      'Las cifras de esta prueba caen dentro del ruido de la anterior. La primera prueba no fue una casualidad y esta no ha encontrado nada nuevo.';

  @override
  String get verdictInspRepeatCountersResetTitle =>
      'Los contadores del BMS bajaron entre visitas';

  @override
  String get verdictInspRepeatCountersResetBody =>
      'Los ciclos y la energía total que cuenta el BMS solo suben. Si entre las dos pruebas bajaron, el BMS se reseteó o se cambió. Pregunta por qué. Lo físico de arriba no se resetea con un botón; eso es lo que hay que mirar.';

  @override
  String get verdictInspRepeatLoadDiffersTitle =>
      'Las dos pruebas no tiraron igual';

  @override
  String get verdictInspRepeatLoadDiffersBody =>
      'La caída de voltaje depende de cuánta corriente se pida. Con acelerones muy distintos, comparar las caídas no dice nada. Para comparar de verdad, repite el test pidiendo un tirón parecido.';

  @override
  String get evidenceRunCount => 'Pruebas a este pack';

  @override
  String evidenceTimesSameCell(String cell) {
    return 'Veces que salió la celda $cell';
  }

  @override
  String evidencePreviousSag(String date) {
    return 'Caída el $date';
  }

  @override
  String evidencePreviousRestDelta(String date) {
    return 'Delta en reposo el $date';
  }

  @override
  String evidencePreviousResistance(String date) {
    return 'Resistencia mediana el $date';
  }

  @override
  String evidencePreviousCycles(String date) {
    return 'Ciclos según el BMS el $date';
  }

  @override
  String evidencePreviousSoh(String date) {
    return 'SOH según el BMS el $date';
  }

  @override
  String evidencePreviousConfiguredCapacity(String date) {
    return 'Capacidad configurada el $date';
  }

  @override
  String evidencePreviousPeakCurrent(String date) {
    return 'Salto de corriente el $date';
  }

  @override
  String get inspectionSeriesTitle => 'Comparado con las pruebas anteriores';

  @override
  String get inspectionSeriesIntro =>
      'Este pack ya se había inspeccionado. Repetir el test es lo que separa una lectura rara de un fallo real.';

  @override
  String inspectionSeriesRun(String number, String total) {
    return 'Prueba $number de $total a este pack';
  }

  @override
  String inspectionSeriesPrevious(String date) {
    return 'Prueba del $date';
  }

  @override
  String get inspectionSeriesFirstRun =>
      'Primera inspección de este pack. Repítela otro día para confirmar lo que has visto.';

  @override
  String get inspectionRepeatButton => 'Repetir la prueba';

  @override
  String get inspectionRepeatHint =>
      'Guárdala antes de repetir para poder compararlas: solo se comparan las pruebas guardadas.';

  @override
  String inspectionAlreadySeen(String count) {
    return 'Ya inspeccionada $count vez/veces';
  }

  @override
  String get reportSectionSeries => 'Pruebas anteriores a este pack';

  @override
  String get reportSeriesNote =>
      'Cada fila es una inspección guardada en el teléfono que firmó esta hoja, incluida esta, que es la última. Repetir el test es lo que distingue una celda mala de una lectura mala.';

  @override
  String get reportSeriesWorstCell => 'Peor celda';

  @override
  String get profileTitle => 'Perfil de la batería';

  @override
  String get profileIntro =>
      'Cuatro cosas que el BMS no puede saber y que cambian lo que la app puede decirte. Todas se pueden dejar en blanco.';

  @override
  String get profileName => 'Nombre';

  @override
  String get profileSoldAs => 'Vendida como';

  @override
  String get profileSoldAsHint => 'Capacidad que te dijeron';

  @override
  String get profileChemistry => 'Química de las celdas';

  @override
  String get profileChemistryWhy =>
      'De esto dependen los rangos seguros. LFP a 4,2 V por celda es un incendio; NMC a 3,6 V es una batería a medio cargar. Si no lo sabes, déjalo en \"No lo sé\" y la app no auditará voltajes.';

  @override
  String profileChemistryFromOvp(String chemistry, String value) {
    return 'El BMS está configurado a $value V por celda, lo que sugiere $chemistry.';
  }

  @override
  String profileChemistryFromCell(String chemistry, String value) {
    return 'Se ha visto una celda a $value V, así que no es LFP: sugiere $chemistry.';
  }

  @override
  String get profileAcquired => 'La tengo desde';

  @override
  String get profileAcquiredUnknown => 'Sin fecha';

  @override
  String get profileAcquiredClear => 'Quitar la fecha';

  @override
  String profileAgeYears(String years) {
    return '$years años contigo';
  }

  @override
  String get profileCaptureBaseline => 'Guardar el estado de hoy como día uno';

  @override
  String get profileCaptureBaselineHint =>
      'Celdas, resistencias y configuración del BMS tal como están ahora. Todo lo que la app diga después sobre derivas se compara contra esto. Mejor con la batería en reposo.';

  @override
  String get profileSave => 'Guardar';

  @override
  String get profileLater => 'Ahora no';

  @override
  String get profileEdit => 'Editar el perfil';

  @override
  String get profileComplete => 'Completar el perfil';

  @override
  String get profileBaseline => 'Día uno';

  @override
  String get profileBaselineMissing => 'Sin guardar';

  @override
  String get profileNoBaselineIntro =>
      'Sin un día uno, \"el delta se ha abierto\" solo significa \"desde que la app empezó a mirar\". Guardar el estado de hoy le da a todo lo demás un punto de partida.';

  @override
  String profileSinceDayOne(String date) {
    return 'Desde el día uno ($date)';
  }

  @override
  String get profileNotComparable =>
      'Una de las dos lecturas se tomó con la batería tirando corriente, así que las celdas no son comparables. Mira esto con la moto parada.';

  @override
  String get profileDeltaThenNow => 'Diferencia entre celdas';

  @override
  String get profileWorstDrift => 'La que más se ha ido';

  @override
  String profileWorstDriftValue(String cell, String mv) {
    return 'Celda $cell, $mv mV';
  }

  @override
  String get profileCyclesSince => 'Ciclos desde entonces';

  @override
  String get profileConfigChanged => 'Configuración del BMS';

  @override
  String get profileConfigUnchanged => 'Igual que el día uno';

  @override
  String profileConfigChangedCount(String count) {
    return '$count ajuste(s) cambiado(s)';
  }

  @override
  String get chemistryLfp => 'LFP';

  @override
  String get chemistryNmc => 'NMC / Li-ion';

  @override
  String get chemistryUnknown => 'No lo sé';

  @override
  String get configCellOvp => 'Corte por celda alta';

  @override
  String get configCellUvp => 'Corte por celda baja';

  @override
  String get configBalanceStart => 'Empieza a balancear';

  @override
  String get configSoc100 => 'Voltaje del 100 %';

  @override
  String get configSoc0 => 'Voltaje del 0 %';

  @override
  String get configMaxCharge => 'Corriente máxima de carga';

  @override
  String get configMaxDischarge => 'Corriente máxima de descarga';

  @override
  String get configMaxBalance => 'Corriente de balanceo';

  @override
  String get configChargeOtp => 'Corte por calor cargando';

  @override
  String get configDischargeOtp => 'Corte por calor descargando';

  @override
  String get configChargeUtp => 'Corte por frío cargando';

  @override
  String get configMosfetOtp => 'Corte por calor del MOSFET';

  @override
  String get configNominalCapacity => 'Capacidad configurada';

  @override
  String get configCellCount => 'Número de celdas';

  @override
  String get configChargeSwitch => 'Carga habilitada';

  @override
  String get configDischargeSwitch => 'Descarga habilitada';

  @override
  String get configBalancerSwitch => 'Balanceador';

  @override
  String get configOn => 'Sí';

  @override
  String get configOff => 'No';

  @override
  String get reportSectionDayOne => 'El día uno de esta batería';

  @override
  String get reportDayOneNote =>
      'Comparación contra el estado guardado el día que se dio de alta la batería. No es una medida de capacidad: una foto de los voltajes no puede medir lo que aguanta un pack, y aquí no se presenta como tal.';

  @override
  String get verdictConfigOvpDangerousTitle =>
      'El corte de carga está por encima de lo que aguantan las celdas';

  @override
  String verdictConfigOvpDangerousBody(String value, String limit) {
    return 'El BMS corta la carga a $value V por celda y el máximo seguro para esta química es $limit V. Cada carga completa está haciendo daño. Se cambia desde la app oficial del BMS, bajo tu responsabilidad; esta app no escribe valores de configuración en la batería.';
  }

  @override
  String get verdictConfigOvpHighTitle => 'El corte de carga está alto';

  @override
  String verdictConfigOvpHighBody(String value, String limit) {
    return 'Cortas a $value V por celda cuando con $limit V la batería ya está prácticamente llena. Lo que ganas en autonomía es casi nada y lo que pierdes en vida útil no lo es.';
  }

  @override
  String get verdictConfigUvpDangerousTitle =>
      'El corte de descarga deja las celdas por debajo de lo recuperable';

  @override
  String verdictConfigUvpDangerousBody(String value, String limit) {
    return 'El BMS deja bajar hasta $value V por celda y el mínimo seguro es $limit V. Una celda que baja de ahí puede no volver, y las que vuelven lo hacen con menos capacidad.';
  }

  @override
  String get verdictConfigUvpLowTitle => 'El corte de descarga está bajo';

  @override
  String verdictConfigUvpLowBody(String value, String limit) {
    return 'Cortas a $value V por celda. Por debajo de $limit V se aprieta a las celdas para sacar unos pocos kilómetros que salen caros en vida útil.';
  }

  @override
  String get verdictConfigChargesWhenFrozenTitle =>
      'El BMS cargará la batería por debajo de cero';

  @override
  String verdictConfigChargesWhenFrozenBody(String value) {
    return 'El corte por frío está en $value °C. Cargar litio bajo cero deposita metal dentro de la celda: es permanente, no aparece en ningún número que el BMS reporte y es la forma más común de arruinar un pack en invierno. Súbelo a 2 °C o más desde la app oficial.';
  }

  @override
  String get verdictConfigColdCutoffOkTitle =>
      'No cargará con la batería helada';

  @override
  String verdictConfigColdCutoffOkBody(String value) {
    return 'El corte por frío está en $value °C, así que el BMS se niega a cargar antes de que empiece el daño. Es de los ajustes que más vida salvan y este está bien puesto.';
  }

  @override
  String get verdictConfigChargeHotLimitTitle =>
      'El corte por calor cargando está alto';

  @override
  String verdictConfigChargeHotLimitBody(String value, String limit) {
    return 'Deja cargar hasta $value °C, y por encima de $limit °C cargar ya envejece las celdas más rápido de lo normal.';
  }

  @override
  String get verdictConfigDischargeHotLimitTitle =>
      'El corte por calor descargando está alto';

  @override
  String verdictConfigDischargeHotLimitBody(String value, String limit) {
    return 'Deja tirar hasta $value °C. Por encima de $limit °C ni siquiera descargar es gratis.';
  }

  @override
  String get verdictConfigCapacityDisagreesTitle =>
      'La capacidad configurada no es la que te vendieron';

  @override
  String verdictConfigCapacityDisagreesBody(String value, String sold) {
    return 'El BMS está configurado a $value Ah y tú anotaste que se vendió como $sold Ah. El número del BMS lo escribió quien montó el pack: no mide nada, pero de él salen el porcentaje de carga y los amperios-hora restantes de todas las pantallas.';
  }

  @override
  String get verdictConfigCellCountDisagreesTitle =>
      'El BMS está configurado para otro número de celdas';

  @override
  String verdictConfigCellCountDisagreesBody(String value, String seen) {
    return 'Configurado para $value celdas y se están leyendo $seen. Con esto mal, el voltaje del pack, el porcentaje y los cortes de protección se calculan sobre una batería que no es esta.';
  }

  @override
  String get verdictConfigChargeCurrentHighTitle =>
      'La corriente de carga es alta para el tamaño del pack';

  @override
  String verdictConfigChargeCurrentHighBody(String value, String capacity) {
    return 'Hasta $value A en una batería configurada como de $capacity Ah. Se puede, pero cargar por encima de 1C calienta y envejece; si no tienes prisa, bajarlo alarga la vida.';
  }

  @override
  String get verdictConfigBalancerOffTitle => 'El balanceador está apagado';

  @override
  String get verdictConfigBalancerOffBody =>
      'Sin balanceo, las celdas se van separando solas y la más débil marca el final de cada carga y de cada descarga. Es la causa número uno de packs que pierden autonomía sin que ninguna celda esté realmente mal.';

  @override
  String get verdictConfigChargeOffTitle =>
      'La carga está deshabilitada en el BMS';

  @override
  String get verdictConfigChargeOffBody =>
      'Si la batería no coge carga, esto lo explica. Puede ser a propósito, o puede que se quedara así después de una protección.';

  @override
  String get verdictConfigDischargeOffTitle =>
      'La descarga está deshabilitada en el BMS';

  @override
  String get verdictConfigDischargeOffBody =>
      'Si la moto no arranca, esto lo explica. Puede ser a propósito, o puede que se quedara así después de una protección.';

  @override
  String get verdictConfigBalanceStartLowTitle =>
      'El balanceo empieza donde el voltaje no dice nada';

  @override
  String verdictConfigBalanceStartLowBody(String value, String limit) {
    return 'Empieza a $value V por celda, y para esta química lo normal es cerca de $limit V. En la parte plana de la curva un milivoltio no significa carga, así que el balanceador puede mover energía en la dirección equivocada.';
  }

  @override
  String get verdictConfigChangedSinceDayOneTitle =>
      'La configuración no es la del día uno';

  @override
  String verdictConfigChangedSinceDayOneBody(String count) {
    return '$count ajuste(s) han cambiado desde que se guardó el estado inicial. Si no fuiste tú, alguien ha tocado el BMS.';
  }

  @override
  String get verdictConfigChemistryUnknownTitle =>
      'Sin química declarada no se auditan voltajes';

  @override
  String get verdictConfigChemistryUnknownBody =>
      'LFP y NMC se llevan casi un voltio por celda: con la química equivocada esta pantalla bendeciría un ajuste peligroso o condenaría uno normal. Dilo en el perfil de la batería y vuelve.';

  @override
  String get verdictConfigLooksSaneTitle => 'La configuración es razonable';

  @override
  String get verdictConfigLooksSaneBody =>
      'Los cortes de voltaje, los de temperatura y los interruptores están donde deberían para esta química. Esto no dice nada sobre el estado de las celdas: es una revisión de los ajustes, no de la batería.';

  @override
  String get evidenceConfiguredSetting => 'Configurado';

  @override
  String get evidenceSafeLimit => 'Límite seguro';

  @override
  String get evidenceCellsSeen => 'Celdas que se están leyendo';

  @override
  String get configAuditTitle => 'Auditoría de configuración';

  @override
  String get configAuditIntro =>
      'Lo que el BMS está configurado para hacer, comparado con lo que aguantan las celdas que dijiste que lleva.';

  @override
  String get configAuditOpen => 'Auditar la configuración';

  @override
  String get configAuditReadOnly =>
      'Solo lectura. Esta app no escribe valores de configuración en el BMS: un valor mal escrito en una batería es un incendio, y el camino de escritura del protocolo está sacado a base de ingeniería inversa. Lo que haya que cambiar se cambia desde la app oficial del BMS, y esa decisión es tuya. Lo único que la app puede tocar son los interruptores de carga, descarga y balanceador, y solo con el permiso de escritura encendido en Ajustes.';

  @override
  String get configAuditSettings => 'Todo lo que se ha mirado';

  @override
  String get configAuditNoSettings =>
      'El BMS todavía no ha mandado su configuración. Espera unos segundos con la batería conectada.';

  @override
  String get configAuditChemistryRow => 'Química declarada';

  @override
  String get configAuditNeedsProfile => 'Completar el perfil';

  @override
  String get alertNearCurrentLimit => 'Corriente cerca del límite del BMS';

  @override
  String get alertLinkLost => 'Se perdió la conexión con la batería';

  @override
  String get alertsNotifyTitle => 'Avisos en la barra de notificaciones';

  @override
  String get alertsNotifyIntro =>
      'Los avisos suenan en la barra de notificaciones con la app en segundo plano o la pantalla apagada (no si cierras la app deslizándola: entonces deja de leer la batería). Sin esto, un aviso a las tres de la mañana con el móvil en otra habitación no lo ve nadie.';

  @override
  String get alertsNotifyEnable => 'Avisar en la barra de notificaciones';

  @override
  String get alertsNotifyDenied =>
      'Android no ha dado permiso para notificar. Los avisos seguirán saliendo en pantalla y con vibración mientras mires la app, pero no llegarán con la app en segundo plano ni con la pantalla apagada.';

  @override
  String get alertsNotifyOneConnection =>
      'Recuerda: el BMS acepta una sola conexión Bluetooth. Mientras el móvil esté conectado en segundo plano, la app oficial de tu BMS no podrá conectarse, y al revés.';

  @override
  String get alertsThresholdsTitle => 'A partir de cuándo avisar';

  @override
  String get alertsThresholdsIntro =>
      'Los valores por defecto son conservadores. Si un aviso salta de más, muévelo hacia el lado que avisa menos: la diferencia entre celdas y la temperatura, hacia arriba; la carga baja, hacia abajo.';

  @override
  String get alertsDeltaWarn => 'Diferencia entre celdas';

  @override
  String get alertsTempWarn => 'Temperatura';

  @override
  String get alertsLowChargeWarn => 'Carga baja';

  @override
  String get alertsResetDefaults => 'Volver a los valores por defecto';

  @override
  String alertNotificationBodyDelta(String value) {
    return 'Las celdas se han separado $value V. La más baja marca cuándo se acaba la batería.';
  }

  @override
  String alertNotificationBodyTemp(String value) {
    return '$value °C. Para y déjala enfriar antes de seguir.';
  }

  @override
  String alertNotificationBodyLow(String value) {
    return 'Queda $value % de carga.';
  }

  @override
  String alertNotificationBodyCritical(String value) {
    return 'Queda $value % de carga. Busca dónde parar.';
  }

  @override
  String alertNotificationBodyCell(String value) {
    return 'Una celda está a $value V, cerca del corte del BMS. Se puede quedar sin batería aunque el porcentaje aún parezca razonable.';
  }

  @override
  String get alertNotificationBodyFault =>
      'El BMS ha levantado una protección. Mira la pantalla antes de seguir.';

  @override
  String alertNotificationBodyNearLimit(String value) {
    return '$value A, cerca de lo que el BMS permite. Si llega al límite, corta sin avisar.';
  }

  @override
  String get alertNotificationBodyLinkLost =>
      'La app dejó de recibir lecturas de la batería. Si estabas vigilando una carga, ya no se está vigilando.';

  @override
  String alertNotificationBodyChargeTarget(String value) {
    return 'El BMS marca $value %, lo que pediste. Es su contador, no una medición de las celdas.';
  }

  @override
  String get alertNotificationBodyChargeComplete =>
      'La celda más alta está arriba y el cargador ya casi no mete corriente: la carga ha terminado.';

  @override
  String alertNotificationBodyChargeHot(String value) {
    return '$value °C mientras carga. Desenchufa y déjala enfriar.';
  }

  @override
  String alertNotificationBodyChargeSpread(String value) {
    return 'Las celdas se han separado $value V al final de la carga. Es donde mejor se ve un desbalance.';
  }

  @override
  String get autoTripBlocked =>
      'No pude grabar el viaje: falta el permiso de ubicación. Sin él la app no aprende tu autonomía.';

  @override
  String rideSavedNotif(String km, String whPerKm) {
    return 'Viaje guardado: $km km, $whPerKm Wh/km';
  }

  @override
  String rideSavedNotifNoConsumption(String km) {
    return 'Viaje guardado: $km km';
  }

  @override
  String get representativeAsk => '¿Este viaje te representa?';

  @override
  String representativeAskBodyUp(
    String whPerKm,
    String percent,
    String before,
    String after,
  ) {
    return 'Salió en $whPerKm Wh/km, un $percent% por encima de lo tuyo. Ya lo conté: tu autonomía pasó de $before a $after km.';
  }

  @override
  String representativeAskBodyDown(
    String whPerKm,
    String percent,
    String before,
    String after,
  ) {
    return 'Salió en $whPerKm Wh/km, un $percent% por debajo de lo tuyo. Ya lo conté: tu autonomía pasó de $before a $after km.';
  }

  @override
  String representativeAskBodyUpNoKm(
    String whPerKm,
    String percent,
    String before,
    String after,
  ) {
    return 'Salió en $whPerKm Wh/km, un $percent% por encima de lo tuyo. Ya lo conté: tu consumo aprendido pasó de $before a $after Wh/km.';
  }

  @override
  String representativeAskBodyDownNoKm(
    String whPerKm,
    String percent,
    String before,
    String after,
  ) {
    return 'Salió en $whPerKm Wh/km, un $percent% por debajo de lo tuyo. Ya lo conté: tu consumo aprendido pasó de $before a $after Wh/km.';
  }

  @override
  String get representativeYes => 'Es normal';

  @override
  String get representativeNo => 'Fue una excepción';

  @override
  String representativeDone(String km) {
    return 'Listo. Tu autonomía queda en $km km.';
  }

  @override
  String representativeDoneNoKm(String whPerKm) {
    return 'Listo. Tu consumo aprendido sigue en $whPerKm Wh/km.';
  }

  @override
  String representativeMarkedException(String km) {
    return 'Listo. Ya no cuenta: tu autonomía queda en $km km.';
  }

  @override
  String representativeMarkedExceptionNoKm(String whPerKm) {
    return 'Listo. Ya no cuenta: tu consumo aprendido queda en $whPerKm Wh/km.';
  }

  @override
  String get representativeChange => 'Cambiar';

  @override
  String get tripRemeasure => 'Volver a medir';

  @override
  String get tripRemeasureWhy =>
      'Si el Bluetooth se cortó durante el viaje, el consumo pudo quedar muy por debajo de lo real. Esto lo vuelve a calcular desde las lecturas guardadas del pack.';

  @override
  String tripRemeasureDone(String whPerKm, String before) {
    return 'Medido de nuevo: $whPerKm Wh/km, antes $before Wh/km.';
  }

  @override
  String get tripRemeasureSame =>
      'Ya estaba bien medido. No hay nada que cambiar.';

  @override
  String get tripRemeasureFailed =>
      'No quedan lecturas para volver a medir este viaje, así que se queda como estaba.';

  @override
  String get tripUphill => 'Cuesta arriba';

  @override
  String get tripFlat => 'Llano';

  @override
  String get tripDownhill => 'Cuesta abajo';

  @override
  String healthCardCyclesBms(String n) {
    return 'el BMS dice $n';
  }

  @override
  String get healthWeakCell => 'La celda que manda';

  @override
  String get healthWeakCellWhy =>
      'El pack se apaga cuando la celda más baja llega al corte, no cuando la media llega. Todo lo que las demás todavía tienen por encima de ese punto no lo vas a usar.';

  @override
  String get healthWeakCellWhich => 'Cuál es';

  @override
  String get healthWeakCellStrands => 'Lo que deja sin usar';

  @override
  String get healthWeakCellResistance => 'Cable de balanceo desde el día uno';

  @override
  String healthWeakCellResistanceUp(String pct, String cell) {
    return '+$pct % en el cable de la celda $cell';
  }

  @override
  String get healthWeakCellResistanceFlat => 'Ningún cable se ha movido';

  @override
  String get healthWeakCellResistanceNoBaseline =>
      'Hace falta una foto del día uno para comparar';

  @override
  String get subjectCells => 'Celdas';

  @override
  String get subjectCapacity => 'Capacidad';

  @override
  String get subjectRange => 'Autonomía';

  @override
  String get subjectTemperature => 'Temperatura';

  @override
  String get subjectConfiguration => 'Configuración';

  @override
  String get subjectBmsClaims => 'Lo que el BMS dice de sí mismo';

  @override
  String adviceCheckedAllFine(String subjects) {
    return 'Revisé $subjects. Todo bien.';
  }

  @override
  String adviceCheckedSomeFine(String subjects) {
    return 'Revisé $subjects: bien.';
  }

  @override
  String adviceNotChecked(String subjects) {
    return 'De $subjects todavía no puedo decir nada.';
  }

  @override
  String get adviceCaveatsTitle => 'Cuánto vale esta medición';

  @override
  String get chargeWatchRedundant =>
      'Con el ajuste de arriba encendido la conexión ya se mantiene con la pantalla apagada, también mientras se recupera de un corte. Esto añade una cosa: mientras carga, la app no deja nunca de intentar reconectar. Sin esto se rinde tras unos seis minutos sin respuesta de la batería.';

  @override
  String get alertGroupSpread => 'Celdas separadas';

  @override
  String get alertGroupHeat => 'Temperatura';

  @override
  String get alertGroupRunningOut => 'Te estás quedando sin carga';

  @override
  String get alertGroupChargeDone => 'La carga terminó';

  @override
  String get alertGroupFaults => 'Fallos y límites';

  @override
  String get alertWhenRiding => 'Rodando';

  @override
  String get alertWhenCharging => 'Cargando';

  @override
  String get alertWhenTopOfCharge => 'Al final de la carga';

  @override
  String get alertTargetReachedShort => 'Llegó al objetivo que pusiste';

  @override
  String get alertBmsHot => 'El BMS está caliente';

  @override
  String get alertWhenBmsMosfet => 'El BMS (MOSFET)';

  @override
  String alertNotificationBodyBmsHot(String value) {
    return 'El MOSFET del BMS está a $value °C. No es la batería: es la pieza que corta la corriente si sigue subiendo. Afloja y dale aire.';
  }

  @override
  String statusBmsHotWatch(String temp) {
    return 'BMS caliente: $temp °C';
  }

  @override
  String statusBmsHotBad(String temp) {
    return 'BMS demasiado caliente: $temp °C';
  }

  @override
  String get adviceBmsHotTitle => 'El BMS está caliente';

  @override
  String adviceBmsHotBody(String temp) {
    return 'Su MOSFET llegó a $temp °C. No es la batería, pero es la pieza que corta la corriente si sigue subiendo. Fíjate que el BMS tenga aire y no esté pegado a algo que dé calor.';
  }

  @override
  String get evidenceMosfetTemp => 'MOSFET del BMS';

  @override
  String get thermalMirrorNote =>
      'La sonda 5 de este BMS repite la temperatura del MOSFET, así que no se cuenta como sonda de la batería.';

  @override
  String get thermalLegendMosfet => 'MOSFET (sin sondas en la batería)';

  @override
  String balanceWhichCellsReported(String cells) {
    return '$cells (lo informa el BMS)';
  }

  @override
  String get balanceWhichCellsNoneReported =>
      'ninguna ahora (lo informa el BMS)';

  @override
  String get balancerStoppedByHeat => 'detenido por calor';

  @override
  String alertNotificationBodyCellTypical(String value, String cutoff) {
    return 'Una celda está a $value V, cerca de $cutoff V, el corte habitual para esta química (el BMS no informó el suyo). Se puede quedar sin batería aunque el porcentaje aún parezca razonable.';
  }

  @override
  String alertNotificationBodyCellAssumed(String value, String cutoff) {
    return 'Una celda está a $value V, cerca de $cutoff V, un corte supuesto: el BMS no informó el suyo y no se sabe la química del pack. Se puede quedar sin batería aunque el porcentaje aún parezca razonable.';
  }

  @override
  String get alertNearLimitUnavailable =>
      'No disponible en este BMS: no informa su límite de corriente.';

  @override
  String get sessionEnergyIn => 'Energía que entró al pack';

  @override
  String get sessionEnergyHint =>
      'Desde que se conectó el pack. Solo cuenta los momentos en que llegaban lecturas.';

  @override
  String get healthWeakCellStrandsNeedsRest =>
      'Hace falta una lectura en reposo, sin corriente. En LFP, además, fuera de la zona plana de la curva.';

  @override
  String healthWeakCellStrandsAge(String minutes) {
    return 'De la última lectura en reposo, hace $minutes min.';
  }

  @override
  String get degSoldUnmeasured =>
      'Todavía sin medir contra lo anunciado: hace falta una descarga completa.';

  @override
  String get degConfiguredTitle => 'Capacidad configurada';

  @override
  String get healthVerdictReported => 'Sin medir todavía';

  @override
  String get healthWeakCellResistanceHint =>
      'El BMS mide la resistencia del cable de balanceo y su conexión, no la de la celda. Si sube, lo primero a revisar es ese cable.';

  @override
  String get cellsResistanceNote =>
      'Los mΩ bajo cada celda son la resistencia de su cable de balanceo y la conexión, que es lo que mide el BMS. No son la resistencia interna de la celda.';

  @override
  String get rangeFullFromBms =>
      'Sale de la capacidad configurada en el BMS, no de una medida.';

  @override
  String get reportRangeFromBmsConfig => 'capacidad configurada en el BMS';

  @override
  String capacityOfConfigured(String pct) {
    return '$pct % de la configurada';
  }

  @override
  String get historyItemDrift =>
      'Qué celda se va separando de las demás con las semanas';

  @override
  String get trendsCapacityNotEnough =>
      'Cada punto es una descarga completa medida con la app conectada, así que no se llena sola: hacen falta al menos tres.';

  @override
  String get profileCaptureBaselineHintNoSettings =>
      'Las celdas tal como están ahora. Este BMS no informa resistencias ni su configuración, así que la foto guarda lo que sí da. Todo lo que la app diga después sobre derivas se compara contra esto. Mejor con la batería en reposo.';

  @override
  String get profileConfigNotCompared => 'Sin comparar';

  @override
  String get profileDriftOtherCharge => 'a otro nivel de carga, no comparable';

  @override
  String get adviceCycleMismatchTitle => 'El contador de ciclos no cuadra';

  @override
  String adviceCycleMismatchBody(String bms, String equivalent) {
    return 'El BMS dice $bms ciclos, y la carga que él mismo contó pasar por el pack da $equivalent ciclos equivalentes. Cada firmware cuenta los ciclos a su manera y ese contador se puede editar, así que la diferencia puede ir para cualquier lado. Si vas a comprar o vender un pack, cita los dos.';
  }

  @override
  String get verdictDeltaLightTitle => 'Bajo carga ligera no se ve nada raro';

  @override
  String verdictDeltaLightBody(String loaded, String rest) {
    return 'Con corriente el delta llega a $loaded V, contra $rest V en reposo. Pero no ha habido carga fuerte suficiente para que una mala conexión se note, así que esto todavía no descarta nada.';
  }

  @override
  String get adviceBmsClaimsOkTitle => 'Lo que el BMS dice cuadra';

  @override
  String get adviceBmsClaimsOkBody =>
      'Lo que se pudo comprobar de lo que el BMS dice de sí mismo coincide con lo que se mide: el contador de ciclos con la carga que pasó, o el porcentaje con las celdas en un extremo de la carga.';

  @override
  String get adviceTemperatureOkTitle => 'Temperatura normal';

  @override
  String adviceTemperatureOkBody(String temp) {
    return 'La sonda más caliente de la batería marca $temp °C, y el BMS tampoco está caliente.';
  }

  @override
  String get adviceConfigNothingFlaggedTitle => 'Nada que objetar aquí';

  @override
  String adviceConfigNothingFlaggedBody(String voltage) {
    return 'El límite de carga por celda está en $voltage V, que no pasa de lo razonable. Esta pantalla solo mira eso; la revisión completa está en Auditar la configuración, en Sistema.';
  }

  @override
  String get verdictConfigColdCutoffMarginalTitle =>
      'El corte por frío tiene poco margen';

  @override
  String verdictConfigColdCutoffMarginalBody(String value, String limit) {
    return 'El corte por frío está en $value °C: por encima de cero, pero justo. La sonda mide el exterior del pack y las celdas por dentro tardan en calentarse. Súbelo a $limit °C o más desde la app oficial del BMS.';
  }

  @override
  String balanceRankingEntry(String cell, String pct) {
    return 'celda $cell: $pct %';
  }

  @override
  String get capacityNoFullMark =>
      'No se sabe dónde está lleno este pack: el BMS no ha dicho a cuánto carga y la química no se conoce. Indícala en los datos del pack para poder empezar el test.';

  @override
  String get capacityStopEarly => 'Terminar aquí';

  @override
  String get capacityStopEarlyHint =>
      'Si terminas antes del corte se guarda como parcial: lo contado es real, pero es un pedazo del pack y no se convierte en capacidad.';

  @override
  String get capacityPartialTag => 'parcial';

  @override
  String get capacityLegacyTag => 'antigua';

  @override
  String get capacityChargedTag => 'cargada a mitad';

  @override
  String get capacityUntrustedNote =>
      'Las marcadas no cuentan como capacidad. «parcial»: terminó antes del corte. «antigua»: se cerró con el porcentaje del BMS, que se calcula contra la capacidad configurada, así que devolvía esa configuración y no lo que tiene la batería. «cargada a mitad»: entró corriente por el camino.';

  @override
  String chargeGapNote(String minutes) {
    return '$minutes min sin conexión por el camino: esa parte la contó el BMS, no la app.';
  }

  @override
  String get etaNearlyFull => 'Casi lleno';

  @override
  String chargeTargetAtTop(String soc) {
    return 'Desde el $soc % este aviso es el de carga terminada: el contador del BMS llega ahí antes que las celdas, así que avisa cuando la celda más alta está arriba y la corriente ya bajó.';
  }

  @override
  String alertsTempWarnHint(String limit) {
    return 'Rodando avisa desde aquí. Cargando, desde aquí o desde $limit °C, lo que sea menor: cargar más caliente daña las celdas, así que ese límite no se sube.';
  }

  @override
  String alertsDeltaWarnHint(String limit) {
    return 'Rodando avisa desde aquí. Al final de la carga, desde aquí o desde $limit mV, lo que sea menor: arriba la curva es empinada y esa diferencia ya es un desbalance.';
  }

  @override
  String alertNotificationBodyCriticalIdle(String value) {
    return 'Queda $value % de carga. Cárgala antes de salir.';
  }

  @override
  String get alertsNotifyQuietChannel => 'Avisos sin vibración';

  @override
  String get alertLinkLostNeedsWatch =>
      'Solo avisa con «Seguir leyendo con la pantalla apagada» o «Vigilar la carga» encendidos: sin ellos no hay nada vigilando la conexión.';

  @override
  String get alertLinkLostRidingHint =>
      'Mientras grabas un viaje no avisa: rodando la conexión va y viene, y el viaje ya muestra en pantalla cuándo se corta.';

  @override
  String get alertsLowChargeWarnHint =>
      'Avisa al bajar de aquí. Bájalo si te avisa demasiado pronto; súbelo si quieres enterarte antes.';

  @override
  String get stuckTitle => 'El Bluetooth del teléfono parece atascado';

  @override
  String get stuckBody =>
      'Varios intentos seguidos han fallado con la batería al alcance. Prueba esto en orden y para en cuanto vuelva a conectar:';

  @override
  String get stuckResetButton => 'Reiniciar la conexión Bluetooth de la app';

  @override
  String get stuckStepForceStop =>
      'Si no basta, fuerza la detención de la app (Ajustes > Aplicaciones > JK BMS + > Forzar detención) y vuelve a abrirla.';

  @override
  String get stuckStepScanning =>
      'Después, desactiva «Búsqueda de Bluetooth» (Ajustes > Ubicación > Servicios de ubicación) y apaga y enciende el Bluetooth. Con esa búsqueda activada, apagar el Bluetooth no lo reinicia de verdad.';

  @override
  String get stuckStepRestart => 'Como último recurso, reinicia el teléfono.';

  @override
  String get stuckAskWhichStep =>
      'Cuando vuelva a conectar, avisa de qué paso lo arregló: eso dice si el fallo está en la app o en Android.';

  @override
  String get stuckResetDone =>
      'Conexión Bluetooth de la app reiniciada. Vuelve a tocar la batería.';

  @override
  String get stuckResetRunning =>
      'Reiniciando la conexión Bluetooth de la app…';

  @override
  String get consoleReportAttempts =>
      'Intentos de conexión, del más reciente al más antiguo';

  @override
  String get tripNoGpsFixes =>
      'No está llegando el GPS, así que este viaje no está midiendo distancia ni velocidad. La app lo está reintentando. Si sigue así, abre la app un momento con la pantalla encendida y comprueba que la ubicación esté activada.';

  @override
  String get locationApproximateOnly =>
      'La app solo tiene permiso de ubicación aproximada, y con eso no se puede medir un viaje: cada posición viene con cientos de metros de error. Activa \"Usar ubicación precisa\" en Ajustes > Aplicaciones > JK BMS + > Permisos > Ubicación, y vuelve a empezar el viaje.';

  @override
  String get inspectionCaveatRecoveryNoLoad =>
      'Sin carga fuerte tampoco hay recuperación que medir.';

  @override
  String get inspectionCaveatEndedBeforeLoad =>
      'La prueba se terminó antes de la carga: ni la caída por celda ni la recuperación se midieron.';

  @override
  String get inspectionCaveatEndedBeforeRecovery =>
      'La prueba se terminó mientras las celdas volvían: la recuperación no se midió.';

  @override
  String get inspectionCaveatRecoveryLinkGap =>
      'Se cortó la conexión con el BMS mientras las celdas volvían: la recuperación no se midió, porque el tiempo habría sido el del corte.';

  @override
  String get inspectionCaveatLinkGaps =>
      'La conexión con el BMS se cortó durante la prueba. Los pasos en los que cayó el corte volvieron a contar desde cero.';

  @override
  String verdictInspCellRisingTitle(String cell) {
    return 'La celda $cell sube mucho más que las demás';
  }

  @override
  String verdictInspCellRisingBody(String excess, String ohms) {
    return 'Con el cargador subió $excess V más que la mediana del pack: unos $ohms mΩ de resistencia de más. Coherente con una celda gastada o con una conexión mala en esa celda. Es la razón principal para no pagar el precio pedido sin más pruebas.';
  }

  @override
  String get verdictInspSagUniformChargeTitle =>
      'Todas las celdas suben parejo';

  @override
  String verdictInspSagUniformChargeBody(
    String amps,
    String excess,
    String floor,
  ) {
    return 'Con el cargador ($amps A) la celda que más subió lo hizo solo $excess V más que la mediana. A esta corriente ya se distinguiría una celda con unos $floor mΩ de resistencia de más, y ninguna se aparta de las demás.';
  }

  @override
  String get verdictInspSagUnresolvedTitle =>
      'Carga insuficiente para descartar una celda mala';

  @override
  String verdictInspSagUnresolvedBody(String amps, String floor) {
    return 'A esta carga ($amps A) no se distingue una celda con menos de $floor mΩ extra, y una celda mala puede tener menos que eso. Las celdas se movieron parejas, pero con tan poca corriente eso no descarta nada. Repite rodando con carga real (una cuesta o acelerar fuerte), o con el cargador.';
  }

  @override
  String get verdictInspRecoveryNotDiscriminatingTitle =>
      'Con esta carga la recuperación no dice nada';

  @override
  String verdictInspRecoveryNotDiscriminatingBody(String seconds, String amps) {
    return 'Las celdas volvieron a su reposo en unos $seconds s. Con esta carga ($amps A) la recuperación no discrimina: una celda cansada vuelve casi tan rápido como una buena. Para que cuente hace falta un tirón de al menos un tercio de la capacidad del pack.';
  }

  @override
  String verdictInspHotRestBody(String temp) {
    return 'Llegó a $temp °C en reposo o con solo las luces. Un pack caliente sin carga no es normal: o venía de un uso fuerte justo antes, o algo dentro se calienta solo.';
  }

  @override
  String verdictInspHotLoadBody(String temp) {
    return 'Llegó a $temp °C durante la carga fuerte o justo después. Un tirón de unos segundos no calienta tanto un pack sano: o ya venía caliente, o algo se calienta de más bajo carga.';
  }

  @override
  String get evidenceInspectionRestDelta =>
      'Delta en reposo (mediana de cada celda en reposo)';

  @override
  String evidenceExcessResistance(String cell) {
    return 'Resistencia de más, celda $cell';
  }

  @override
  String get evidenceDetectionFloor =>
      'Lo mínimo que se distingue a esta carga';

  @override
  String get evidenceLoadWasCharge => 'Carga usada';

  @override
  String get evidenceLoadCharger => 'el cargador';

  @override
  String get evidenceSeenDuringStep => 'Cuándo se vio';

  @override
  String get evidenceStepRest => 'en reposo';

  @override
  String get evidenceStepLight => 'con las luces';

  @override
  String get evidenceStepHeavy => 'con la carga fuerte';

  @override
  String get evidenceStepRecovery => 'al soltar la carga';

  @override
  String get inspectionFidelityNoteUnmeasured =>
      'Sin una carga suficiente este test no ha podido buscar la celda mala: lo de arriba es solo lo que se ve en reposo. Tampoco mide capacidad real; para eso hace falta una descarga completa.';

  @override
  String get inspectionLightUnresolved =>
      'Sin veredicto: la carga no bastó para descartar una celda mala';

  @override
  String get inspectionUnresolvedBody =>
      'Hubo carga, pero poca: a esa corriente una celda mala puede moverse igual que las buenas, así que aquí no hay nada sobre esta batería ni a favor ni en contra. Repítelo con más corriente: rodando con carga real (una cuesta o acelerar fuerte), o con el cargador.';

  @override
  String get inspectionLightUnmeasuredShort => 'Sin veredicto';

  @override
  String get verdictInspRepeatConfigChangedTitle =>
      'Cambió la configuración o los contadores entre visitas';

  @override
  String get verdictInspRepeatConfigChangedBody =>
      'Entre las dos pruebas cambió la capacidad configurada, o subió la salud que reporta el BMS. Puede ser el dueño corrigiendo un ajuste o el firmware recalculando, y no tiene por qué ser un engaño, pero pregunta qué se tocó. Lo físico de arriba no depende de estos números.';

  @override
  String evidencePreviousCycleCapacity(String date) {
    return 'Energía total contada el $date';
  }

  @override
  String get evidenceCycleCapacity => 'Energía total contada por el BMS';

  @override
  String get certificateIssuedHere => 'Emitido por este teléfono.';

  @override
  String get certificateDoesNotProve =>
      'Lo que la firma no demuestra: qué batería se probó (el nombre y el número de serie los da el BMS y se pueden cambiar), ni la fecha, que es la del reloj del teléfono que firmó, ni que la batería esté bien.';

  @override
  String get certificateSimulated =>
      'PRUEBA CON PACK SIMULADO. Estas cifras salieron del simulador de la app, no de una batería.';

  @override
  String get certificateSimulatedUnknown =>
      'Certificado de una versión anterior de la app: no dice si la prueba se hizo con una batería o con el pack simulado.';

  @override
  String get certificateNoSimulated =>
      'Un ensayo con el pack simulado no se puede firmar: un certificado dice que las cifras salieron de una batería.';

  @override
  String get certificateLocalIssuer => 'Código de emisor de este teléfono';

  @override
  String get certificateLocalIssuerHint =>
      'Es el código que verá quien compruebe un certificado firmado en este teléfono. Publícalo donde te conozcan (tu anuncio, tu taller) para que puedan compararlo.';

  @override
  String get inspectionSimulatedBanner =>
      'PRUEBA CON PACK SIMULADO. Nada de esto es de una batería real.';

  @override
  String get reportCertificateIssuerCheck =>
      'Comprueba que este código de emisor es el que publica quien te dio el certificado.';

  @override
  String get reportPackLabel => 'Batería';

  @override
  String get reportCurrentStep => 'Escalón de corriente (carga menos reposo)';

  @override
  String get reportMedianRise => 'Subida mediana con el cargador';

  @override
  String get inspectionCellHeaderChange => 'Cambio';

  @override
  String get inspectionSaveTitle => 'Guardar esta prueba';

  @override
  String reportHonestyInspectionUnmeasured(String date) {
    return 'Test rápido del $date sin una carga suficiente: no se ha podido buscar la celda mala, y esta hoja no dice nada a favor ni en contra de la batería. No mide capacidad: la capacidad que aparece es la configurada en el BMS, no una medida.';
  }

  @override
  String get reportSeriesNoteUnsigned =>
      'Cada fila es una inspección guardada en el teléfono que hizo esta hoja, incluida esta, que es la última. Esta hoja no está firmada. Repetir el test es lo que distingue una celda mala de una lectura mala.';

  @override
  String get reportChange => 'Cambio (V)';

  @override
  String get reportCellTableNoteCharge =>
      'El cambio es cuánto subió cada celda con el cargador. La resistencia se estima del salto de corriente, no se mide con instrumento.';

  @override
  String get inspectionDeleteConfirm => 'Borrar';

  @override
  String get inspectionSaveNoStore =>
      'No se pudo guardar: el almacenamiento de la app no está disponible.';

  @override
  String get autoTripPocketNeedsLinkWatch =>
      'Con «Seguir leyendo con la pantalla apagada» desactivado, la app deja de leer el pack al apagarse la pantalla, así que con el móvil en el bolsillo no puede empezar ningún viaje.';

  @override
  String get autoTripPocketWhileInUse =>
      'Con el móvil en el bolsillo funciona mientras siga puesta la notificación que la app abrió al conectar con la pantalla encendida. Si Android la cierra, o la app se reconecta sola con la pantalla apagada, el GPS solo responde con la ubicación permitida todo el tiempo, y sin GPS el viaje no empieza.';

  @override
  String get autoTripPocketAllowAlways =>
      'Permitir la ubicación todo el tiempo';

  @override
  String get autoTripPocketSettingsHint =>
      'En los ajustes de la app, entra en Permisos, Ubicación, y elige «Permitir todo el tiempo».';

  @override
  String get autoTripPocketAlways =>
      'Ubicación permitida todo el tiempo: el viaje puede empezar con el móvil en el bolsillo aunque la app se haya reconectado sola.';

  @override
  String offlineWeakestRestValue(String index, String pct, String count) {
    return 'celda $index, la más baja en el $pct % de $count lecturas en reposo del último mes';
  }

  @override
  String get offlineLowestLastReading => 'Celda más baja en la última lectura';

  @override
  String historyAverageOf(String used, String total) {
    return 'de $used de $total viajes: los medidos que cuentan para la autonomía';
  }

  @override
  String learnWhyUnmeasured(String n) {
    return '$n no se pudieron medir: la conexión con la batería se cortó durante buena parte del viaje y no quedaron lecturas para saber cuánta energía salió. No es algo del manejo. Si el viaje conserva lecturas, «Volver a medir» en su detalle lo intenta otra vez.';
  }

  @override
  String learnWhyExcluded(String n) {
    return '$n los marcaste como una excepción, así que no cuentan.';
  }

  @override
  String get tripNotMeasured => 'sin medir';

  @override
  String get tripEnergyUnmeasuredWhy =>
      'La conexión con la batería se cortó durante buena parte del viaje y no quedaron lecturas para saber cuánta energía salió. No cuenta para la autonomía.';

  @override
  String get tripEnergySourceLabel => 'Cómo se midió';

  @override
  String get tripEnergySourceBms => 'contador del BMS, todo el viaje';

  @override
  String get tripEnergySourceIntegrated => 'sumado de las lecturas recibidas';

  @override
  String get tripEnergySourceBracketed =>
      'contador del BMS, de las lecturas de antes y después';

  @override
  String get tripEnergySourcePartial => 'parcial: la conexión se cortó';

  @override
  String get tripEnergySourceUnmeasurable => 'no se pudo medir';

  @override
  String get tripResistanceHint =>
      'La mediana de la pendiente del voltaje contra la corriente en los tramos en que la corriente cambió mucho. Aproximada: sirve para seguir el mismo pack con los meses, no para compararlo con una hoja de datos.';

  @override
  String get trendsCapacityHollow =>
      'Los círculos huecos son descargas que la app no da por buenas (faltaron minutos, hubo carga en medio o se cerraron por el porcentaje) o que detectó sola al rodar. Se ven, pero no entran en la tendencia.';

  @override
  String get maintDeleteConfirmTitle => '¿Borrar esta anotación?';

  @override
  String get maintDeleteConfirmBody =>
      'Se quita del registro de mantenimiento y de las gráficas.';

  @override
  String get maintDeleteConfirmCellBody =>
      'Se quita del registro, y el historial de la batería vuelve a contar desde antes del cambio de celda: la deriva, la capacidad y las gráficas incluirán otra vez las celdas viejas.';

  @override
  String get orphansDiscardConfirmTitle => '¿Descartar este historial?';

  @override
  String orphansDiscardConfirmBody(String count) {
    return 'Se borran para siempre $count filas guardadas sin batería asignada. No se puede deshacer.';
  }

  @override
  String tripEnergySoFarOffline(String wh) {
    return '$wh Wh hasta que se cortó la conexión';
  }

  @override
  String tripReadingAgeSeconds(String s) {
    return 'hace $s s';
  }

  @override
  String tripReadingAgeMinutes(String m) {
    return 'hace $m min';
  }

  @override
  String backupExportFailed(String reason) {
    return 'No se pudo hacer la copia: $reason';
  }

  @override
  String get exportShared => 'Enviado.';

  @override
  String get exportRange => 'Lecturas y frames de:';

  @override
  String get exportRangeDay => '1 día';

  @override
  String get exportRangeWeek => '7 días';

  @override
  String get exportRangeMonth => '30 días';

  @override
  String get exportRangeAll => 'Todo';

  @override
  String get exportRangeNote =>
      'Los frames crudos se guardan 30 días, así que «Todo» trae como mucho esos. Las lecturas de más de un mes están guardadas una por minuto.';

  @override
  String get tripExportGpx => 'Exportar recorrido (GPX)';

  @override
  String get settingsGroupCell => 'Protecciones de celda';

  @override
  String get settingsGroupCurrent => 'Corriente';

  @override
  String get settingsGroupTemperature => 'Temperatura';

  @override
  String get settingsGroupBalance => 'Balanceo';

  @override
  String get settingsGroupOther => 'Otros';

  @override
  String get settingSmartSleep => 'Voltaje de reposo inteligente';

  @override
  String get settingRequestCharge => 'Voltaje de carga pedido por celda';

  @override
  String get settingRequestFloat => 'Voltaje de flotación pedido por celda';

  @override
  String get settingChargeOcpDelay => 'Retardo de sobrecorriente en carga';

  @override
  String get settingChargeOcpRecovery =>
      'Recuperación de sobrecorriente en carga';

  @override
  String get settingDischargeOcpDelay =>
      'Retardo de sobrecorriente en descarga';

  @override
  String get settingDischargeOcpRecovery =>
      'Recuperación de sobrecorriente en descarga';

  @override
  String get settingScpDelay => 'Retardo de cortocircuito';

  @override
  String get settingScpRecovery => 'Recuperación de cortocircuito';

  @override
  String get settingChargeOtpRecovery =>
      'Recuperación de sobretemperatura en carga';

  @override
  String get settingDischargeOtpRecovery =>
      'Recuperación de sobretemperatura en descarga';

  @override
  String get settingChargeUtpRecovery =>
      'Recuperación de subtemperatura en carga';

  @override
  String get settingMosfetOtpRecovery =>
      'Recuperación de sobretemperatura de MOSFET';

  @override
  String get settingWireResistances => 'Resistencia de los cables de balanceo';

  @override
  String settingWireResistancesCount(int count) {
    return '$count celdas';
  }

  @override
  String get settingWireResistancesHint =>
      'Lo que el BMS tiene configurado para compensar el cable de cada celda, en miliohmios. Es un ajuste, no una medición de la celda.';

  @override
  String get systemSetupPasscode => 'Contraseña de ajustes que entrega el BMS';

  @override
  String get bmsStateTitle => 'Estado del BMS';

  @override
  String get bmsStateIntro => 'Tal como lo informa el BMS en cada lectura.';

  @override
  String get bmsStatePrecharge => 'Precarga';

  @override
  String get bmsStateChargerPlugged => 'Ve un cargador conectado';

  @override
  String get bmsStateChargeStatus => 'Fase de carga';

  @override
  String get bmsStateBatteryType => 'Tipo de batería configurado';

  @override
  String get bmsStateBatteryTypeHint =>
      'Es lo que alguien eligió al configurar el BMS, no algo que el BMS mida en las celdas.';

  @override
  String get bmsStateRuntime => 'Tiempo de funcionamiento total';

  @override
  String get bmsStateEnabledCells => 'Celdas habilitadas';

  @override
  String get bmsStateCycleCapacity => 'Carga total que pasó por el pack';

  @override
  String get bmsStateCycleCapacityHint =>
      'El contador acumulado del propio BMS. Dividido por la capacidad da los ciclos completos reales.';

  @override
  String get chargeStatusBulk => 'corriente constante';

  @override
  String get chargeStatusAbsorption => 'absorción';

  @override
  String get chargeStatusFloat => 'flotación';

  @override
  String get batteryTypeLfp => 'LFP (LiFePO4)';

  @override
  String get batteryTypeLiIon => 'Litio-ion';

  @override
  String get batteryTypeLto => 'LTO';

  @override
  String bmsUnknownCode(String code) {
    return 'código $code';
  }

  @override
  String get nowChargerByBms => 'Según el BMS';

  @override
  String get nowChargerSeen => 've el cargador conectado';

  @override
  String get nowChargerNotSeen => 'no ve ningún cargador';

  @override
  String nowChargePhase(String phase) {
    return 'fase: $phase';
  }

  @override
  String get profileBaselineNoteAdd => 'Añadir una nota';

  @override
  String get profileBaselineNoteEdit => 'Editar la nota';

  @override
  String get profileBaselineNoteTitle => 'Nota del día uno';

  @override
  String get profileBaselineNoteHint =>
      'De dónde vino, qué dijo el vendedor, lo que costó.';

  @override
  String get profileBaselineRedo => 'Rehacer el día uno';

  @override
  String get profileBaselineRedoTitle => '¿Rehacer el día uno?';

  @override
  String profileBaselineRedoBody(String date) {
    return 'Se borra el día uno guardado el $date y se guarda uno nuevo con la lectura y la configuración del BMS de ahora. Todo lo que la app compara «desde el día uno» vuelve a empezar hoy. La nota se conserva. No se puede deshacer, y conviene hacerlo con la batería en reposo.';
  }

  @override
  String get profileBaselineRedoConfirm => 'Borrar y guardar el nuevo';

  @override
  String get profileBaselineRedone =>
      'Día uno guardado de nuevo, con la lectura de ahora.';

  @override
  String get balanceRankingNeedsHistory => 'necesita más histórico';

  @override
  String balanceRankingProgress(String count, String needed) {
    return '$count de $needed lecturas en reposo con las celdas separadas al menos 10 mV, en los últimos 30 días.';
  }

  @override
  String balanceRankingBasis(String count) {
    return 'De $count lecturas en reposo de los últimos 30 días con las celdas separadas al menos 10 mV. La más baja en reposo es la que tiene menos carga: dice dónde mirar, no que esa celda esté mal.';
  }

  @override
  String get faultHistoryTitle => 'Historial de fallos del BMS';

  @override
  String get faultHistoryIntro =>
      'Cada vez que el BMS levantó una protección o un aviso en esta batería, la más reciente primero. Sale del registro de avisos que se guarda con cada lectura, así que es solo lo que la app vio: sin conexión no hay lecturas.';

  @override
  String get faultHistoryEmpty =>
      'Ninguna protección ni aviso del BMS en las lecturas guardadas de esta batería.';

  @override
  String get faultHistoryThinned =>
      'Las lecturas de más de un mes se guardan una por minuto. Ahí un fallo más corto que eso puede no aparecer, y las duraciones son aproximadas.';

  @override
  String faultUnknownBit(int bit) {
    return 'Aviso sin nombre (bit $bit)';
  }

  @override
  String get faultOngoing => 'seguía en la última lectura';

  @override
  String get faultInstant => 'una lectura';

  @override
  String get faultStarted => 'Visto por primera vez';

  @override
  String get faultLastSeen => 'Visto por última vez';

  @override
  String get faultNoData =>
      'Sin datos: la conexión estuvo caída más de 5 minutos durante el fallo o justo antes o después, así que pudo empezar antes, acabar después o ir y venir sin que nadie lo viera.';

  @override
  String get faultReadings => 'Lecturas con el aviso';

  @override
  String get faultAtStart => 'Al empezar';

  @override
  String faultAtStartCells(String max, String min) {
    return 'Celda más alta $max V, más baja $min V.';
  }

  @override
  String get offlineMoreHistory => 'Más historial';

  @override
  String get cellHistoryTitle => 'Celdas en el tiempo';

  @override
  String get cellHistoryOpen => 'Ver historial';

  @override
  String get cellHistoryTripButton => 'Celdas durante el viaje';

  @override
  String get cellHistoryRangeHour => 'Última hora';

  @override
  String get cellHistoryRangeDay => 'Últimas 24 h';

  @override
  String get cellHistoryRangeWeek => 'Últimos 7 días';

  @override
  String get cellHistoryRangeTrip => 'Este viaje';

  @override
  String get cellHistoryRangeCharge => 'Última carga';

  @override
  String cellHistoryAnchor(String date) {
    return 'Hasta la última lectura guardada, $date.';
  }

  @override
  String get cellHistoryModeVolts => 'Voltaje';

  @override
  String get cellHistoryModeDeviation => 'Frente al promedio';

  @override
  String get cellHistoryAxisVolts => 'V por celda';

  @override
  String get cellHistoryAxisDeviation =>
      'mV por encima o por debajo del promedio del pack en esa lectura';

  @override
  String cellHistoryLowest(int cell) {
    return 'Celda $cell: la más baja de media en este intervalo';
  }

  @override
  String cellHistoryHighest(int cell) {
    return 'Celda $cell: la más alta de media en este intervalo';
  }

  @override
  String cellHistoryPicked(int cell) {
    return 'Celda $cell: la que elegiste';
  }

  @override
  String get cellHistoryOthers => 'Las demás';

  @override
  String get cellHistoryPickCell => 'Resaltar una celda';

  @override
  String cellHistoryPoints(int count) {
    return '$count lecturas';
  }

  @override
  String cellHistoryNote(String bucket) {
    return 'Cada punto es una lectura real, una por cada $bucket: un pico entre dos de ellas no se dibuja. Donde las líneas se cortan no hubo lecturas durante más de 30 segundos, y no se rellena.';
  }

  @override
  String get cellHistoryEmpty => 'No hay lecturas guardadas en este intervalo.';

  @override
  String get linkEventRidingCurrentSeen => 'Corriente de marcha vista';

  @override
  String get linkEventIdleSpeedSeen => 'Velocidad vista sin viaje abierto';

  @override
  String get linkEventLocationArmed => 'GPS encendido';

  @override
  String get linkEventLocationStoodDown => 'GPS apagado';

  @override
  String get linkEventLocationRefused => 'El GPS no arrancó';

  @override
  String get linkEventTripWithoutFixes => 'Viaje sin posición GPS';

  @override
  String get linkEventLocationStreamError => 'Error del GPS';

  @override
  String get linkEventForegroundServiceRefused =>
      'Android no dejó arrancar el servicio';

  @override
  String get linkEventForegroundServiceLost => 'Android paró el servicio';

  @override
  String get linkEventAutoTripStarted => 'Viaje abierto solo';

  @override
  String get linkEventAutoTripStopped => 'Viaje cerrado solo';

  @override
  String get linkEventAutoTripBlocked => 'No se pudo abrir el viaje';

  @override
  String get linkEventReadingsResumed => 'Vuelven las lecturas';

  @override
  String get linkEventLinkDropped => 'Conexión perdida';

  @override
  String get linkEventMuteLinkReleased => 'Conexión muda soltada';

  @override
  String get linkEventReconnectAttempted => 'Intento de reconexión';

  @override
  String get linkEventReconnectFailed => 'Reconexión fallida';

  @override
  String get linkEventReconnectGaveUp => 'Dejó de intentar reconectar';

  @override
  String get linkEventReconnectPersisting =>
      'Reconexión sin rendirse (viaje en curso)';

  @override
  String get linkEventReconnectRelaxed => 'Reconexión normal otra vez';

  @override
  String get linkEventConnectAttempt => 'Intento de conexión';

  @override
  String get linkEventBluetoothLooksStuck =>
      'El Bluetooth del teléfono parece atascado';

  @override
  String get linkEventBluetoothRemedy => 'Remedio de Bluetooth';

  @override
  String get linkEventBluetoothRecovered => 'Conectó tras el atasco';

  @override
  String get linkEventProtocolSwitched => 'Cambio de protocolo';

  @override
  String get linkEventAntFrameRejected => 'Frame ANT descartado';

  @override
  String get linkEventAntDecodeFailed => 'Frame ANT sin descifrar';

  @override
  String get linkEventOldAntProtocolSeen => 'Protocolo ANT antiguo';

  @override
  String get linkEventJkFrameRejected => 'Bytes JK descartados';

  @override
  String get linkEventJkFrameUndecoded => 'Frame JK sin descifrar';

  @override
  String get linkEventAntCurrentSignInverted =>
      'Signo de corriente ANT invertido';

  @override
  String get linkEventsTitle => 'Historial de conexión';

  @override
  String get linkEventsIntro =>
      'Lo que la app decidió y cuándo: cada intento de conexión, cada caída, cada viaje que se abrió o no. Se guarda 14 días.';

  @override
  String get linkEventsThisPack => 'Esta batería';

  @override
  String get linkEventsAllPacks => 'Todas';

  @override
  String get linkEventsThisPackHint =>
      'Lo que pasa mientras se conecta casi nunca tiene batería asignada todavía: está en «Todas».';

  @override
  String get linkEventsAnyKind => 'Todos los tipos';

  @override
  String get linkEventsEmpty => 'Nada registrado con estos filtros.';

  @override
  String get linkEventsNoPack => 'sin batería';

  @override
  String linkEventsBytes(int count) {
    return '$count bytes';
  }

  @override
  String get linkEventsCopyBytes => 'Copiar los bytes';

  @override
  String get linkEventsBytesCopied => 'Bytes copiados';

  @override
  String get linkEventsCopyAll => 'Copiar todo lo mostrado';

  @override
  String linkEventsCopiedAll(int count) {
    return 'Copiado: $count filas';
  }

  @override
  String linkEventsCount(int count) {
    return '$count filas';
  }

  @override
  String linkEventsUnknownKind(String name) {
    return 'Tipo desconocido: $name';
  }

  @override
  String get workshopTitle => 'Datos del taller en los informes';

  @override
  String get workshopIntro =>
      'Se imprimen arriba en los PDF: el de la batería y el de inspección. Las cifras siguen siendo las que mide la app, y el informe lo sigue diciendo.';

  @override
  String get workshopName => 'Nombre del taller';

  @override
  String get workshopLine => 'Línea de contacto';

  @override
  String get workshopLineHint => 'Teléfono, dirección o web';

  @override
  String get workshopLogo => 'Logo';

  @override
  String get workshopLogoPick => 'Elegir logo';

  @override
  String get workshopLogoChange => 'Cambiar';

  @override
  String get workshopLogoRemove => 'Quitar';

  @override
  String get workshopLogoRefused =>
      'Ese archivo no sirve: tiene que ser PNG o JPEG, de menos de 1 MB.';

  @override
  String get workshopSaved => 'Guardado. Sale en el próximo informe.';

  @override
  String get workshopSaveFailed => 'No se pudo guardar.';

  @override
  String get linkEventBmsWriteRefused =>
      'Cambio en el BMS rechazado por la app';

  @override
  String get linkEventBmsWriteNotSent => 'Cambio en el BMS sin enviar';

  @override
  String get linkEventBmsWriteSent => 'Cambio enviado al BMS';

  @override
  String get linkEventBmsWriteConfirmed => 'El BMS confirmó el cambio';

  @override
  String get linkEventBmsWriteUnconfirmed => 'El BMS no confirmó el cambio';

  @override
  String get settingsSectionBmsWrites => 'Cambios en el BMS';

  @override
  String get bmsWritesTitle => 'Permitir que la app cambie el BMS';

  @override
  String get bmsWritesHint =>
      'Apagado, la app no cambia nada en el BMS. Encendido, puede encender y apagar la carga, la descarga y el balanceador desde Sistema, en Configuración del BMS, y cada vez te pide confirmación. Solo en un JK. Ningún valor de configuración (voltajes, corrientes, temperaturas) se escribe nunca.';

  @override
  String get bmsWritesConfirmTitle => '¿Permitir cambios en el BMS?';

  @override
  String get bmsWritesConfirmBody =>
      'Con esto encendido, la app puede apagar la carga, la descarga y el balanceador del BMS. Apagar la descarga corta la corriente: la moto se queda sin potencia y sin luces. Cada cambio te pide confirmación, la app no apaga la descarga con la moto en marcha, y solo da un cambio por hecho cuando el BMS lo confirma. El protocolo está sacado a base de ingeniería inversa: úsalo bajo tu responsabilidad.';

  @override
  String get bmsWritesConfirmAction => 'Permitir';

  @override
  String get bmsSwitchesLocked =>
      'Solo lectura. Para cambiarlos, activa «Permitir que la app cambie el BMS» en Ajustes.';

  @override
  String get bmsSwitchesHint =>
      'Lo que se ve es lo último que dijo el BMS. Cada cambio pide confirmación y se da por hecho solo cuando el BMS lo confirma.';

  @override
  String get bmsSwitchSending => 'Enviado. Esperando a que el BMS lo confirme.';

  @override
  String bmsSwitchConfirmTitle(String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'chargeOff': '¿Apagar la carga?',
      'chargeOn': '¿Encender la carga?',
      'dischargeOff': '¿Apagar la descarga?',
      'dischargeOn': '¿Encender la descarga?',
      'balancerOff': '¿Apagar el balanceador?',
      'balancerOn': '¿Encender el balanceador?',
      'other': '¿Cambiar el interruptor?',
    });
    return '$_temp0';
  }

  @override
  String bmsSwitchConfirmBody(String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'chargeOff':
          'El BMS deja de aceptar carga: con el cargador enchufado, la batería no carga hasta que lo vuelvas a encender. Con la batería baja, no lo dejes así.',
      'chargeOn':
          'El BMS vuelve a aceptar carga. Sus propias protecciones siguen cortando como siempre.',
      'dischargeOff':
          'La batería deja de dar corriente: la moto se queda sin potencia, sin luces y sin controlador hasta que lo vuelvas a encender, desde aquí o desde la app oficial. Hazlo solo con la moto parada y en un sitio seguro.',
      'dischargeOn':
          'La batería vuelve a dar corriente. Comprueba antes que el acelerador está en reposo.',
      'balancerOff':
          'El balanceador deja de igualar las celdas. Con el tiempo se separan, el pack pierde capacidad útil y una celda llega antes al corte. Vuelve a encenderlo cuando termines.',
      'balancerOn':
          'El balanceador vuelve a igualar las celdas según su voltaje de arranque.',
      'other': 'El BMS cambia este interruptor.',
    });
    return '$_temp0';
  }

  @override
  String get bmsSwitchConfirmAction => 'Enviar al BMS';

  @override
  String get bmsSwitchApplied => 'Aplicado: el BMS lo confirma.';

  @override
  String get bmsSwitchUnconfirmed =>
      'El BMS no confirmó el cambio. Lo que ves es lo último que dijo; queda anotado en el historial de conexión.';

  @override
  String get bmsSwitchNotSent =>
      'No se pudo enviar: el Bluetooth no aceptó la escritura. No cambió nada.';

  @override
  String bmsSwitchRefused(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'notPermitted':
          'La app no tiene permiso para cambiar el BMS. Se activa en Ajustes.',
      'notJk': 'Solo se puede en un JK. En un ANT la app no escribe nada.',
      'notConnected': 'No hay conexión con el BMS.',
      'variantUnsupported':
          'Este BMS habla un formato (JK04 o desconocido) en el que la app no escribe. No se envió nada.',
      'noSettings':
          'El BMS todavía no mandó su configuración, así que no se sabe cómo está ahora.',
      'noRecentReading':
          'No hay lecturas recientes: sin ellas la app no puede saber si la moto anda ni esperar la respuesta del BMS.',
      'readingImplausible':
          'Las lecturas no cuadran con el formato en uso. Mientras no cuadren, la app no escribe nada.',
      'alreadySet': 'El BMS ya lo tiene así.',
      'riding':
          'Para la moto primero: con la moto en marcha o un viaje grabándose, la app no apaga la descarga.',
      'busy': 'Hay otro cambio esperando la respuesta del BMS.',
      'other': 'No se envió nada.',
    });
    return '$_temp0';
  }

  @override
  String get systemWritesOnNote =>
      'El permiso de escritura está encendido: la app solo puede encender y apagar los tres interruptores de arriba, cada vez con tu confirmación. Ningún otro valor se escribe nunca.';

  @override
  String get tripMapTitle => 'Recorrido';

  @override
  String get tripMapStart => 'Salida';

  @override
  String get tripMapEnd => 'Llegada';

  @override
  String get tripMapBySpeed => 'Velocidad';

  @override
  String get tripMapByPower => 'Potencia';

  @override
  String get tripMapPowerHint =>
      'Lo que daba la batería en cada punto: su voltaje por su corriente, tal como los mandó el BMS junto a cada posición. No es consumo por kilómetro, que en cada parada se dispara aunque no se gaste nada.';

  @override
  String get tripMapOffline =>
      'El mapa de fondo se pide a OpenStreetMap por internet al abrir esta pantalla, así que sus servidores ven por qué zona fue el viaje (no el viaje en sí). Sin conexión, el recorrido se dibuja igual sobre fondo liso.';
}
