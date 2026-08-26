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
  String get connectCancelScan => 'Cancelar búsqueda';

  @override
  String get connectScanCancelled => 'Búsqueda cancelada';

  @override
  String get connectNoDevices => 'Todavía no aparece ningún BMS';

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
  String get demoBanner => 'DEMO — pack simulado, sin BMS conectado';

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
  String get waitingCellVoltages => 'los voltajes de celda';

  @override
  String get waitingTemperatures => 'las temperaturas';

  @override
  String get soc => 'Carga';

  @override
  String get range => 'Autonomía';

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
  String get adviceCapacityBelowTitle =>
      'Hay menos capacidad de la que dice la etiqueta';

  @override
  String adviceCapacityBelowBody(String percent) {
    return 'Los propios números del BMS implican un $percent% menos de lo que el pack dice tener. Puede ser degradación real, o que el contador de coulombs esté desincronizado. Un test de capacidad completo lo resuelve sin dudas.';
  }

  @override
  String get adviceNoCapacityTestTitle =>
      'Nunca mediste la capacidad de verdad';

  @override
  String get adviceNoCapacityTestBody =>
      'Es la única forma de saber si te vendieron lo que dice la caja. Carga al tope, conduce hasta que corte, y deja que la app integre los Ah que salieron. Todo lo demás son estimaciones.';

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
      'Si el delta es plano y salta cerca del tope, hay una celda con menos capacidad. Si crece con la corriente, es resistencia: casi siempre una conexión.';

  @override
  String get trendsSagHint =>
      'La misma corriente produciendo una caída mayor con los meses significa que la resistencia interna sube. Se nota mucho antes que la pérdida de capacidad.';

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
}
