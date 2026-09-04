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
      'El JK BMS acepta una sola conexión Bluetooth a la vez. Cierra la app oficial de JK antes de conectar aquí.';

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
      'No apareció nada. Casi siempre es una de estas:\n\n• La app oficial de JK está conectada al BMS. Mientras lo está, el BMS deja de anunciarse y ningún otro teléfono lo ve. Ciérrala del todo.\n• El pack está dormido. Enciende la moto o muévela para despertarlo.\n• Estás lejos. Acércate al pack.';

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
  String get tapBusy =>
      'Ya hay un intento en marcha. Espera a que termine: tocar otra vez no lo acelera y sí puede dejar otra conexión colgada en el teléfono.';

  @override
  String tapCooling(String seconds) {
    return 'Espera $seconds s antes de reintentar con esta batería. La pausa no es un capricho: el BMS tarda unos segundos en soltar el enlace anterior, y cada intento dentro de esa ventana deja una conexión que el teléfono no cierra.';
  }

  @override
  String tapStackSaturated(String count) {
    return 'Van $count intentos fallidos seguidos. A estas alturas el problema es el Bluetooth del teléfono, no la batería, y otro intento solo lo empeora. Apaga y enciende el Bluetooth; si sigue igual, reinicia el teléfono. Después toca Desconectar o vuelve a buscar para reintentar.';
  }

  @override
  String get tapHeldByPhone =>
      'El teléfono ya tiene abierta una conexión con esta batería que esta app no controla. O la tiene otra app, o quedó colgada de un intento anterior. Ningún intento desde aquí va a ganarla: cierra la otra app, o reinicia el Bluetooth del teléfono.';

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
  String get sessionEnergy => 'Energía por el pack';

  @override
  String get sessionDistance => 'Distancia';

  @override
  String get sessionWhPerKm => 'Wh por km';

  @override
  String get sessionSamples => 'Muestras en memoria';

  @override
  String get needsGps => 'necesita un viaje activo';

  @override
  String get needsDatabase => 'necesita más histórico';

  @override
  String get needsSteps => 'necesita escalones de corriente';

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
  String get packSagNoBaseline => 'sin lectura en reposo aún';

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
  String get balanceRanking => 'Ranking de celda débil';

  @override
  String get resistanceTitle => 'Resistencia';

  @override
  String get resistanceSource => 'Origen';

  @override
  String get resistanceSourceValue => 'medición de cableado del propio BMS';

  @override
  String get resistanceEstimated => 'Resistencia interna estimada';

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
  String get historyEmptyTitle => 'Todavía no hay nada grabado';

  @override
  String get historyEmptyBody =>
      'Los viajes que grabes quedan guardados con su recorrido, y las curvas de degradación se van dibujando solas con las semanas.';

  @override
  String get historyWhatGoesHere => 'QUÉ VA A APARECER AQUÍ';

  @override
  String get historyItemCapacity =>
      'Capacidad medida por ciclo, y la curva de degradación que dibuja con los meses';

  @override
  String get historyItemTrips => 'Lista de viajes con distancia, Wh y Wh/km';

  @override
  String get historyItemDelta =>
      'Delta graficado contra voltaje de pack, que es donde una celda corta se delata';

  @override
  String get historyItemSag =>
      'Caída de tensión a una corriente dada, y cómo empeora con el tiempo';

  @override
  String get historyItemBalance => 'En qué celdas trabaja más el balanceador';

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
  String get systemSettingsTitle => 'Configuración del BMS (solo lectura)';

  @override
  String get systemNotices => 'Avisos';

  @override
  String get systemRawConsole => 'Consola de frames crudos';

  @override
  String get systemReadOnlyNote =>
      'Esta app nunca escribe configuración al BMS. Todo lo de arriba es solo lectura.';

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
      'Restante dividido por el SOC informado. Si queda muy por debajo de la nominal configurada, el pack ya perdió capacidad o el contador de coulombs está desincronizado.';

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
      'Ah totales que pasaron por el pack divididos por su capacidad nominal. El contador de ciclos del BMS suma cargas parciales, así que casi siempre exagera.';

  @override
  String get healthReportedCycles => 'Ciclos que informa el BMS';

  @override
  String get healthCycleInflation => 'Inflación del contador';

  @override
  String get healthImbalanceLoss => 'Capacidad perdida por desbalance';

  @override
  String get healthImbalanceHint =>
      'El pack se corta cuando la celda más baja llega al límite, no cuando llega el promedio. El delta actual se traduce a los Ah que quedan atrapados en el resto de las celdas.';

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
      'La degradación medida, la vida restante estimada y la evolución de la caída de tensión necesitan meses de lecturas guardadas. Se van llenando solas a medida que uses la moto.';

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
      'Descuenta lo que queda atrapado por la celda más baja: el pack se corta cuando esa celda llega al límite, no cuando llega el promedio.';

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
  String get healthCardCapacity => 'Capacidad real';

  @override
  String get healthCardLoss => 'Pérdida';

  @override
  String get healthCardCycles => 'Ciclos reales';

  @override
  String get healthCardInflation => 'Contador infla';

  @override
  String get healthCardImbalance => 'Desbalance';

  @override
  String get healthCardWeakest => 'Celda que manda';

  @override
  String get healthCardSpread => 'Peor resistencia';

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
  String get tripSag => 'Caída máxima';

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
    return 'Con la moto quieta el delta llega a $delta V. Sin corriente de por medio eso no es resistencia: son celdas que guardan cantidades distintas de carga. Déjala cargar hasta arriba y en reposo unas horas para que el balanceador trabaje; si en varias cargas no se cierra, la celda $cell tiene menos capacidad que el resto.';
  }

  @override
  String get adviceImbalanceUnderLoadTitle =>
      'El delta se abre solo con corriente';

  @override
  String adviceImbalanceUnderLoadBody(String delta, int cell) {
    return 'En reposo las celdas están parejas, pero bajo carga se separan $delta V más. Eso es resistencia, y nueve de cada diez veces es una conexión floja u oxidada, no una celda mala. Revisa el tornillo y la barra de la celda $cell antes de pensar en cambiar nada.';
  }

  @override
  String get adviceWeakCellTitle => 'Siempre es la misma celda';

  @override
  String adviceWeakCellBody(int cell, String percent) {
    return 'La celda $cell fue la más baja en el $percent% de las lecturas. No es ruido: esa celda es la que define tu autonomía real y la que llega primero al corte.';
  }

  @override
  String get adviceCycleInflatedTitle => 'El contador de ciclos exagera';

  @override
  String adviceCycleInflatedBody(String factor) {
    return 'El BMS informa $factor veces más ciclos de los que justifica la carga que realmente pasó por el pack. Suma cargas parciales como si fueran completas. Si vas a comprar o vender un pack, el número honesto es el de ciclos equivalentes.';
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
    return 'Las celdas están desparejas pero el balanceador no trabajó en toda la sesión. O está apagado, o su voltaje de arranque ($voltage V) está por encima de donde llegan tus celdas. Se revisa en los ajustes del BMS con la app oficial: esta app no escribe nada.';
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
    return 'Un $percent% de la energía que el pack todavía guarda queda atrapada arriba del corte, porque la celda más baja llega antes que las demás. Cerrar el delta te devuelve esos kilómetros sin cambiar una sola celda.';
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
  String get tripLearnedTooShort =>
      'Demasiado corto para aprender algo. Hacen falta al menos 500 metros con consumo real.';

  @override
  String get tripLearnedRange => 'Autonomía ahora';

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
    return 'El delta llegó a $delta V bajo carga. Si en reposo las celdas están parejas, eso apunta a una conexión, no a una celda mala.';
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
      'Cuando esté activado, la app busca tu BMS cada medio minuto y se conecta sola en cuanto aparece. Pensado para dejarlo un tiempo mientras calibras una batería nueva, no para siempre: mientras está conectado la app oficial de JK no puede entrar, y buscar consume algo de batería del teléfono.';

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
      'La única medición real de la app. Todo lo demás son cuentas cruzadas sobre lo que el BMS dice de sí mismo; esto cuenta los amperios-hora que salen de verdad entre lleno y corte, y los compara con lo que te vendieron.';

  @override
  String get capacityStart => 'Empezar test';

  @override
  String get capacityAbort => 'Cancelar test';

  @override
  String get capacityRunning => 'midiendo';

  @override
  String get capacityNotFull =>
      'Carga el pack al tope primero. Empezar a media carga solo mediría un pedazo, y el resultado saldría corto.';

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
      'No hace falta que te acuerdes de nada: la app revisa las lecturas guardadas y toma como medición cualquier descarga completa que ya haya ocurrido. El botón es para hacerla a propósito y ver el avance en vivo.';

  @override
  String get capacityAutoTag => 'detectada';

  @override
  String capacityGapWarning(String minutes) {
    return 'Con $minutes min sin conexión, así que la cifra se queda corta.';
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
  String chargeOpensAtTop(int cell) {
    return 'Las celdas iban parejas y se abrieron al final. Ese patrón es capacidad desigual, no una conexión floja: la celda $cell se llena antes que las demás.';
  }

  @override
  String get chargeNone => 'Todavía no se ha grabado ninguna carga';

  @override
  String get trendsTitle => 'Con el tiempo';

  @override
  String get trendsConsumption => 'Consumo por viaje';

  @override
  String get trendsCapacity => 'Capacidad medida';

  @override
  String get trendsSag => 'Caída bajo carga';

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
      'Esta es la distinta: a lo ancho va el nivel de carga, no el tiempo. Cada punto es una lectura, colocada según lo llena que estaba la batería y cuánto se separaban su celda más alta y su más baja en ese momento. Lo que importa es la forma. Plana en el medio con un pico cerca del lleno es una celda con menos capacidad que las demás. Una curva que en cambio sigue a la corriente, más alta con carga, es resistencia en algún punto, y casi siempre una conexión y no una celda.';

  @override
  String get trendsSagHint =>
      'Cuántos miliohmios de resistencia interna implica cada viaje, sacado de cuánto cayó el voltaje para la corriente que se pidió. El más viejo a la izquierda. La resistencia subiendo es lo primero que se degrada en una batería y se nota mucho antes que la pérdida de capacidad, así que una subida aquí es un aviso temprano y no un veredicto. Un salto de golpe casi siempre es una conexión, no las celdas.';

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
      'Lo que dice la etiqueta del pack. Es contra este número que se mide la salud, así que conviene que sea el real.';

  @override
  String get catalogueUnset => 'Sin definir';

  @override
  String get catalogueUnsetHint =>
      'Nadie ha dicho todavía con cuántos amperios-hora se vendió esta batería, y la app no se lo inventa. Hasta que lo pongas, la salud y la degradación no se pueden calcular: no hay contra qué compararlas.';

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
      'Rodando nadie mira la pantalla. Con esto el teléfono avisa aunque esté en el bolsillo.';

  @override
  String get settingsRawFrames => 'Guardar frames crudos';

  @override
  String get settingsRawFramesHint =>
      'Déjalo encendido. Es lo que permite reinterpretar el histórico si aparece que un offset del protocolo estaba mal leído.';

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
  String get exportReadings => 'Lecturas de la última semana (CSV)';

  @override
  String get exportFrames => 'Frames crudos del último día';

  @override
  String get exportTrack => 'Recorrido (GPX)';

  @override
  String exportDone(String path) {
    return 'Guardado en $path';
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
      'La app no está en ninguna tienda, así que se actualiza desde las releases de GitHub. No comprueba nada sola ni descarga nada por su cuenta: lo pides tú.';

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
      'Tomado de la configuración del BMS, que es un número sobre este pack pero lo escribió quien lo armó. Si te lo vendieron con otra capacidad, ponla: la diferencia entre las dos cifras es justo lo que la salud mide.';

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
  String get offlineImpliedUnusable =>
      'Solo se puede leer entre un 25 % y un 90 % de carga.';

  @override
  String get offlineSoh => 'Salud que reporta el BMS';

  @override
  String get offlineCycles => 'Ciclos que cuenta el BMS';

  @override
  String get offlineWeakest => 'Celda más floja';

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
      'No se pudo levantar la conexión Bluetooth con la batería en 25 segundos, y la app lo intentó más de una vez. Comprueba que la batería esté encendida y cerca, y que la app oficial de JK esté cerrada del todo, no solo en segundo plano.';

  @override
  String get connectSilentJk =>
      'Se conectó, pero la batería no dijo nada en 12 segundos. Se anuncia como JK, así que sí es un BMS JK: su única sesión de datos la tiene otro, o se quedó colgada. Lo primero a mirar es la app oficial de JK, que se reconecta sola desde el segundo plano: fuérzala a detenerse en los ajustes de Android, no solo la cierres. Si no hay nadie más, el módulo Bluetooth del BMS suelta la sesión colgada por sí solo al cabo de un rato, y apagar y encender el Bluetooth del teléfono no lo acelera; con el vigilante de proximidad activado la app vuelve a intentarlo sola. La consola de frames crudos en Ajustes muestra si llega algo.';

  @override
  String get connectTalkingUndecoded =>
      'Se conectó y están llegando bytes, pero ninguno se decodifica como un frame JK. Mira la consola de frames crudos en Ajustes: lo que aparezca ahí es lo que hace falta para añadir soporte.';

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
      'Toda la base de datos en un archivo, y de vuelta. Las exportaciones a CSV y GPX son para leer los datos en otro sitio; esto es para no perderlos. Si cambias de teléfono o lo pierdes, es lo único que trae de vuelta meses de lecturas, los viajes con su recorrido y los frames crudos.';

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
  String get chargeAlertsTitle => 'Avisos de carga';

  @override
  String get chargeAlertsIntro =>
      'Se carga de noche y nadie lo mira. Estos avisos existen para eso. Parar antes del tope no es superstición: la parte alta del rango es donde una celda de litio envejece más, así que si mañana no necesitas el pack entero, te conviene quedarte antes.';

  @override
  String get chargeTarget => 'Avisar al llegar a';

  @override
  String get chargeTargetOff => 'Desactivado';

  @override
  String chargeAlertTargetReached(String soc) {
    return 'La batería llegó al $soc %';
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
      'Mientras la app está en segundo plano Android corta la conexión Bluetooth a los pocos minutos. Con esto activado, en cuanto detecta que estás cargando levanta un servicio en primer plano y mantiene la conexión, que es lo que hace falta para que los avisos lleguen de noche. Cuesta batería del teléfono mientras dura.';

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
  String get autoTripTitle => 'Empezar viajes solo';

  @override
  String get autoTripHint =>
      'Abre y cierra el viaje al detectar que estás rodando: hace falta consumo del pack y movimiento del GPS a la vez, sostenidos. Sin esto el aprendizaje depende de que te acuerdes de darle a empezar, y los viajes que se olvidan no son al azar: son los cortos y los que llevabas prisa. Usa GPS mientras rueda.';

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
    return 'Se vendió como $sold Ah y lo mejor que ha dado son $real Ah: alrededor de un $pct % menos de autonomía de la anunciada. Eso no es desgaste, es que nunca fueron $sold.';
  }

  @override
  String get degSoldOk => 'Ha dado lo que se anunció.';

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
  String get etaFull => 'Lleno en';

  @override
  String get etaTapering => 'aprox., ya va bajando la corriente';

  @override
  String get etaDone => 'Está lleno';

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
  String linkReadingAge(String age) {
    return 'Última lectura hace $age';
  }

  @override
  String get linkBack => 'Leyendo otra vez';

  @override
  String get linkDetails => 'Detalles';

  @override
  String get troubleBusy =>
      'Algo más ya está conectado a la batería. El JK BMS acepta una sola conexión Bluetooth a la vez, así que cierra la app oficial de JK o cualquier otro registrador.';

  @override
  String get troubleOutOfRange =>
      'La batería no respondió. O está fuera de alcance o apagada, o algo más tiene tomada su única conexión Bluetooth: la app oficial de JK, u otro registrador.';

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
      'Ese dispositivo no tiene el servicio Bluetooth de JK. No es un BMS JK, o no uno con el que esta app pueda hablar.';

  @override
  String get troublePackMute =>
      'La batería estuvo conectada pero muda: no mandó ni un byte en 20 segundos, pese a pedírselo varias veces. La app soltó la conexión a propósito y vuelve a entrar en unos segundos; es la única forma de que el módulo Bluetooth del BMS suelte la sesión que se le quedó colgada.';

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
      'Android deja de entregarle lecturas Bluetooth a una app poco después de que la pantalla se apaga, a menos que la app mantenga un servicio en primer plano. Esto lo mantiene mientras la batería está conectada, para que la app funcione igual con la pantalla encendida o apagada. Para eso es la notificación; no es la app anunciándose.';

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
    return '$n grabaron distancia pero no energía saliendo de la batería. O fueron en remolque, o la batería reporta su corriente con el signo contrario al que esta app asume.';
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
      'Un punto por viaje grabado, el más viejo a la izquierda. La altura es lo que costó ese viaje por kilómetro. La forma de manejar y el clima lo mueven mucho, así que ignora los puntos suertos y mira si la nube va subiendo con los meses: que la misma ruta cueste más significa que la batería está trabajando más para lograrlo.';

  @override
  String get trendsCapacityHint =>
      'Un punto por descarga completa medida, la más vieja a la izquierda. La altura es los amperios-hora que la batería realmente tenía esa vez. Es la única medida real de desgaste que hay aquí, y la más lenta en llenarse: espera que baje un poco cada año, y desconfía de una caída de golpe.';

  @override
  String get trendsAxisTime =>
      'de izquierda a derecha: del más viejo al más nuevo';

  @override
  String get trendsAxisCharge => 'de izquierda a derecha: de vacía a llena';

  @override
  String learnWhyImplausible(String n) {
    return '$n dieron un consumo que ninguna moto puede producir, así que se rechazaron. Eso es un fallo de esta app y no algo del manejo, y quedó arreglado en esta versión: los viajes grabados de aquí en adelante deberían salir bien. Los viejos no se pueden reparar, porque las lecturas que hacían falta nunca se guardaron.';
  }

  @override
  String get connectCouldNotSearch =>
      'La radio nunca confirmó que la búsqueda empezara, así que en realidad no se buscó nada. Normalmente es el Bluetooth despertando justo al abrir la app. Prueba otra vez.';

  @override
  String get backupShare => 'Enviarla a otro lugar';

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
      'Sale de una capacidad que esta batería midió de verdad.';

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
  String get healthCardShortOfAdvert => 'Frente al anuncio';

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
      'Visor completo en vivo y las últimas 24 horas de historial, gratis. Lo demás (historial ilimitado, degradación, veredictos, avisos con la app cerrada, copia de seguridad) es Pro: un pago único, de por vida, para este teléfono.';

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
      'Lo gratis iguala a la app oficial de JK y no se recorta nunca. Lo Pro es lo que esa app no puede hacer por diseño: recordar, comparar y concluir. Un pago único; nada de suscripciones. Sin cuenta, sin servidor y sin internet: la clave se comprueba en el teléfono con la firma del autor.';

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
  String get proFeatureBackgroundAlerts => 'Los avisos con la app cerrada';

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
      'Es Pro: requiere licencia para mantener la conexión con la app cerrada.';

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
      'Cada frase se apoya en un dato medido: tócala para verlo. Los ciclos y la capacidad configurada del BMS se pueden editar desde la app oficial, así que aquí se contrastan siempre con lo que dice la física.';

  @override
  String get verdictHealthMeasuredTitle =>
      'Capacidad frente a la mejor que ha dado';

  @override
  String verdictHealthMeasuredBody(String pct, String now, String best) {
    return 'Tu batería está al $pct % de la capacidad con la que llegó: $now Ah medidos ahora frente a $best Ah, lo mejor que ha dado. Medido en descargas completas, no estimado.';
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
  String verdictCellDriftingBody(String weeks, String dev, String rate) {
    return 'Lleva $weeks semanas alejándose: va $dev V por debajo de la media del pack y baja unos $rate V al mes. Coherente con una celda en camino de irse. Revísala antes de que el pack se apague en la calle.';
  }

  @override
  String get verdictNoCellDriftingTitle => 'Ninguna celda se está yendo';

  @override
  String verdictNoCellDriftingBody(String weeks, String dev) {
    return 'En $weeks semanas de lecturas en reposo ninguna celda se separa del resto. La peor va $dev V bajo la media y no empeora. Nada que hacer.';
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
    return 'Con corriente el delta llega a $loaded V, contra $rest V en reposo. No hay nada resistivo que perseguir. Nada que hacer.';
  }

  @override
  String get evidenceRestingDelta => 'Delta en reposo (máximo en la sesión)';

  @override
  String get evidenceLoadedDelta => 'Delta bajo carga (máximo en la sesión)';

  @override
  String evidenceWeakCellShare(String cell) {
    return 'Lecturas en que la celda $cell fue la más baja';
  }

  @override
  String get evidenceReadingsInSession => 'Lecturas en esta sesión';

  @override
  String get evidenceReportedCycles => 'Ciclos según el BMS (dato editable)';

  @override
  String get evidenceEquivalentCycles =>
      'Ciclos equivalentes por los amperios que pasaron';

  @override
  String get evidenceReportedSoh => 'SOH según el BMS';

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
  String get evidenceDriftSpanWeeks => 'Semanas observadas';

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
      'Rueda trasera al aire y acelera, o 50 metros en la moto con el teléfono en el bolsillo, o el cargador conectado. Cualquiera sirve: la app mide la corriente.';

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
  String inspectionLoadTooLow(String amps) {
    return 'Muy poca corriente ($amps A). Dale más.';
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
  String get inspectionFidelityNote =>
      'Un test rápido detecta la estafa obvia y la celda mala; no mide capacidad real. Para capacidad real hace falta una descarga completa.';

  @override
  String get inspectionCaveatsTitle => 'Lo que este test no pudo ver';

  @override
  String get inspectionCaveatNoHeavyLoad =>
      'Sin carga fuerte: la caída por celda no se pudo medir.';

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
  String verdictInspCellSaggingBody(String excess) {
    return 'Bajo la carga fuerte cayó $excess V más que la mediana del pack. Coherente con una celda gastada o con una conexión mala en esa celda. Es la razón principal para no pagar el precio pedido sin más pruebas.';
  }

  @override
  String get verdictInspSagUniformTitle => 'Todas las celdas caen parejo';

  @override
  String verdictInspSagUniformBody(String excess) {
    return 'Bajo la carga fuerte la peor celda cayó solo $excess V más que la mediana. Ninguna se rinde antes que las demás.';
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
    return 'Con solo las luces ($amps A) cayó $extra V más que las demás. Una celda que se rinde con uno o dos amperios es una celda muy cansada.';
  }

  @override
  String verdictInspSlowRecoveryTitle(String cell) {
    return 'La celda $cell rebota lento';
  }

  @override
  String verdictInspSlowRecoveryBody(String extra) {
    return 'Tardó $extra s más que la mediana en volver a su voltaje de reposo tras soltar la carga, o no volvió. Las celdas cansadas rebotan lento; es un indicador poco mirado y muy bueno.';
  }

  @override
  String get verdictInspRecoveryOkTitle => 'Recuperación pareja';

  @override
  String verdictInspRecoveryOkBody(String seconds) {
    return 'Tras soltar la carga las celdas volvieron a su reposo en unos $seconds s, todas al mismo paso.';
  }

  @override
  String get verdictInspHotTitle => 'El pack estaba caliente';

  @override
  String verdictInspHotBody(String temp) {
    return 'Llegó a $temp °C durante el test. Un pack caliente en reposo o con poca carga no es normal.';
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
    return 'La corriente máxima vista fue $amps A. Sin un tirón fuerte no se puede medir cuánto cae cada celda, que es donde sale la verdad. Repite con la rueda al aire o 50 metros en la moto.';
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
}
