import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'JK BMS +'**
  String get appTitle;

  /// No description provided for @connectTitle.
  ///
  /// In es, this message translates to:
  /// **'Conectar'**
  String get connectTitle;

  /// No description provided for @connectOneConnectionWarning.
  ///
  /// In es, this message translates to:
  /// **'El JK BMS acepta una sola conexión Bluetooth a la vez. Cierra la app oficial de JK antes de conectar aquí.'**
  String get connectOneConnectionWarning;

  /// No description provided for @connectScan.
  ///
  /// In es, this message translates to:
  /// **'Buscar BMS'**
  String get connectScan;

  /// No description provided for @connectScanning.
  ///
  /// In es, this message translates to:
  /// **'Buscando'**
  String get connectScanning;

  /// No description provided for @connectScanFinished.
  ///
  /// In es, this message translates to:
  /// **'Búsqueda terminada'**
  String get connectScanFinished;

  /// No description provided for @connectLocationDenied.
  ///
  /// In es, this message translates to:
  /// **'Android no entrega resultados de búsqueda Bluetooth si la app no tiene permiso de ubicación. Es una regla del sistema, no algo que necesite la app para rastrearte: la ubicación solo se usa cuando grabas un viaje. Sin ese permiso la búsqueda termina sin encontrar nada y sin decir por qué.'**
  String get connectLocationDenied;

  /// No description provided for @connectGrantLocation.
  ///
  /// In es, this message translates to:
  /// **'Dar permiso'**
  String get connectGrantLocation;

  /// No description provided for @connectSeenCount.
  ///
  /// In es, this message translates to:
  /// **'{count} dispositivos Bluetooth vistos'**
  String connectSeenCount(String count);

  /// No description provided for @connectNothingFoundHelp.
  ///
  /// In es, this message translates to:
  /// **'No apareció nada. Casi siempre es una de estas:\n\n• La app oficial de JK está conectada al BMS. Mientras lo está, el BMS deja de anunciarse y ningún otro teléfono lo ve. Ciérrala del todo.\n• El pack está dormido. Enciende la moto o muévela para despertarlo.\n• Estás lejos. Acércate al pack.'**
  String get connectNothingFoundHelp;

  /// No description provided for @connectCancelScan.
  ///
  /// In es, this message translates to:
  /// **'Cancelar búsqueda'**
  String get connectCancelScan;

  /// No description provided for @connectNoDevices.
  ///
  /// In es, this message translates to:
  /// **'Todavía no aparece ningún BMS'**
  String get connectNoDevices;

  /// No description provided for @connectLocationOff.
  ///
  /// In es, this message translates to:
  /// **'La ubicación del teléfono está apagada. Android no entrega resultados de búsqueda Bluetooth sin ella, aunque le hayas dado el permiso a la app: devuelve cero dispositivos sin avisar. Enciéndela y vuelve a buscar.'**
  String get connectLocationOff;

  /// No description provided for @connectOtherDevices.
  ///
  /// In es, this message translates to:
  /// **'Otros dispositivos cerca'**
  String get connectOtherDevices;

  /// No description provided for @connectOtherDevicesHint.
  ///
  /// In es, this message translates to:
  /// **'La app no oculta nada. Si tu BMS tiene otro nombre, porque lo cambiaste en la app oficial o porque ese modelo no anuncia el suyo, va a salir en esta lista. Búscalo por la señal más fuerte y pruébalo.'**
  String get connectOtherDevicesHint;

  /// No description provided for @connectLikelyBms.
  ///
  /// In es, this message translates to:
  /// **'probable BMS'**
  String get connectLikelyBms;

  /// No description provided for @connectByService.
  ///
  /// In es, this message translates to:
  /// **'anuncia el servicio JK'**
  String get connectByService;

  /// No description provided for @connectNoBle.
  ///
  /// In es, this message translates to:
  /// **'Este teléfono no tiene Bluetooth LE.'**
  String get connectNoBle;

  /// No description provided for @connectBluetoothOff.
  ///
  /// In es, this message translates to:
  /// **'El Bluetooth está apagado. Enciéndelo y vuelve a buscar.'**
  String get connectBluetoothOff;

  /// No description provided for @connectDemoButton.
  ///
  /// In es, this message translates to:
  /// **'Abrir modo demo'**
  String get connectDemoButton;

  /// No description provided for @connectDemoHint.
  ///
  /// In es, this message translates to:
  /// **'El modo demo corre un pack 20S simulado a través del parser real, para ver todas las pantallas sin ningún BMS cerca.'**
  String get connectDemoHint;

  /// No description provided for @tabNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get tabNow;

  /// No description provided for @tabCells.
  ///
  /// In es, this message translates to:
  /// **'Celdas'**
  String get tabCells;

  /// No description provided for @tabThermal.
  ///
  /// In es, this message translates to:
  /// **'Térmico'**
  String get tabThermal;

  /// No description provided for @tabHistory.
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get tabHistory;

  /// No description provided for @tabSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get tabSystem;

  /// No description provided for @demoBanner.
  ///
  /// In es, this message translates to:
  /// **'DEMO: pack simulado, sin BMS conectado'**
  String get demoBanner;

  /// No description provided for @demoTitle.
  ///
  /// In es, this message translates to:
  /// **'Modo demo'**
  String get demoTitle;

  /// No description provided for @demoExplanation.
  ///
  /// In es, this message translates to:
  /// **'Un pack 20S simulado genera frames reales de 300 bytes. Pasan por el mismo checksum, ensamblado y parser que usará el hardware, así que estas pantallas están cableadas exactamente como estarán en la moto. Los valores en sí son modelados, no medidos.'**
  String get demoExplanation;

  /// No description provided for @demoScenarioRiding.
  ///
  /// In es, this message translates to:
  /// **'Rodando'**
  String get demoScenarioRiding;

  /// No description provided for @demoScenarioRidingDesc.
  ///
  /// In es, this message translates to:
  /// **'Acelerador variable, caída de tensión bajo carga, SOC bajando'**
  String get demoScenarioRidingDesc;

  /// No description provided for @demoScenarioCharging.
  ///
  /// In es, this message translates to:
  /// **'Cargando'**
  String get demoScenarioCharging;

  /// No description provided for @demoScenarioChargingDesc.
  ///
  /// In es, this message translates to:
  /// **'Carga estable, el delta se abre cerca del tope'**
  String get demoScenarioChargingDesc;

  /// No description provided for @demoScenarioIdle.
  ///
  /// In es, this message translates to:
  /// **'Detenida'**
  String get demoScenarioIdle;

  /// No description provided for @demoScenarioIdleDesc.
  ///
  /// In es, this message translates to:
  /// **'Sin corriente, celdas relajadas'**
  String get demoScenarioIdleDesc;

  /// No description provided for @demoScenarioWeakCell.
  ///
  /// In es, this message translates to:
  /// **'Celda débil'**
  String get demoScenarioWeakCell;

  /// No description provided for @demoScenarioWeakCellDesc.
  ///
  /// In es, this message translates to:
  /// **'La celda 7 cae fuerte, balanceador activo, alarmas encendidas'**
  String get demoScenarioWeakCellDesc;

  /// No description provided for @demoPackName.
  ///
  /// In es, this message translates to:
  /// **'Pack demo'**
  String get demoPackName;

  /// No description provided for @healthGood.
  ///
  /// In es, this message translates to:
  /// **'Todo en orden'**
  String get healthGood;

  /// No description provided for @healthWatch.
  ///
  /// In es, this message translates to:
  /// **'Vigilar'**
  String get healthWatch;

  /// No description provided for @healthBad.
  ///
  /// In es, this message translates to:
  /// **'Problema'**
  String get healthBad;

  /// No description provided for @waitingFor.
  ///
  /// In es, this message translates to:
  /// **'Esperando {what}'**
  String waitingFor(String what);

  /// No description provided for @waitingFirstReading.
  ///
  /// In es, this message translates to:
  /// **'la primera lectura'**
  String get waitingFirstReading;

  /// No description provided for @waitingCellVoltages.
  ///
  /// In es, this message translates to:
  /// **'los voltajes de celda'**
  String get waitingCellVoltages;

  /// No description provided for @waitingTemperatures.
  ///
  /// In es, this message translates to:
  /// **'las temperaturas'**
  String get waitingTemperatures;

  /// No description provided for @soc.
  ///
  /// In es, this message translates to:
  /// **'Carga'**
  String get soc;

  /// No description provided for @range.
  ///
  /// In es, this message translates to:
  /// **'Autonomía'**
  String get range;

  /// No description provided for @rangeDisclaimer.
  ///
  /// In es, this message translates to:
  /// **'Estimación aproximada desde la energía restante. El valor real sale del Wh/km medido con GPS.'**
  String get rangeDisclaimer;

  /// No description provided for @power.
  ///
  /// In es, this message translates to:
  /// **'Potencia'**
  String get power;

  /// No description provided for @current.
  ///
  /// In es, this message translates to:
  /// **'Corriente'**
  String get current;

  /// No description provided for @packVoltage.
  ///
  /// In es, this message translates to:
  /// **'Pack'**
  String get packVoltage;

  /// No description provided for @cellDelta.
  ///
  /// In es, this message translates to:
  /// **'Delta'**
  String get cellDelta;

  /// No description provided for @average.
  ///
  /// In es, this message translates to:
  /// **'Promedio'**
  String get average;

  /// No description provided for @charging.
  ///
  /// In es, this message translates to:
  /// **'cargando'**
  String get charging;

  /// No description provided for @discharging.
  ///
  /// In es, this message translates to:
  /// **'descargando'**
  String get discharging;

  /// No description provided for @resting.
  ///
  /// In es, this message translates to:
  /// **'en reposo'**
  String get resting;

  /// No description provided for @sessionTitle.
  ///
  /// In es, this message translates to:
  /// **'Esta sesión'**
  String get sessionTitle;

  /// No description provided for @sessionEnergy.
  ///
  /// In es, this message translates to:
  /// **'Energía por el pack'**
  String get sessionEnergy;

  /// No description provided for @sessionDistance.
  ///
  /// In es, this message translates to:
  /// **'Distancia'**
  String get sessionDistance;

  /// No description provided for @sessionWhPerKm.
  ///
  /// In es, this message translates to:
  /// **'Wh por km'**
  String get sessionWhPerKm;

  /// No description provided for @sessionSamples.
  ///
  /// In es, this message translates to:
  /// **'Muestras en memoria'**
  String get sessionSamples;

  /// No description provided for @needsGps.
  ///
  /// In es, this message translates to:
  /// **'necesita un viaje activo'**
  String get needsGps;

  /// No description provided for @needsDatabase.
  ///
  /// In es, this message translates to:
  /// **'necesita más histórico'**
  String get needsDatabase;

  /// No description provided for @needsSteps.
  ///
  /// In es, this message translates to:
  /// **'necesita escalones de corriente'**
  String get needsSteps;

  /// No description provided for @packTitle.
  ///
  /// In es, this message translates to:
  /// **'Pack'**
  String get packTitle;

  /// No description provided for @packRemaining.
  ///
  /// In es, this message translates to:
  /// **'Restante'**
  String get packRemaining;

  /// No description provided for @packRemainingValue.
  ///
  /// In es, this message translates to:
  /// **'{remaining} de {nominal} Ah'**
  String packRemainingValue(String remaining, String nominal);

  /// No description provided for @packCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos'**
  String get packCycles;

  /// No description provided for @packSoh.
  ///
  /// In es, this message translates to:
  /// **'Salud'**
  String get packSoh;

  /// No description provided for @packSag.
  ///
  /// In es, this message translates to:
  /// **'Caída bajo carga'**
  String get packSag;

  /// No description provided for @packSagNoBaseline.
  ///
  /// In es, this message translates to:
  /// **'sin lectura en reposo aún'**
  String get packSagNoBaseline;

  /// No description provided for @packMosfets.
  ///
  /// In es, this message translates to:
  /// **'MOSFETs'**
  String get packMosfets;

  /// No description provided for @mosfetChargeOn.
  ///
  /// In es, this message translates to:
  /// **'carga on'**
  String get mosfetChargeOn;

  /// No description provided for @mosfetChargeOff.
  ///
  /// In es, this message translates to:
  /// **'carga off'**
  String get mosfetChargeOff;

  /// No description provided for @mosfetDischargeOn.
  ///
  /// In es, this message translates to:
  /// **'descarga on'**
  String get mosfetDischargeOn;

  /// No description provided for @mosfetDischargeOff.
  ///
  /// In es, this message translates to:
  /// **'descarga off'**
  String get mosfetDischargeOff;

  /// No description provided for @cellsLowest.
  ///
  /// In es, this message translates to:
  /// **'Más baja: celda {index} con {voltage} V'**
  String cellsLowest(int index, String voltage);

  /// No description provided for @cellsHighest.
  ///
  /// In es, this message translates to:
  /// **'Más alta: celda {index} con {voltage} V'**
  String cellsHighest(int index, String voltage);

  /// No description provided for @cellsSpreadTitle.
  ///
  /// In es, this message translates to:
  /// **'Dispersión'**
  String get cellsSpreadTitle;

  /// No description provided for @cellsDeviationHint.
  ///
  /// In es, this message translates to:
  /// **'Las barras muestran la desviación respecto del promedio, no el voltaje absoluto: a 3,9 V nominales veinte barras llenas idénticas no dirían nada.'**
  String get cellsDeviationHint;

  /// No description provided for @balancingTitle.
  ///
  /// In es, this message translates to:
  /// **'Balanceo'**
  String get balancingTitle;

  /// No description provided for @balancerState.
  ///
  /// In es, this message translates to:
  /// **'Balanceador'**
  String get balancerState;

  /// No description provided for @balancerBadge.
  ///
  /// In es, this message translates to:
  /// **'Balanceando'**
  String get balancerBadge;

  /// No description provided for @balancerWorking.
  ///
  /// In es, this message translates to:
  /// **'trabajando'**
  String get balancerWorking;

  /// No description provided for @balancerIdle.
  ///
  /// In es, this message translates to:
  /// **'en reposo'**
  String get balancerIdle;

  /// No description provided for @balanceCurrent.
  ///
  /// In es, this message translates to:
  /// **'Corriente de balanceo'**
  String get balanceCurrent;

  /// No description provided for @balanceDirection.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get balanceDirection;

  /// No description provided for @balanceDirectionCharge.
  ///
  /// In es, this message translates to:
  /// **'moviendo carga hacia las celdas bajas'**
  String get balanceDirectionCharge;

  /// No description provided for @balanceDirectionDischarge.
  ///
  /// In es, this message translates to:
  /// **'drenando las celdas altas'**
  String get balanceDirectionDischarge;

  /// No description provided for @balanceDirectionOff.
  ///
  /// In es, this message translates to:
  /// **'sin actividad'**
  String get balanceDirectionOff;

  /// No description provided for @balanceActiveNote.
  ///
  /// In es, this message translates to:
  /// **'Este BMS es un balanceador activo: mueve carga entre celdas en vez de quemarla en resistencias, así que puede trabajar con corrientes mucho mayores que un balanceador pasivo.'**
  String get balanceActiveNote;

  /// No description provided for @balanceWhichCells.
  ///
  /// In es, this message translates to:
  /// **'Qué celdas'**
  String get balanceWhichCells;

  /// No description provided for @balanceWhichCellsValue.
  ///
  /// In es, this message translates to:
  /// **'deducido, el BMS no lo informa'**
  String get balanceWhichCellsValue;

  /// No description provided for @balanceRanking.
  ///
  /// In es, this message translates to:
  /// **'Ranking de celda débil'**
  String get balanceRanking;

  /// No description provided for @resistanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Resistencia'**
  String get resistanceTitle;

  /// No description provided for @resistanceSource.
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get resistanceSource;

  /// No description provided for @resistanceSourceValue.
  ///
  /// In es, this message translates to:
  /// **'medición de cableado del propio BMS'**
  String get resistanceSourceValue;

  /// No description provided for @resistanceEstimated.
  ///
  /// In es, this message translates to:
  /// **'Resistencia interna estimada'**
  String get resistanceEstimated;

  /// No description provided for @resistanceWireWarnings.
  ///
  /// In es, this message translates to:
  /// **'Alarmas de resistencia de cable'**
  String get resistanceWireWarnings;

  /// No description provided for @none.
  ///
  /// In es, this message translates to:
  /// **'ninguna'**
  String get none;

  /// No description provided for @thermalProbe.
  ///
  /// In es, this message translates to:
  /// **'Sonda {index}'**
  String thermalProbe(int index);

  /// No description provided for @thermalMosfet.
  ///
  /// In es, this message translates to:
  /// **'MOSFET'**
  String get thermalMosfet;

  /// No description provided for @thermalLastMinutes.
  ///
  /// In es, this message translates to:
  /// **'Últimos {minutes} minutos'**
  String thermalLastMinutes(int minutes);

  /// No description provided for @thermalSamples.
  ///
  /// In es, this message translates to:
  /// **'{count} muestras'**
  String thermalSamples(int count);

  /// No description provided for @thermalCollecting.
  ///
  /// In es, this message translates to:
  /// **'Juntando muestras'**
  String get thermalCollecting;

  /// No description provided for @thermalLegendHottest.
  ///
  /// In es, this message translates to:
  /// **'Sonda más caliente'**
  String get thermalLegendHottest;

  /// No description provided for @thermalLegendCurrent.
  ///
  /// In es, this message translates to:
  /// **'Corriente (|A|)'**
  String get thermalLegendCurrent;

  /// No description provided for @thermalSensorsTitle.
  ///
  /// In es, this message translates to:
  /// **'Sensores'**
  String get thermalSensorsTitle;

  /// No description provided for @thermalProbesReported.
  ///
  /// In es, this message translates to:
  /// **'Sondas informadas'**
  String get thermalProbesReported;

  /// No description provided for @thermalMosfetSensor.
  ///
  /// In es, this message translates to:
  /// **'Sensor de MOSFET'**
  String get thermalMosfetSensor;

  /// No description provided for @reported.
  ///
  /// In es, this message translates to:
  /// **'informado'**
  String get reported;

  /// No description provided for @notReported.
  ///
  /// In es, this message translates to:
  /// **'no informado'**
  String get notReported;

  /// No description provided for @thermalSensorMask.
  ///
  /// In es, this message translates to:
  /// **'Máscara de sensores'**
  String get thermalSensorMask;

  /// No description provided for @thermalHeater.
  ///
  /// In es, this message translates to:
  /// **'Calefactor'**
  String get thermalHeater;

  /// No description provided for @thermalHeaterCurrent.
  ///
  /// In es, this message translates to:
  /// **'Corriente del calefactor'**
  String get thermalHeaterCurrent;

  /// No description provided for @on.
  ///
  /// In es, this message translates to:
  /// **'on'**
  String get on;

  /// No description provided for @off.
  ///
  /// In es, this message translates to:
  /// **'off'**
  String get off;

  /// No description provided for @thermalMaskNote.
  ///
  /// In es, this message translates to:
  /// **'La máscara se muestra cruda y no se oculta ninguna lectura por su causa. La implementación de referencia la llama máscara de sensores «ausentes», pero las capturas reales encienden bits de sondas que claramente funcionan. Ver docs/PROTOCOL.md.'**
  String get thermalMaskNote;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay nada grabado'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Los viajes que grabes quedan guardados con su recorrido, y las curvas de degradación se van dibujando solas con las semanas.'**
  String get historyEmptyBody;

  /// No description provided for @historyWhatGoesHere.
  ///
  /// In es, this message translates to:
  /// **'QUÉ VA A APARECER AQUÍ'**
  String get historyWhatGoesHere;

  /// No description provided for @historyItemCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad medida por ciclo, y la curva de degradación que dibuja con los meses'**
  String get historyItemCapacity;

  /// No description provided for @historyItemTrips.
  ///
  /// In es, this message translates to:
  /// **'Lista de viajes con distancia, Wh y Wh/km'**
  String get historyItemTrips;

  /// No description provided for @historyItemDelta.
  ///
  /// In es, this message translates to:
  /// **'Delta graficado contra voltaje de pack, que es donde una celda corta se delata'**
  String get historyItemDelta;

  /// No description provided for @historyItemSag.
  ///
  /// In es, this message translates to:
  /// **'Caída de tensión a una corriente dada, y cómo empeora con el tiempo'**
  String get historyItemSag;

  /// No description provided for @historyItemBalance.
  ///
  /// In es, this message translates to:
  /// **'En qué celdas trabaja más el balanceador'**
  String get historyItemBalance;

  /// No description provided for @systemDeviceTitle.
  ///
  /// In es, this message translates to:
  /// **'Equipo'**
  String get systemDeviceTitle;

  /// No description provided for @systemModel.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get systemModel;

  /// No description provided for @systemHardware.
  ///
  /// In es, this message translates to:
  /// **'Hardware'**
  String get systemHardware;

  /// No description provided for @systemSoftware.
  ///
  /// In es, this message translates to:
  /// **'Firmware'**
  String get systemSoftware;

  /// No description provided for @systemSerial.
  ///
  /// In es, this message translates to:
  /// **'Número de serie'**
  String get systemSerial;

  /// No description provided for @systemManufactured.
  ///
  /// In es, this message translates to:
  /// **'Fabricado'**
  String get systemManufactured;

  /// No description provided for @systemPowerOnCount.
  ///
  /// In es, this message translates to:
  /// **'Encendidos'**
  String get systemPowerOnCount;

  /// No description provided for @systemUptime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo encendido'**
  String get systemUptime;

  /// No description provided for @systemDeviceInfoMissing.
  ///
  /// In es, this message translates to:
  /// **'todavía no llegó'**
  String get systemDeviceInfoMissing;

  /// No description provided for @systemVariantTitle.
  ///
  /// In es, this message translates to:
  /// **'Variante de protocolo'**
  String get systemVariantTitle;

  /// No description provided for @systemVariantInUse.
  ///
  /// In es, this message translates to:
  /// **'En uso'**
  String get systemVariantInUse;

  /// No description provided for @systemVariantUndecided.
  ///
  /// In es, this message translates to:
  /// **'sin decidir'**
  String get systemVariantUndecided;

  /// No description provided for @systemVariantAuto.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get systemVariantAuto;

  /// No description provided for @systemVariantWarning.
  ///
  /// In es, this message translates to:
  /// **'Cambia esto si los valores decodificados se ven mal. Elegir la variante equivocada no falla de forma ruidosa: decodifica en los offsets incorrectos y produce números creíbles pero falsos.'**
  String get systemVariantWarning;

  /// No description provided for @systemConnectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Conexión'**
  String get systemConnectionTitle;

  /// No description provided for @systemMtu.
  ///
  /// In es, this message translates to:
  /// **'MTU'**
  String get systemMtu;

  /// No description provided for @systemMtuValue.
  ///
  /// In es, this message translates to:
  /// **'{bytes} bytes'**
  String systemMtuValue(int bytes);

  /// No description provided for @unknown.
  ///
  /// In es, this message translates to:
  /// **'desconocido'**
  String get unknown;

  /// No description provided for @systemFramesOk.
  ///
  /// In es, this message translates to:
  /// **'Frames aceptados'**
  String get systemFramesOk;

  /// No description provided for @systemFramesBadChecksum.
  ///
  /// In es, this message translates to:
  /// **'Checksum inválido'**
  String get systemFramesBadChecksum;

  /// No description provided for @systemFramesUnsupported.
  ///
  /// In es, this message translates to:
  /// **'Tipo no soportado'**
  String get systemFramesUnsupported;

  /// No description provided for @systemAcceptRate.
  ///
  /// In es, this message translates to:
  /// **'Tasa de aceptación'**
  String get systemAcceptRate;

  /// No description provided for @systemBytesReceived.
  ///
  /// In es, this message translates to:
  /// **'Bytes recibidos'**
  String get systemBytesReceived;

  /// No description provided for @systemSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración del BMS (solo lectura)'**
  String get systemSettingsTitle;

  /// No description provided for @systemNotices.
  ///
  /// In es, this message translates to:
  /// **'Avisos'**
  String get systemNotices;

  /// No description provided for @systemRawConsole.
  ///
  /// In es, this message translates to:
  /// **'Consola de frames crudos'**
  String get systemRawConsole;

  /// No description provided for @systemReadOnlyNote.
  ///
  /// In es, this message translates to:
  /// **'Esta app nunca escribe configuración al BMS. Todo lo de arriba es solo lectura.'**
  String get systemReadOnlyNote;

  /// No description provided for @systemLanguageTitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get systemLanguageTitle;

  /// No description provided for @systemLanguageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get systemLanguageSpanish;

  /// No description provided for @systemLanguageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get systemLanguageEnglish;

  /// No description provided for @systemLanguageSystem.
  ///
  /// In es, this message translates to:
  /// **'Del sistema'**
  String get systemLanguageSystem;

  /// No description provided for @settingCellCount.
  ///
  /// In es, this message translates to:
  /// **'Cantidad de celdas'**
  String get settingCellCount;

  /// No description provided for @settingNominalCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad nominal'**
  String get settingNominalCapacity;

  /// No description provided for @settingCellOvp.
  ///
  /// In es, this message translates to:
  /// **'Sobretensión de celda'**
  String get settingCellOvp;

  /// No description provided for @settingCellOvpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de sobretensión'**
  String get settingCellOvpRecovery;

  /// No description provided for @settingCellUvp.
  ///
  /// In es, this message translates to:
  /// **'Subtensión de celda'**
  String get settingCellUvp;

  /// No description provided for @settingCellUvpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de subtensión'**
  String get settingCellUvpRecovery;

  /// No description provided for @settingPowerOff.
  ///
  /// In es, this message translates to:
  /// **'Voltaje de corte'**
  String get settingPowerOff;

  /// No description provided for @settingMaxCharge.
  ///
  /// In es, this message translates to:
  /// **'Corriente máx. de carga'**
  String get settingMaxCharge;

  /// No description provided for @settingMaxDischarge.
  ///
  /// In es, this message translates to:
  /// **'Corriente máx. de descarga'**
  String get settingMaxDischarge;

  /// No description provided for @settingMaxBalance.
  ///
  /// In es, this message translates to:
  /// **'Corriente máx. de balanceo'**
  String get settingMaxBalance;

  /// No description provided for @settingBalanceStart.
  ///
  /// In es, this message translates to:
  /// **'Voltaje de inicio de balanceo'**
  String get settingBalanceStart;

  /// No description provided for @settingBalanceTrigger.
  ///
  /// In es, this message translates to:
  /// **'Delta que dispara el balanceo'**
  String get settingBalanceTrigger;

  /// No description provided for @settingChargeOtp.
  ///
  /// In es, this message translates to:
  /// **'Sobretemperatura en carga'**
  String get settingChargeOtp;

  /// No description provided for @settingDischargeOtp.
  ///
  /// In es, this message translates to:
  /// **'Sobretemperatura en descarga'**
  String get settingDischargeOtp;

  /// No description provided for @settingChargeUtp.
  ///
  /// In es, this message translates to:
  /// **'Subtemperatura en carga'**
  String get settingChargeUtp;

  /// No description provided for @settingMosfetOtp.
  ///
  /// In es, this message translates to:
  /// **'Sobretemperatura de MOSFET'**
  String get settingMosfetOtp;

  /// No description provided for @settingSwitches.
  ///
  /// In es, this message translates to:
  /// **'Interruptores'**
  String get settingSwitches;

  /// No description provided for @consoleTitle.
  ///
  /// In es, this message translates to:
  /// **'Frames crudos'**
  String get consoleTitle;

  /// No description provided for @consoleFollow.
  ///
  /// In es, this message translates to:
  /// **'Siguiendo'**
  String get consoleFollow;

  /// No description provided for @consolePaused.
  ///
  /// In es, this message translates to:
  /// **'Pausado'**
  String get consolePaused;

  /// No description provided for @consoleCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar registro'**
  String get consoleCopy;

  /// No description provided for @consoleCopied.
  ///
  /// In es, this message translates to:
  /// **'Registro copiado'**
  String get consoleCopied;

  /// No description provided for @tabHealth.
  ///
  /// In es, this message translates to:
  /// **'Salud'**
  String get tabHealth;

  /// No description provided for @healthTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que el fabricante no te muestra'**
  String get healthTitle;

  /// No description provided for @healthIntro.
  ///
  /// In es, this message translates to:
  /// **'Estos números salen de lo que el BMS ya informa, cruzados entre sí. Ninguno es un dato que el fabricante publique.'**
  String get healthIntro;

  /// No description provided for @healthRealCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad real implícita'**
  String get healthRealCapacity;

  /// No description provided for @healthRealCapacityHint.
  ///
  /// In es, this message translates to:
  /// **'Restante dividido por el SOC informado. Si queda muy por debajo de la nominal configurada, el pack ya perdió capacidad o el contador de coulombs está desincronizado.'**
  String get healthRealCapacityHint;

  /// No description provided for @healthClaimedCapacity.
  ///
  /// In es, this message translates to:
  /// **'Nominal configurada en el BMS'**
  String get healthClaimedCapacity;

  /// No description provided for @healthSpecCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad de catálogo'**
  String get healthSpecCapacity;

  /// No description provided for @healthCapacityLoss.
  ///
  /// In es, this message translates to:
  /// **'Pérdida frente a catálogo'**
  String get healthCapacityLoss;

  /// No description provided for @healthEquivalentCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos completos equivalentes'**
  String get healthEquivalentCycles;

  /// No description provided for @healthEquivalentCyclesHint.
  ///
  /// In es, this message translates to:
  /// **'Ah totales que pasaron por el pack divididos por su capacidad nominal. El contador de ciclos del BMS suma cargas parciales, así que casi siempre exagera.'**
  String get healthEquivalentCyclesHint;

  /// No description provided for @healthReportedCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos que informa el BMS'**
  String get healthReportedCycles;

  /// No description provided for @healthCycleInflation.
  ///
  /// In es, this message translates to:
  /// **'Inflación del contador'**
  String get healthCycleInflation;

  /// No description provided for @healthImbalanceLoss.
  ///
  /// In es, this message translates to:
  /// **'Capacidad perdida por desbalance'**
  String get healthImbalanceLoss;

  /// No description provided for @healthImbalanceHint.
  ///
  /// In es, this message translates to:
  /// **'El pack se corta cuando la celda más baja llega al límite, no cuando llega el promedio. El delta actual se traduce a los Ah que quedan atrapados en el resto de las celdas.'**
  String get healthImbalanceHint;

  /// No description provided for @healthWeakestCell.
  ///
  /// In es, this message translates to:
  /// **'Celda que manda'**
  String get healthWeakestCell;

  /// No description provided for @healthWeakestCellValue.
  ///
  /// In es, this message translates to:
  /// **'celda {index}'**
  String healthWeakestCellValue(int index);

  /// No description provided for @healthWeakestCellHint.
  ///
  /// In es, this message translates to:
  /// **'El pack vale lo que vale su peor celda. Es la que llega primero al corte y la que define la autonomía real.'**
  String get healthWeakestCellHint;

  /// No description provided for @healthResistanceSpread.
  ///
  /// In es, this message translates to:
  /// **'Dispersión de resistencia'**
  String get healthResistanceSpread;

  /// No description provided for @healthResistanceSpreadValue.
  ///
  /// In es, this message translates to:
  /// **'la peor está {percent}% por encima de la mediana'**
  String healthResistanceSpreadValue(String percent);

  /// No description provided for @healthSohReported.
  ///
  /// In es, this message translates to:
  /// **'Salud que informa el BMS'**
  String get healthSohReported;

  /// No description provided for @healthSohSuspect.
  ///
  /// In es, this message translates to:
  /// **'Muchos firmwares dejan este número fijo y no lo recalculan nunca. Tratalo como decorativo hasta que lo veas moverse.'**
  String get healthSohSuspect;

  /// No description provided for @healthNeedsHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Necesita histórico'**
  String get healthNeedsHistoryTitle;

  /// No description provided for @healthNeedsHistoryBody.
  ///
  /// In es, this message translates to:
  /// **'La degradación medida, la vida restante estimada y la evolución de la caída de tensión necesitan meses de lecturas guardadas. Se van llenando solas a medida que uses la moto.'**
  String get healthNeedsHistoryBody;

  /// No description provided for @healthNotEnoughData.
  ///
  /// In es, this message translates to:
  /// **'sin datos suficientes'**
  String get healthNotEnoughData;

  /// No description provided for @healthCapacityUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Con el SOC muy bajo o muy alto este cálculo se vuelve ruido, así que no se muestra.'**
  String get healthCapacityUnavailable;

  /// No description provided for @rangeLearning.
  ///
  /// In es, this message translates to:
  /// **'aprendiendo'**
  String get rangeLearning;

  /// No description provided for @rangeEstimatorTitle.
  ///
  /// In es, this message translates to:
  /// **'Autonomía adaptativa'**
  String get rangeEstimatorTitle;

  /// No description provided for @rangeEstimatorIntro.
  ///
  /// In es, this message translates to:
  /// **'La app mide los Wh que realmente salen del pack y los divide por los kilómetros del GPS del teléfono. Cada viaje corrige la estimación, así que el número se ajusta a cómo conduces tú, en tu terreno, con tu carga.'**
  String get rangeEstimatorIntro;

  /// No description provided for @rangeConsumption.
  ///
  /// In es, this message translates to:
  /// **'Consumo aprendido'**
  String get rangeConsumption;

  /// No description provided for @rangeConsumptionDefault.
  ///
  /// In es, this message translates to:
  /// **'valor inicial por defecto'**
  String get rangeConsumptionDefault;

  /// No description provided for @rangeSamples.
  ///
  /// In es, this message translates to:
  /// **'Kilómetros aprendidos'**
  String get rangeSamples;

  /// No description provided for @rangeConfidence.
  ///
  /// In es, this message translates to:
  /// **'Confianza'**
  String get rangeConfidence;

  /// No description provided for @rangeConfidenceLow.
  ///
  /// In es, this message translates to:
  /// **'baja'**
  String get rangeConfidenceLow;

  /// No description provided for @rangeConfidenceMedium.
  ///
  /// In es, this message translates to:
  /// **'media'**
  String get rangeConfidenceMedium;

  /// No description provided for @rangeConfidenceHigh.
  ///
  /// In es, this message translates to:
  /// **'alta'**
  String get rangeConfidenceHigh;

  /// No description provided for @rangeBand.
  ///
  /// In es, this message translates to:
  /// **'entre {low} y {high} km'**
  String rangeBand(String low, String high);

  /// No description provided for @rangeUsableEnergy.
  ///
  /// In es, this message translates to:
  /// **'Energía utilizable'**
  String get rangeUsableEnergy;

  /// No description provided for @rangeUsableHint.
  ///
  /// In es, this message translates to:
  /// **'Descuenta lo que queda atrapado por la celda más baja: el pack se corta cuando esa celda llega al límite, no cuando llega el promedio.'**
  String get rangeUsableHint;

  /// No description provided for @rangeNeedsGps.
  ///
  /// In es, this message translates to:
  /// **'La distancia sale del GPS del teléfono durante un viaje. El BMS no informa posición: el protocolo tiene bits de bloqueo por GPS, pero ningún campo de coordenadas.'**
  String get rangeNeedsGps;

  /// No description provided for @rangeDemoNote.
  ///
  /// In es, this message translates to:
  /// **'En modo demo la distancia también es simulada, para que se pueda ver cómo se comporta el estimador.'**
  String get rangeDemoNote;

  /// No description provided for @systemPasscode.
  ///
  /// In es, this message translates to:
  /// **'Contraseña que entrega el BMS'**
  String get systemPasscode;

  /// No description provided for @systemPasscodeHint.
  ///
  /// In es, this message translates to:
  /// **'El BMS incluye su propia contraseña, en texto plano, dentro del frame de información de equipo. Cualquier cliente Bluetooth que se conecte puede leerla: no hay autenticación en ninguna parte de este protocolo. Esta app solo lee, pero conviene saberlo.'**
  String get systemPasscodeHint;

  /// No description provided for @systemPasscodeEmpty.
  ///
  /// In es, this message translates to:
  /// **'no la informa'**
  String get systemPasscodeEmpty;

  /// No description provided for @linkIdle.
  ///
  /// In es, this message translates to:
  /// **'en espera'**
  String get linkIdle;

  /// No description provided for @linkScanning.
  ///
  /// In es, this message translates to:
  /// **'buscando'**
  String get linkScanning;

  /// No description provided for @linkConnecting.
  ///
  /// In es, this message translates to:
  /// **'conectando'**
  String get linkConnecting;

  /// No description provided for @linkNegotiating.
  ///
  /// In es, this message translates to:
  /// **'negociando'**
  String get linkNegotiating;

  /// No description provided for @linkConnected.
  ///
  /// In es, this message translates to:
  /// **'conectado'**
  String get linkConnected;

  /// No description provided for @linkReconnecting.
  ///
  /// In es, this message translates to:
  /// **'reconectando'**
  String get linkReconnecting;

  /// No description provided for @linkFailed.
  ///
  /// In es, this message translates to:
  /// **'falló'**
  String get linkFailed;

  /// No description provided for @variantReasonUnreadable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer una versión mayor de «{version}» en el modelo {model}.'**
  String variantReasonUnreadable(String version, String model);

  /// No description provided for @variantReasonModern.
  ///
  /// In es, this message translates to:
  /// **'Firmware {version} (mayor {major} ≥ 11).'**
  String variantReasonModern(String version, int major);

  /// No description provided for @variantReasonLegacy.
  ///
  /// In es, this message translates to:
  /// **'Firmware {version} (mayor {major} < 11) implica JK02_24S, pero la familia de balanceadores JK04 también informa versiones por debajo de 11. Confirma que los valores decodificados tengan sentido antes de confiar en ellos.'**
  String variantReasonLegacy(String version, int major);

  /// No description provided for @healthGaugeLabel.
  ///
  /// In es, this message translates to:
  /// **'Salud'**
  String get healthGaugeLabel;

  /// No description provided for @healthGaugeMeasured.
  ///
  /// In es, this message translates to:
  /// **'medida'**
  String get healthGaugeMeasured;

  /// No description provided for @healthGaugeReported.
  ///
  /// In es, this message translates to:
  /// **'la informa el BMS'**
  String get healthGaugeReported;

  /// No description provided for @healthVerdictGood.
  ///
  /// In es, this message translates to:
  /// **'El pack está como debería'**
  String get healthVerdictGood;

  /// No description provided for @healthVerdictWatch.
  ///
  /// In es, this message translates to:
  /// **'El pack perdió algo de capacidad'**
  String get healthVerdictWatch;

  /// No description provided for @healthVerdictBad.
  ///
  /// In es, this message translates to:
  /// **'El pack está bastante gastado'**
  String get healthVerdictBad;

  /// No description provided for @healthHowCalculated.
  ///
  /// In es, this message translates to:
  /// **'Cómo se calcula esto'**
  String get healthHowCalculated;

  /// No description provided for @healthCardCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad real'**
  String get healthCardCapacity;

  /// No description provided for @healthCardLoss.
  ///
  /// In es, this message translates to:
  /// **'Pérdida'**
  String get healthCardLoss;

  /// No description provided for @healthCardCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos reales'**
  String get healthCardCycles;

  /// No description provided for @healthCardInflation.
  ///
  /// In es, this message translates to:
  /// **'Contador infla'**
  String get healthCardInflation;

  /// No description provided for @healthCardImbalance.
  ///
  /// In es, this message translates to:
  /// **'Desbalance'**
  String get healthCardImbalance;

  /// No description provided for @healthCardWeakest.
  ///
  /// In es, this message translates to:
  /// **'Celda que manda'**
  String get healthCardWeakest;

  /// No description provided for @healthCardSpread.
  ///
  /// In es, this message translates to:
  /// **'Peor resistencia'**
  String get healthCardSpread;

  /// No description provided for @healthCardUsable.
  ///
  /// In es, this message translates to:
  /// **'Energía utilizable'**
  String get healthCardUsable;

  /// No description provided for @healthCardConsumption.
  ///
  /// In es, this message translates to:
  /// **'Consumo'**
  String get healthCardConsumption;

  /// No description provided for @healthCardLearnedKm.
  ///
  /// In es, this message translates to:
  /// **'Km aprendidos'**
  String get healthCardLearnedKm;

  /// No description provided for @tripTitle.
  ///
  /// In es, this message translates to:
  /// **'Viaje'**
  String get tripTitle;

  /// No description provided for @tripOpen.
  ///
  /// In es, this message translates to:
  /// **'Modo viaje'**
  String get tripOpen;

  /// No description provided for @tripStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar viaje'**
  String get tripStart;

  /// No description provided for @tripPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get tripPause;

  /// No description provided for @tripResume.
  ///
  /// In es, this message translates to:
  /// **'Reanudar'**
  String get tripResume;

  /// No description provided for @tripStop.
  ///
  /// In es, this message translates to:
  /// **'Terminar'**
  String get tripStop;

  /// No description provided for @tripRecording.
  ///
  /// In es, this message translates to:
  /// **'grabando'**
  String get tripRecording;

  /// No description provided for @tripPaused.
  ///
  /// In es, this message translates to:
  /// **'en pausa'**
  String get tripPaused;

  /// No description provided for @tripIdle.
  ///
  /// In es, this message translates to:
  /// **'sin viaje'**
  String get tripIdle;

  /// No description provided for @tripDistance.
  ///
  /// In es, this message translates to:
  /// **'Distancia'**
  String get tripDistance;

  /// No description provided for @tripSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get tripSpeed;

  /// No description provided for @tripMaxSpeed.
  ///
  /// In es, this message translates to:
  /// **'Máxima'**
  String get tripMaxSpeed;

  /// No description provided for @tripAvgSpeed.
  ///
  /// In es, this message translates to:
  /// **'Promedio'**
  String get tripAvgSpeed;

  /// No description provided for @tripMoving.
  ///
  /// In es, this message translates to:
  /// **'En movimiento'**
  String get tripMoving;

  /// No description provided for @tripElapsed.
  ///
  /// In es, this message translates to:
  /// **'Transcurrido'**
  String get tripElapsed;

  /// No description provided for @tripConsumption.
  ///
  /// In es, this message translates to:
  /// **'Consumo'**
  String get tripConsumption;

  /// No description provided for @tripEnergyOut.
  ///
  /// In es, this message translates to:
  /// **'Energía usada'**
  String get tripEnergyOut;

  /// No description provided for @tripEnergyIn.
  ///
  /// In es, this message translates to:
  /// **'Recuperada'**
  String get tripEnergyIn;

  /// No description provided for @tripSocUsed.
  ///
  /// In es, this message translates to:
  /// **'Carga gastada'**
  String get tripSocUsed;

  /// No description provided for @tripSocPerKm.
  ///
  /// In es, this message translates to:
  /// **'Carga por km'**
  String get tripSocPerKm;

  /// No description provided for @tripSag.
  ///
  /// In es, this message translates to:
  /// **'Caída máxima'**
  String get tripSag;

  /// No description provided for @tripMaxCurrent.
  ///
  /// In es, this message translates to:
  /// **'Corriente máxima'**
  String get tripMaxCurrent;

  /// No description provided for @tripMaxTemp.
  ///
  /// In es, this message translates to:
  /// **'Temperatura máxima'**
  String get tripMaxTemp;

  /// No description provided for @tripMaxDelta.
  ///
  /// In es, this message translates to:
  /// **'Delta máximo'**
  String get tripMaxDelta;

  /// No description provided for @tripClimb.
  ///
  /// In es, this message translates to:
  /// **'Subida'**
  String get tripClimb;

  /// No description provided for @tripDescent.
  ///
  /// In es, this message translates to:
  /// **'Bajada'**
  String get tripDescent;

  /// No description provided for @tripSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Viaje terminado'**
  String get tripSummaryTitle;

  /// No description provided for @tripNotSaved.
  ///
  /// In es, this message translates to:
  /// **'El viaje queda guardado con su recorrido. Puedes verlo después en la pestaña Viajes.'**
  String get tripNotSaved;

  /// No description provided for @tripHowItLearns.
  ///
  /// In es, this message translates to:
  /// **'Al terminar, los Wh medidos y los km recorridos se suman al estimador de autonomía. Cada viaje lo corrige un poco más.'**
  String get tripHowItLearns;

  /// No description provided for @tripPackDuring.
  ///
  /// In es, this message translates to:
  /// **'Cómo se portó el pack'**
  String get tripPackDuring;

  /// No description provided for @tripClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get tripClose;

  /// No description provided for @locationDisabled.
  ///
  /// In es, this message translates to:
  /// **'La ubicación del teléfono está apagada. Actívala para registrar distancia.'**
  String get locationDisabled;

  /// No description provided for @locationDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin permiso de ubicación no se puede medir distancia ni velocidad.'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In es, this message translates to:
  /// **'El permiso de ubicación está bloqueado. Habilítalo desde los ajustes de Android.'**
  String get locationDeniedForever;

  /// No description provided for @historyTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay viajes grabados'**
  String get historyEmpty;

  /// No description provided for @historyEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Empieza un viaje desde la pestaña Ahora y al terminar queda guardado aquí, con su recorrido.'**
  String get historyEmptyHint;

  /// No description provided for @historyTrips.
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get historyTrips;

  /// No description provided for @historyTotals.
  ///
  /// In es, this message translates to:
  /// **'Totales'**
  String get historyTotals;

  /// No description provided for @historyTotalDistance.
  ///
  /// In es, this message translates to:
  /// **'Distancia total'**
  String get historyTotalDistance;

  /// No description provided for @historyTotalEnergy.
  ///
  /// In es, this message translates to:
  /// **'Energía total'**
  String get historyTotalEnergy;

  /// No description provided for @historyTotalTrips.
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get historyTotalTrips;

  /// No description provided for @historyAverage.
  ///
  /// In es, this message translates to:
  /// **'Consumo promedio'**
  String get historyAverage;

  /// No description provided for @historyDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar viaje'**
  String get historyDelete;

  /// No description provided for @historyDeleted.
  ///
  /// In es, this message translates to:
  /// **'Viaje borrado'**
  String get historyDeleted;

  /// No description provided for @historyUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get historyUndo;

  /// No description provided for @historyDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle del viaje'**
  String get historyDetail;

  /// No description provided for @historyPoints.
  ///
  /// In es, this message translates to:
  /// **'{count} puntos de recorrido'**
  String historyPoints(int count);

  /// No description provided for @historyNoPoints.
  ///
  /// In es, this message translates to:
  /// **'Sin recorrido guardado'**
  String get historyNoPoints;

  /// No description provided for @historyProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil del viaje'**
  String get historyProfile;

  /// No description provided for @historyLegendSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get historyLegendSpeed;

  /// No description provided for @historyLegendAltitude.
  ///
  /// In es, this message translates to:
  /// **'Altitud'**
  String get historyLegendAltitude;

  /// No description provided for @historyStorage.
  ///
  /// In es, this message translates to:
  /// **'Almacenamiento'**
  String get historyStorage;

  /// No description provided for @historyStorageSnapshots.
  ///
  /// In es, this message translates to:
  /// **'Lecturas guardadas'**
  String get historyStorageSnapshots;

  /// No description provided for @historyStorageFrames.
  ///
  /// In es, this message translates to:
  /// **'Frames crudos'**
  String get historyStorageFrames;

  /// No description provided for @historyStorageSize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño en disco'**
  String get historyStorageSize;

  /// No description provided for @historyStorageNote.
  ///
  /// In es, this message translates to:
  /// **'Los frames crudos se guardan 30 días y después se borran solos. Están para poder reinterpretar el histórico si aparece que un offset del protocolo estaba mal leído.'**
  String get historyStorageNote;

  /// No description provided for @adviceTitle.
  ///
  /// In es, this message translates to:
  /// **'Qué haría yo con esto'**
  String get adviceTitle;

  /// No description provided for @adviceNone.
  ///
  /// In es, this message translates to:
  /// **'Nada que señalar. El pack se está portando bien.'**
  String get adviceNone;

  /// No description provided for @adviceImbalanceAtRestTitle.
  ///
  /// In es, this message translates to:
  /// **'Las celdas están desparejas en reposo'**
  String get adviceImbalanceAtRestTitle;

  /// No description provided for @adviceImbalanceAtRestBody.
  ///
  /// In es, this message translates to:
  /// **'Con la moto quieta el delta llega a {delta} V. Sin corriente de por medio eso no es resistencia: son celdas que guardan cantidades distintas de carga. Déjala cargar hasta arriba y en reposo unas horas para que el balanceador trabaje; si en varias cargas no se cierra, la celda {cell} tiene menos capacidad que el resto.'**
  String adviceImbalanceAtRestBody(String delta, int cell);

  /// No description provided for @adviceImbalanceUnderLoadTitle.
  ///
  /// In es, this message translates to:
  /// **'El delta se abre solo con corriente'**
  String get adviceImbalanceUnderLoadTitle;

  /// No description provided for @adviceImbalanceUnderLoadBody.
  ///
  /// In es, this message translates to:
  /// **'En reposo las celdas están parejas, pero bajo carga se separan {delta} V más. Eso es resistencia, y nueve de cada diez veces es una conexión floja u oxidada, no una celda mala. Revisa el tornillo y la barra de la celda {cell} antes de pensar en cambiar nada.'**
  String adviceImbalanceUnderLoadBody(String delta, int cell);

  /// No description provided for @adviceWeakCellTitle.
  ///
  /// In es, this message translates to:
  /// **'Siempre es la misma celda'**
  String get adviceWeakCellTitle;

  /// No description provided for @adviceWeakCellBody.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} fue la más baja en el {percent}% de las lecturas. No es ruido: esa celda es la que define tu autonomía real y la que llega primero al corte.'**
  String adviceWeakCellBody(int cell, String percent);

  /// No description provided for @adviceCycleInflatedTitle.
  ///
  /// In es, this message translates to:
  /// **'El contador de ciclos exagera'**
  String get adviceCycleInflatedTitle;

  /// No description provided for @adviceCycleInflatedBody.
  ///
  /// In es, this message translates to:
  /// **'El BMS informa {factor} veces más ciclos de los que justifica la carga que realmente pasó por el pack. Suma cargas parciales como si fueran completas. Si vas a comprar o vender un pack, el número honesto es el de ciclos equivalentes.'**
  String adviceCycleInflatedBody(String factor);

  /// No description provided for @adviceHealthDecorativeTitle.
  ///
  /// In es, this message translates to:
  /// **'El SOH del BMS no se mueve'**
  String get adviceHealthDecorativeTitle;

  /// No description provided for @adviceHealthDecorativeBody.
  ///
  /// In es, this message translates to:
  /// **'Sigue clavado en 100% con ciclos reales encima. Muchos firmwares nunca lo recalculan. Ignóralo y guíate por la capacidad medida.'**
  String get adviceHealthDecorativeBody;

  /// No description provided for @adviceCapacityBelowTitle.
  ///
  /// In es, this message translates to:
  /// **'Hay menos capacidad de la que dice la etiqueta'**
  String get adviceCapacityBelowTitle;

  /// No description provided for @adviceCapacityBelowBody.
  ///
  /// In es, this message translates to:
  /// **'Los propios números del BMS implican un {percent}% menos de lo que el pack dice tener. Puede ser degradación real, o que el contador de coulombs esté desincronizado. Un test de capacidad completo lo resuelve sin dudas.'**
  String adviceCapacityBelowBody(String percent);

  /// No description provided for @adviceNoCapacityTestTitle.
  ///
  /// In es, this message translates to:
  /// **'Nunca mediste la capacidad de verdad'**
  String get adviceNoCapacityTestTitle;

  /// No description provided for @adviceNoCapacityTestBody.
  ///
  /// In es, this message translates to:
  /// **'Es la única forma de saber si te vendieron lo que dice la caja. Carga al tope, conduce hasta que corte, y deja que la app integre los Ah que salieron. Todo lo demás son estimaciones.'**
  String get adviceNoCapacityTestBody;

  /// No description provided for @adviceRunningHotTitle.
  ///
  /// In es, this message translates to:
  /// **'El pack está caliente'**
  String get adviceRunningHotTitle;

  /// No description provided for @adviceRunningHotBody.
  ///
  /// In es, this message translates to:
  /// **'Llegó a {temp} °C. Afloja un poco y fíjate que no tenga el aire tapado. El calor es lo que más rápido envejece una celda de litio.'**
  String adviceRunningHotBody(String temp);

  /// No description provided for @adviceBalancerNeverSeenTitle.
  ///
  /// In es, this message translates to:
  /// **'El balanceador nunca arrancó'**
  String get adviceBalancerNeverSeenTitle;

  /// No description provided for @adviceBalancerNeverSeenBody.
  ///
  /// In es, this message translates to:
  /// **'Las celdas están desparejas pero el balanceador no trabajó en toda la sesión. O está apagado, o su voltaje de arranque ({voltage} V) está por encima de donde llegan tus celdas. Se revisa en los ajustes del BMS con la app oficial: esta app no escribe nada.'**
  String adviceBalancerNeverSeenBody(String voltage);

  /// No description provided for @adviceOvervoltageHighTitle.
  ///
  /// In es, this message translates to:
  /// **'El límite de sobretensión está alto'**
  String get adviceOvervoltageHighTitle;

  /// No description provided for @adviceOvervoltageHighBody.
  ///
  /// In es, this message translates to:
  /// **'Está en {voltage} V por celda. Para NMC, cada décima por encima de 4.20 se paga en ciclos. Bajarlo un poco cuesta algo de autonomía y devuelve bastante vida.'**
  String adviceOvervoltageHighBody(String voltage);

  /// No description provided for @adviceRangeLearningTitle.
  ///
  /// In es, this message translates to:
  /// **'La autonomía todavía es una estimación'**
  String get adviceRangeLearningTitle;

  /// No description provided for @adviceRangeLearningBody.
  ///
  /// In es, this message translates to:
  /// **'Lleva {km} km aprendidos. Graba algunos viajes completos y el número se ajusta a cómo conduces tú.'**
  String adviceRangeLearningBody(String km);

  /// No description provided for @adviceImbalanceCostingTitle.
  ///
  /// In es, this message translates to:
  /// **'El desbalance te está costando autonomía'**
  String get adviceImbalanceCostingTitle;

  /// No description provided for @adviceImbalanceCostingBody.
  ///
  /// In es, this message translates to:
  /// **'Un {percent}% de la energía que el pack todavía guarda queda atrapada arriba del corte, porque la celda más baja llega antes que las demás. Cerrar el delta te devuelve esos kilómetros sin cambiar una sola celda.'**
  String adviceImbalanceCostingBody(String percent);

  /// No description provided for @statusAllClear.
  ///
  /// In es, this message translates to:
  /// **'Todo en orden'**
  String get statusAllClear;

  /// No description provided for @statusExplain.
  ///
  /// In es, this message translates to:
  /// **'Esta franja mira tres cosas: que el BMS no tenga alarmas, que las celdas no estén muy separadas entre sí, y que nada esté demasiado caliente. No mira cuánta carga queda: una batería vacía no está enferma.'**
  String get statusExplain;

  /// No description provided for @statusSpreadWatch.
  ///
  /// In es, this message translates to:
  /// **'Celdas separadas {delta} V'**
  String statusSpreadWatch(String delta);

  /// No description provided for @statusSpreadBad.
  ///
  /// In es, this message translates to:
  /// **'Celdas muy separadas: {delta} V'**
  String statusSpreadBad(String delta);

  /// No description provided for @statusTempWatch.
  ///
  /// In es, this message translates to:
  /// **'Temperatura alta: {temp} °C'**
  String statusTempWatch(String temp);

  /// No description provided for @statusTempBad.
  ///
  /// In es, this message translates to:
  /// **'Demasiado caliente: {temp} °C'**
  String statusTempBad(String temp);

  /// No description provided for @tripStartFromHistory.
  ///
  /// In es, this message translates to:
  /// **'Empezar un viaje'**
  String get tripStartFromHistory;

  /// No description provided for @tripDeleteConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar este viaje?'**
  String get tripDeleteConfirmTitle;

  /// No description provided for @tripDeleteConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra el viaje y su recorrido. El consumo que aprendió el estimador de autonomía se vuelve a calcular sin él.'**
  String get tripDeleteConfirmBody;

  /// No description provided for @tripDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get tripDeleteConfirm;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @tripSwipeHint.
  ///
  /// In es, this message translates to:
  /// **'Desliza un viaje hacia la izquierda para borrarlo.'**
  String get tripSwipeHint;

  /// No description provided for @rangeRelearned.
  ///
  /// In es, this message translates to:
  /// **'Autonomía recalculada con {count} viajes'**
  String rangeRelearned(int count);

  /// No description provided for @tripLearnedTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que aprendió este viaje'**
  String get tripLearnedTitle;

  /// No description provided for @tripLearnedFirst.
  ///
  /// In es, this message translates to:
  /// **'Es el primer viaje con datos, así que el consumo aprendido pasa a ser el de este recorrido: {after} Wh/km.'**
  String tripLearnedFirst(String after);

  /// No description provided for @tripLearnedChanged.
  ///
  /// In es, this message translates to:
  /// **'El consumo aprendido pasó de {before} a {after} Wh/km.'**
  String tripLearnedChanged(String before, String after);

  /// No description provided for @tripLearnedUnchanged.
  ///
  /// In es, this message translates to:
  /// **'Este viaje confirmó lo que ya sabía: {after} Wh/km.'**
  String tripLearnedUnchanged(String after);

  /// No description provided for @tripLearnedTooShort.
  ///
  /// In es, this message translates to:
  /// **'Demasiado corto para aprender algo. Hacen falta al menos 500 metros con consumo real.'**
  String get tripLearnedTooShort;

  /// No description provided for @tripLearnedRange.
  ///
  /// In es, this message translates to:
  /// **'Autonomía ahora'**
  String get tripLearnedRange;

  /// No description provided for @tripLearnedTotalKm.
  ///
  /// In es, this message translates to:
  /// **'Aprendido de'**
  String get tripLearnedTotalKm;

  /// No description provided for @tripLearnedConfidence.
  ///
  /// In es, this message translates to:
  /// **'Confianza'**
  String get tripLearnedConfidence;

  /// No description provided for @tripDeepDischargeTip.
  ///
  /// In es, this message translates to:
  /// **'Este viaje bajó mucho la carga, y eso es justamente lo que más ayuda: cuanto más rango de la batería recorre un viaje, menos margen de error queda en el cálculo.'**
  String get tripDeepDischargeTip;

  /// No description provided for @tripShallowTip.
  ///
  /// In es, this message translates to:
  /// **'Consejo: un viaje que gasta poca carga deja más margen de error. Si quieres afinar la autonomía, un recorrido largo enseña mucho más que varios cortos.'**
  String get tripShallowTip;

  /// No description provided for @tripHotTip.
  ///
  /// In es, this message translates to:
  /// **'El pack llegó a {temp} °C en este viaje. Vale la pena mirar la pestaña Térmico si se repite.'**
  String tripHotTip(String temp);

  /// No description provided for @tripDeltaTip.
  ///
  /// In es, this message translates to:
  /// **'El delta llegó a {delta} V bajo carga. Si en reposo las celdas están parejas, eso apunta a una conexión, no a una celda mala.'**
  String tripDeltaTip(String delta);

  /// No description provided for @tripThirstyTip.
  ///
  /// In es, this message translates to:
  /// **'Este viaje gastó {percent}% más que tu promedio. Viento, cuestas, carga o mano derecha: si se repite, el promedio se ajustará solo.'**
  String tripThirstyTip(String percent);

  /// No description provided for @tripStopped.
  ///
  /// In es, this message translates to:
  /// **'Detenido'**
  String get tripStopped;

  /// No description provided for @tripNotificationTitle.
  ///
  /// In es, this message translates to:
  /// **'Viaje en curso'**
  String get tripNotificationTitle;

  /// No description provided for @tripNotificationChannel.
  ///
  /// In es, this message translates to:
  /// **'Grabación de viaje'**
  String get tripNotificationChannel;

  /// No description provided for @tripNotificationChannelDesc.
  ///
  /// In es, this message translates to:
  /// **'Mantiene el viaje grabando con la pantalla apagada o con otra app abierta.'**
  String get tripNotificationChannelDesc;

  /// No description provided for @tripNotificationDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin permiso de notificaciones el viaje se detiene al salir de la app. Se puede activar en los ajustes de Android.'**
  String get tripNotificationDenied;

  /// No description provided for @proximityTitle.
  ///
  /// In es, this message translates to:
  /// **'Conectar solo al acercarme'**
  String get proximityTitle;

  /// No description provided for @proximityBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando esté activado, la app busca tu BMS cada medio minuto y se conecta sola en cuanto aparece. Pensado para dejarlo un tiempo mientras calibras una batería nueva, no para siempre: mientras está conectado la app oficial de JK no puede entrar, y buscar consume algo de batería del teléfono.'**
  String get proximityBody;

  /// No description provided for @proximityLimit.
  ///
  /// In es, this message translates to:
  /// **'Funciona con la app abierta o en segundo plano. Si Android mata el proceso, deja de buscar hasta que la vuelvas a abrir.'**
  String get proximityLimit;

  /// No description provided for @proximityRemembered.
  ///
  /// In es, this message translates to:
  /// **'Buscando'**
  String get proximityRemembered;

  /// No description provided for @proximityNoDevice.
  ///
  /// In es, this message translates to:
  /// **'Conecta una vez a tu BMS y quedará recordado aquí.'**
  String get proximityNoDevice;

  /// No description provided for @proximityFound.
  ///
  /// In es, this message translates to:
  /// **'BMS encontrado, conectando'**
  String get proximityFound;

  /// No description provided for @proximityScanning.
  ///
  /// In es, this message translates to:
  /// **'buscando'**
  String get proximityScanning;

  /// No description provided for @capacityTitle.
  ///
  /// In es, this message translates to:
  /// **'Test de capacidad'**
  String get capacityTitle;

  /// No description provided for @capacityIntro.
  ///
  /// In es, this message translates to:
  /// **'La única medición real de la app. Todo lo demás son cuentas cruzadas sobre lo que el BMS dice de sí mismo; esto cuenta los amperios-hora que salen de verdad entre lleno y corte, y los compara con lo que te vendieron.'**
  String get capacityIntro;

  /// No description provided for @capacityStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar test'**
  String get capacityStart;

  /// No description provided for @capacityAbort.
  ///
  /// In es, this message translates to:
  /// **'Cancelar test'**
  String get capacityAbort;

  /// No description provided for @capacityRunning.
  ///
  /// In es, this message translates to:
  /// **'midiendo'**
  String get capacityRunning;

  /// No description provided for @capacityNotFull.
  ///
  /// In es, this message translates to:
  /// **'Carga el pack al tope primero. Empezar a media carga solo mediría un pedazo, y el resultado saldría corto.'**
  String get capacityNotFull;

  /// No description provided for @capacityNoReadings.
  ///
  /// In es, this message translates to:
  /// **'Conecta el BMS primero.'**
  String get capacityNoReadings;

  /// No description provided for @capacityDrawn.
  ///
  /// In es, this message translates to:
  /// **'Sacado hasta ahora'**
  String get capacityDrawn;

  /// No description provided for @capacityProgress.
  ///
  /// In es, this message translates to:
  /// **'Avance'**
  String get capacityProgress;

  /// No description provided for @capacityStartedAt.
  ///
  /// In es, this message translates to:
  /// **'Empezó'**
  String get capacityStartedAt;

  /// No description provided for @capacityResult.
  ///
  /// In es, this message translates to:
  /// **'Capacidad medida'**
  String get capacityResult;

  /// No description provided for @capacityVsCatalogue.
  ///
  /// In es, this message translates to:
  /// **'Frente a catálogo'**
  String get capacityVsCatalogue;

  /// No description provided for @capacityCharged.
  ///
  /// In es, this message translates to:
  /// **'El pack se cargó a mitad del test, así que el total no sirve. Conviene repetirlo desde lleno sin enchufar nada.'**
  String get capacityCharged;

  /// No description provided for @capacityCost.
  ///
  /// In es, this message translates to:
  /// **'Ojo: llevar el pack hasta el corte gasta ciclos. Vale la pena de vez en cuando para medir, no como costumbre.'**
  String get capacityCost;

  /// No description provided for @capacityNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has medido la capacidad'**
  String get capacityNone;

  /// No description provided for @capacityHistory.
  ///
  /// In es, this message translates to:
  /// **'Mediciones'**
  String get capacityHistory;

  /// No description provided for @capacityAutoNote.
  ///
  /// In es, this message translates to:
  /// **'No hace falta que te acuerdes de nada: la app revisa las lecturas guardadas y toma como medición cualquier descarga completa que ya haya ocurrido. El botón es para hacerla a propósito y ver el avance en vivo.'**
  String get capacityAutoNote;

  /// No description provided for @capacityAutoTag.
  ///
  /// In es, this message translates to:
  /// **'detectada'**
  String get capacityAutoTag;

  /// No description provided for @capacityGapWarning.
  ///
  /// In es, this message translates to:
  /// **'Con {minutes} min sin conexión, así que la cifra se queda corta.'**
  String capacityGapWarning(String minutes);

  /// No description provided for @chargeReportTitle.
  ///
  /// In es, this message translates to:
  /// **'Última carga'**
  String get chargeReportTitle;

  /// No description provided for @chargeReportIntro.
  ///
  /// In es, this message translates to:
  /// **'Arriba de 4,0 V por celda la curva se vuelve empinada, así que una diferencia pequeña de carga entre celdas se ve como una diferencia grande de voltaje. Es la mejor ventana que da el pack, y la que nadie mira porque se carga de noche.'**
  String get chargeReportIntro;

  /// No description provided for @chargeAdded.
  ///
  /// In es, this message translates to:
  /// **'Metido'**
  String get chargeAdded;

  /// No description provided for @chargeFrom.
  ///
  /// In es, this message translates to:
  /// **'De {start}% a {end}%'**
  String chargeFrom(String start, String end);

  /// No description provided for @chargeDeltaStart.
  ///
  /// In es, this message translates to:
  /// **'Delta al empezar'**
  String get chargeDeltaStart;

  /// No description provided for @chargeDeltaTop.
  ///
  /// In es, this message translates to:
  /// **'Delta arriba'**
  String get chargeDeltaTop;

  /// No description provided for @chargeWorstDelta.
  ///
  /// In es, this message translates to:
  /// **'Peor delta arriba'**
  String get chargeWorstDelta;

  /// No description provided for @chargeWeakCell.
  ///
  /// In es, this message translates to:
  /// **'Celda que se queda atrás'**
  String get chargeWeakCell;

  /// No description provided for @chargeBalancerTime.
  ///
  /// In es, this message translates to:
  /// **'Balanceador trabajando'**
  String get chargeBalancerTime;

  /// No description provided for @chargeNeverReachedTop.
  ///
  /// In es, this message translates to:
  /// **'Esta carga no llegó arriba de 4,0 V por celda, así que no dice nada del desbalance. Para que sirva hay que cargar hasta el tope.'**
  String get chargeNeverReachedTop;

  /// No description provided for @chargeOpensAtTop.
  ///
  /// In es, this message translates to:
  /// **'Las celdas iban parejas y se abrieron al final. Ese patrón es capacidad desigual, no una conexión floja: la celda {cell} se llena antes que las demás.'**
  String chargeOpensAtTop(int cell);

  /// No description provided for @chargeNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no se ha grabado ninguna carga'**
  String get chargeNone;

  /// No description provided for @trendsTitle.
  ///
  /// In es, this message translates to:
  /// **'Con el tiempo'**
  String get trendsTitle;

  /// No description provided for @trendsConsumption.
  ///
  /// In es, this message translates to:
  /// **'Consumo por viaje'**
  String get trendsConsumption;

  /// No description provided for @trendsCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad medida'**
  String get trendsCapacity;

  /// No description provided for @trendsSag.
  ///
  /// In es, this message translates to:
  /// **'Caída bajo carga'**
  String get trendsSag;

  /// No description provided for @trendsDeltaVsCharge.
  ///
  /// In es, this message translates to:
  /// **'Delta contra carga'**
  String get trendsDeltaVsCharge;

  /// No description provided for @trendsSpan.
  ///
  /// In es, this message translates to:
  /// **'{days} días de histórico'**
  String trendsSpan(int days);

  /// No description provided for @trendsNotEnough.
  ///
  /// In es, this message translates to:
  /// **'Hace falta más histórico para que esto signifique algo. Se va llenando sola.'**
  String get trendsNotEnough;

  /// No description provided for @trendsPerMonth.
  ///
  /// In es, this message translates to:
  /// **'{value} por mes'**
  String trendsPerMonth(String value);

  /// No description provided for @trendsLegendLoaded.
  ///
  /// In es, this message translates to:
  /// **'Bajo carga'**
  String get trendsLegendLoaded;

  /// No description provided for @trendsLegendResting.
  ///
  /// In es, this message translates to:
  /// **'En reposo'**
  String get trendsLegendResting;

  /// No description provided for @trendsDeltaHint.
  ///
  /// In es, this message translates to:
  /// **'Si el delta es plano y salta cerca del tope, hay una celda con menos capacidad. Si crece con la corriente, es resistencia: casi siempre una conexión.'**
  String get trendsDeltaHint;

  /// No description provided for @trendsSagHint.
  ///
  /// In es, this message translates to:
  /// **'La misma corriente produciendo una caída mayor con los meses significa que la resistencia interna sube. Se nota mucho antes que la pérdida de capacidad.'**
  String get trendsSagHint;

  /// No description provided for @alertTitle.
  ///
  /// In es, this message translates to:
  /// **'Aviso'**
  String get alertTitle;

  /// No description provided for @alertBmsFault.
  ///
  /// In es, this message translates to:
  /// **'El BMS levantó una alarma'**
  String get alertBmsFault;

  /// No description provided for @alertCellSpread.
  ///
  /// In es, this message translates to:
  /// **'Las celdas se separaron mucho'**
  String get alertCellSpread;

  /// No description provided for @alertTemperature.
  ///
  /// In es, this message translates to:
  /// **'El pack está demasiado caliente'**
  String get alertTemperature;

  /// No description provided for @alertLowCharge.
  ///
  /// In es, this message translates to:
  /// **'Queda poca carga'**
  String get alertLowCharge;

  /// No description provided for @alertCriticalCharge.
  ///
  /// In es, this message translates to:
  /// **'La carga está casi agotada'**
  String get alertCriticalCharge;

  /// No description provided for @alertCellNearCutoff.
  ///
  /// In es, this message translates to:
  /// **'Una celda está cerca del corte'**
  String get alertCellNearCutoff;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsCatalogue.
  ///
  /// In es, this message translates to:
  /// **'Capacidad de catálogo'**
  String get settingsCatalogue;

  /// No description provided for @settingsCatalogueHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que dice la etiqueta del pack. Es contra este número que se mide la salud, así que conviene que sea el real.'**
  String get settingsCatalogueHint;

  /// No description provided for @catalogueUnset.
  ///
  /// In es, this message translates to:
  /// **'Sin definir'**
  String get catalogueUnset;

  /// No description provided for @catalogueUnsetHint.
  ///
  /// In es, this message translates to:
  /// **'Nadie ha dicho todavía con cuántos amperios-hora se vendió esta batería, y la app no se lo inventa. Hasta que lo pongas, la salud y la degradación no se pueden calcular: no hay contra qué compararlas.'**
  String get catalogueUnsetHint;

  /// No description provided for @catalogueSetIt.
  ///
  /// In es, this message translates to:
  /// **'Definir capacidad'**
  String get catalogueSetIt;

  /// No description provided for @catalogueUseBms.
  ///
  /// In es, this message translates to:
  /// **'Usar {ah} Ah del BMS'**
  String catalogueUseBms(String ah);

  /// No description provided for @catalogueNotComparable.
  ///
  /// In es, this message translates to:
  /// **'sin comparar'**
  String get catalogueNotComparable;

  /// No description provided for @settingsCatalogueForPack.
  ///
  /// In es, this message translates to:
  /// **'Lo que te vendieron como {pack}. Cada batería tiene la suya, así que cambiarla aquí no toca las demás.'**
  String settingsCatalogueForPack(String pack);

  /// No description provided for @exportNoPack.
  ///
  /// In es, this message translates to:
  /// **'Conecta un pack para exportar su historial.'**
  String get exportNoPack;

  /// No description provided for @settingsBmsConfigured.
  ///
  /// In es, this message translates to:
  /// **'Configurada en el BMS'**
  String get settingsBmsConfigured;

  /// No description provided for @settingsCapacityMismatch.
  ///
  /// In es, this message translates to:
  /// **'El BMS está configurado para {bms} Ah y el pack se vendió como {sold} Ah. Ese número del BMS no es una medición: es lo que escribió quien armó el pack, y es contra lo que el BMS calcula el porcentaje de carga. La diferencia ya es un dato, así que la app no lo copia encima de lo tuyo.'**
  String settingsCapacityMismatch(String bms, String sold);

  /// No description provided for @settingsHaptics.
  ///
  /// In es, this message translates to:
  /// **'Vibrar con los avisos'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsHint.
  ///
  /// In es, this message translates to:
  /// **'Rodando nadie mira la pantalla. Con esto el teléfono avisa aunque esté en el bolsillo.'**
  String get settingsHapticsHint;

  /// No description provided for @settingsRawFrames.
  ///
  /// In es, this message translates to:
  /// **'Guardar frames crudos'**
  String get settingsRawFrames;

  /// No description provided for @settingsRawFramesHint.
  ///
  /// In es, this message translates to:
  /// **'Déjalo encendido. Es lo que permite reinterpretar el histórico si aparece que un offset del protocolo estaba mal leído.'**
  String get settingsRawFramesHint;

  /// No description provided for @settingsSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get settingsSave;

  /// No description provided for @exportTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get exportTitle;

  /// No description provided for @exportIntro.
  ///
  /// In es, this message translates to:
  /// **'Los datos que no puedes sacar no son del todo tuyos.'**
  String get exportIntro;

  /// No description provided for @exportTrips.
  ///
  /// In es, this message translates to:
  /// **'Viajes (CSV)'**
  String get exportTrips;

  /// No description provided for @exportReadings.
  ///
  /// In es, this message translates to:
  /// **'Lecturas de la última semana (CSV)'**
  String get exportReadings;

  /// No description provided for @exportFrames.
  ///
  /// In es, this message translates to:
  /// **'Frames crudos del último día'**
  String get exportFrames;

  /// No description provided for @exportTrack.
  ///
  /// In es, this message translates to:
  /// **'Recorrido (GPX)'**
  String get exportTrack;

  /// No description provided for @exportDone.
  ///
  /// In es, this message translates to:
  /// **'Guardado en {path}'**
  String exportDone(String path);

  /// No description provided for @exportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar'**
  String get exportFailed;

  /// No description provided for @warnWireResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia de cable alta'**
  String get warnWireResistance;

  /// No description provided for @warnMosfetOvertemp.
  ///
  /// In es, this message translates to:
  /// **'MOSFET sobrecalentado'**
  String get warnMosfetOvertemp;

  /// No description provided for @warnCellCountMismatch.
  ///
  /// In es, this message translates to:
  /// **'Número de celdas distinto al configurado'**
  String get warnCellCountMismatch;

  /// No description provided for @warnFullyCharged.
  ///
  /// In es, this message translates to:
  /// **'Pack cargado al tope'**
  String get warnFullyCharged;

  /// No description provided for @warnPackOvervoltage.
  ///
  /// In es, this message translates to:
  /// **'Sobrevoltaje del pack'**
  String get warnPackOvervoltage;

  /// No description provided for @warnChargeOvercurrent.
  ///
  /// In es, this message translates to:
  /// **'Sobrecorriente de carga'**
  String get warnChargeOvercurrent;

  /// No description provided for @warnChargeShortCircuit.
  ///
  /// In es, this message translates to:
  /// **'Cortocircuito en carga'**
  String get warnChargeShortCircuit;

  /// No description provided for @warnChargeOvertemp.
  ///
  /// In es, this message translates to:
  /// **'Temperatura alta cargando'**
  String get warnChargeOvertemp;

  /// No description provided for @warnChargeUndertemp.
  ///
  /// In es, this message translates to:
  /// **'Temperatura baja cargando'**
  String get warnChargeUndertemp;

  /// No description provided for @warnCoprocessor.
  ///
  /// In es, this message translates to:
  /// **'Fallo de comunicación interna del BMS'**
  String get warnCoprocessor;

  /// No description provided for @warnCellUndervoltage.
  ///
  /// In es, this message translates to:
  /// **'Celda por debajo del mínimo'**
  String get warnCellUndervoltage;

  /// No description provided for @warnPackUndervoltage.
  ///
  /// In es, this message translates to:
  /// **'Voltaje del pack por debajo del mínimo'**
  String get warnPackUndervoltage;

  /// No description provided for @warnDischargeOvercurrent.
  ///
  /// In es, this message translates to:
  /// **'Sobrecorriente de descarga'**
  String get warnDischargeOvercurrent;

  /// No description provided for @warnDischargeShortCircuit.
  ///
  /// In es, this message translates to:
  /// **'Cortocircuito en descarga'**
  String get warnDischargeShortCircuit;

  /// No description provided for @warnDischargeOvertemp.
  ///
  /// In es, this message translates to:
  /// **'Temperatura alta descargando'**
  String get warnDischargeOvertemp;

  /// No description provided for @warnChargeMosfet.
  ///
  /// In es, this message translates to:
  /// **'MOSFET de carga con fallo'**
  String get warnChargeMosfet;

  /// No description provided for @warnDischargeMosfet.
  ///
  /// In es, this message translates to:
  /// **'MOSFET de descarga con fallo'**
  String get warnDischargeMosfet;

  /// No description provided for @warnGpsDisconnected.
  ///
  /// In es, this message translates to:
  /// **'GPS desconectado'**
  String get warnGpsDisconnected;

  /// No description provided for @warnChangePassword.
  ///
  /// In es, this message translates to:
  /// **'Cambia la contraseña del BMS'**
  String get warnChangePassword;

  /// No description provided for @warnDischargeOnFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo activar la descarga'**
  String get warnDischargeOnFailed;

  /// No description provided for @warnPackOvertemp.
  ///
  /// In es, this message translates to:
  /// **'Pack sobrecalentado'**
  String get warnPackOvertemp;

  /// No description provided for @warnTempSensor.
  ///
  /// In es, this message translates to:
  /// **'Sensor de temperatura con fallo'**
  String get warnTempSensor;

  /// No description provided for @warnPlModule.
  ///
  /// In es, this message translates to:
  /// **'Módulo PL con fallo'**
  String get warnPlModule;

  /// No description provided for @warnScpRelease.
  ///
  /// In es, this message translates to:
  /// **'No se liberó la protección de cortocircuito'**
  String get warnScpRelease;

  /// No description provided for @warnDischargeOcp2.
  ///
  /// In es, this message translates to:
  /// **'Sobrecorriente de descarga (nivel 2)'**
  String get warnDischargeOcp2;

  /// No description provided for @warnDischargeOcp3.
  ///
  /// In es, this message translates to:
  /// **'Sobrecorriente de descarga (nivel 3)'**
  String get warnDischargeOcp3;

  /// No description provided for @warnDischargeUndertemp.
  ///
  /// In es, this message translates to:
  /// **'Temperatura baja descargando'**
  String get warnDischargeUndertemp;

  /// No description provided for @warnGpsRemoteLock.
  ///
  /// In es, this message translates to:
  /// **'Bloqueo remoto por GPS'**
  String get warnGpsRemoteLock;

  /// No description provided for @updateTitle.
  ///
  /// In es, this message translates to:
  /// **'Actualizaciones'**
  String get updateTitle;

  /// No description provided for @updateIntro.
  ///
  /// In es, this message translates to:
  /// **'La app no está en ninguna tienda, así que se actualiza desde las releases de GitHub. No comprueba nada sola ni descarga nada por su cuenta: lo pides tú.'**
  String get updateIntro;

  /// No description provided for @updateInstalled.
  ///
  /// In es, this message translates to:
  /// **'Versión instalada'**
  String get updateInstalled;

  /// No description provided for @updatePublished.
  ///
  /// In es, this message translates to:
  /// **'Última publicada'**
  String get updatePublished;

  /// No description provided for @updateReleasedOn.
  ///
  /// In es, this message translates to:
  /// **'Publicada el {date}'**
  String updateReleasedOn(String date);

  /// No description provided for @updateCheck.
  ///
  /// In es, this message translates to:
  /// **'Buscar actualización'**
  String get updateCheck;

  /// No description provided for @updateChecking.
  ///
  /// In es, this message translates to:
  /// **'Buscando...'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In es, this message translates to:
  /// **'Estás en la última versión.'**
  String get updateUpToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión {version} disponible ({size} MB).'**
  String updateAvailable(String version, String size);

  /// No description provided for @updateDownload.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get updateDownload;

  /// No description provided for @updateDownloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando... {percent}%'**
  String updateDownloading(String percent);

  /// No description provided for @updateInstall.
  ///
  /// In es, this message translates to:
  /// **'Instalar'**
  String get updateInstall;

  /// No description provided for @updateReady.
  ///
  /// In es, this message translates to:
  /// **'Descargada. Al instalar, Android te va a pedir confirmación.'**
  String get updateReady;

  /// No description provided for @updateNoAsset.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión {version}, pero no trae una build para el procesador de este teléfono.'**
  String updateNoAsset(String version);

  /// No description provided for @updateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo comprobar: {error}'**
  String updateFailed(String error);

  /// No description provided for @updateNeedsToken.
  ///
  /// In es, this message translates to:
  /// **'GitHub no entregó la release. Suele ser porque el repositorio está privado, y entonces hace falta un token de lectura. Si está público, vuelve a intentarlo en un momento.'**
  String get updateNeedsToken;

  /// No description provided for @updateTokenLabel.
  ///
  /// In es, this message translates to:
  /// **'Token de GitHub'**
  String get updateTokenLabel;

  /// No description provided for @updateTokenHint.
  ///
  /// In es, this message translates to:
  /// **'Solo hace falta si el repositorio es privado. Se guarda en este teléfono y solo se manda a api.github.com; no está dentro del APK, justo para que no viaje con él.'**
  String get updateTokenHint;

  /// No description provided for @updateTokenSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get updateTokenSave;

  /// No description provided for @updateTokenSaved.
  ///
  /// In es, this message translates to:
  /// **'Token guardado'**
  String get updateTokenSaved;

  /// No description provided for @updateNeedsPermission.
  ///
  /// In es, this message translates to:
  /// **'Android no deja instalar paquetes a esta app todavía. Ábrele el permiso y vuelve.'**
  String get updateNeedsPermission;

  /// No description provided for @updateOpenPermission.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get updateOpenPermission;

  /// No description provided for @updateNotes.
  ///
  /// In es, this message translates to:
  /// **'Novedades'**
  String get updateNotes;

  /// No description provided for @packsTitle.
  ///
  /// In es, this message translates to:
  /// **'Baterías'**
  String get packsTitle;

  /// No description provided for @packsIntro.
  ///
  /// In es, this message translates to:
  /// **'Todo lo que la app mide (capacidad, degradación, qué celda se queda atrás, cuánto cuesta un kilómetro) es de una batería concreta. Cada pack guarda su historial aparte, así que puedes usar el mismo teléfono con varias sin que se mezclen.'**
  String get packsIntro;

  /// No description provided for @packsCurrent.
  ///
  /// In es, this message translates to:
  /// **'Conectada ahora'**
  String get packsCurrent;

  /// No description provided for @packsNone.
  ///
  /// In es, this message translates to:
  /// **'Ninguna conectada'**
  String get packsNone;

  /// No description provided for @packsKnown.
  ///
  /// In es, this message translates to:
  /// **'Baterías conocidas'**
  String get packsKnown;

  /// No description provided for @packsLastSeen.
  ///
  /// In es, this message translates to:
  /// **'Vista el {date}'**
  String packsLastSeen(String date);

  /// No description provided for @packsRename.
  ///
  /// In es, this message translates to:
  /// **'Cambiar nombre'**
  String get packsRename;

  /// No description provided for @packsRenameHint.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la batería'**
  String get packsRenameHint;

  /// No description provided for @packsSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get packsSave;

  /// No description provided for @packsCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get packsCancel;

  /// No description provided for @packsDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar batería'**
  String get packsDelete;

  /// No description provided for @packsDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Se borra {pack} y todo lo grabado con ella: viajes, recorridos, lecturas, frames crudos y mediciones de capacidad. No se puede deshacer.'**
  String packsDeleteConfirm(String pack);

  /// No description provided for @packsRides.
  ///
  /// In es, this message translates to:
  /// **'{count} viajes'**
  String packsRides(String count);

  /// No description provided for @orphansTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial sin batería asignada'**
  String get orphansTitle;

  /// No description provided for @orphansBody.
  ///
  /// In es, this message translates to:
  /// **'Hay {count} filas guardadas antes de que la app separara por batería, así que no consta de cuál son. Puedes asignarlas a la batería conectada o descartarlas. La app no lo adivina sola: una procedencia inventada al lado de mediciones reales es peor que un hueco.'**
  String orphansBody(String count);

  /// No description provided for @orphansAdopt.
  ///
  /// In es, this message translates to:
  /// **'Asignar a esta batería'**
  String get orphansAdopt;

  /// No description provided for @orphansDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get orphansDiscard;

  /// No description provided for @orphansDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get orphansDone;

  /// No description provided for @storedTitle.
  ///
  /// In es, this message translates to:
  /// **'Baterías guardadas'**
  String get storedTitle;

  /// No description provided for @storedOpen.
  ///
  /// In es, this message translates to:
  /// **'Ver historial'**
  String get storedOpen;

  /// No description provided for @storedNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has conectado ninguna batería.'**
  String get storedNone;

  /// No description provided for @storedLastSeen.
  ///
  /// In es, this message translates to:
  /// **'Última lectura {when}'**
  String storedLastSeen(String when);

  /// No description provided for @storedNever.
  ///
  /// In es, this message translates to:
  /// **'sin lecturas guardadas'**
  String get storedNever;

  /// No description provided for @offlineTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen guardado'**
  String get offlineTitle;

  /// No description provided for @offlineBanner.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Todo esto sale de lo que ya estaba guardado, no del BMS ahora mismo.'**
  String get offlineBanner;

  /// No description provided for @offlineLastReading.
  ///
  /// In es, this message translates to:
  /// **'Última lectura'**
  String get offlineLastReading;

  /// No description provided for @offlineStateOfCharge.
  ///
  /// In es, this message translates to:
  /// **'Carga entonces'**
  String get offlineStateOfCharge;

  /// No description provided for @offlineTrips.
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get offlineTrips;

  /// No description provided for @offlineTripsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} guardados'**
  String offlineTripsCount(String count);

  /// No description provided for @offlineTotalKm.
  ///
  /// In es, this message translates to:
  /// **'Distancia total'**
  String get offlineTotalKm;

  /// No description provided for @offlineRange.
  ///
  /// In es, this message translates to:
  /// **'Autonomía aprendida'**
  String get offlineRange;

  /// No description provided for @offlineRangeUnknown.
  ///
  /// In es, this message translates to:
  /// **'aún sin aprender'**
  String get offlineRangeUnknown;

  /// No description provided for @offlineNoData.
  ///
  /// In es, this message translates to:
  /// **'No hay lecturas guardadas de esta batería todavía. Conéctate una vez y quedará aquí.'**
  String get offlineNoData;

  /// No description provided for @appSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get appSettingsTitle;

  /// No description provided for @settingsSectionApp.
  ///
  /// In es, this message translates to:
  /// **'Aplicación'**
  String get settingsSectionApp;

  /// No description provided for @settingsSectionPack.
  ///
  /// In es, this message translates to:
  /// **'Esta batería'**
  String get settingsSectionPack;

  /// No description provided for @agoPrefix.
  ///
  /// In es, this message translates to:
  /// **'hace'**
  String get agoPrefix;

  /// No description provided for @agoSuffix.
  ///
  /// In es, this message translates to:
  /// **''**
  String get agoSuffix;

  /// No description provided for @catalogueFromBmsTag.
  ///
  /// In es, this message translates to:
  /// **'del BMS'**
  String get catalogueFromBmsTag;

  /// No description provided for @catalogueConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar que se vendió así'**
  String get catalogueConfirm;

  /// No description provided for @catalogueFromBmsHint.
  ///
  /// In es, this message translates to:
  /// **'Tomado de la configuración del BMS, que es un número sobre este pack pero lo escribió quien lo armó. Si te lo vendieron con otra capacidad, ponla: la diferencia entre las dos cifras es justo lo que la salud mide.'**
  String get catalogueFromBmsHint;

  /// No description provided for @connectRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar búsqueda'**
  String get connectRetry;

  /// No description provided for @storedManageHint.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsada una batería para renombrarla o borrarla.'**
  String get storedManageHint;

  /// No description provided for @offlineHealthTitle.
  ///
  /// In es, this message translates to:
  /// **'Salud guardada'**
  String get offlineHealthTitle;

  /// No description provided for @offlineMeasuredHealth.
  ///
  /// In es, this message translates to:
  /// **'Salud medida'**
  String get offlineMeasuredHealth;

  /// No description provided for @offlineImplied.
  ///
  /// In es, this message translates to:
  /// **'Capacidad total'**
  String get offlineImplied;

  /// No description provided for @offlineImpliedHint.
  ///
  /// In es, this message translates to:
  /// **'Ah restantes divididos entre la carga que reporta el BMS. Es la capacidad que implica su propio contador, no una medición independiente.'**
  String get offlineImpliedHint;

  /// No description provided for @offlineImpliedUnusable.
  ///
  /// In es, this message translates to:
  /// **'La última lectura fue con la carga muy alta o muy baja, y ahí esa división es solo ruido.'**
  String get offlineImpliedUnusable;

  /// No description provided for @offlineSoh.
  ///
  /// In es, this message translates to:
  /// **'Salud que reporta el BMS'**
  String get offlineSoh;

  /// No description provided for @offlineCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos que cuenta el BMS'**
  String get offlineCycles;

  /// No description provided for @offlineWeakest.
  ///
  /// In es, this message translates to:
  /// **'Celda más floja'**
  String get offlineWeakest;

  /// No description provided for @offlineWeakestValue.
  ///
  /// In es, this message translates to:
  /// **'celda {index}, {volts} V'**
  String offlineWeakestValue(String index, String volts);

  /// No description provided for @offlineMaxTemp.
  ///
  /// In es, this message translates to:
  /// **'Temperatura'**
  String get offlineMaxTemp;

  /// No description provided for @offlineHistorySince.
  ///
  /// In es, this message translates to:
  /// **'Historial desde'**
  String get offlineHistorySince;

  /// No description provided for @offlineReadings.
  ///
  /// In es, this message translates to:
  /// **'{count} lecturas guardadas'**
  String offlineReadings(String count);

  /// No description provided for @offlineBestMeasured.
  ///
  /// In es, this message translates to:
  /// **'Mejor medición real'**
  String get offlineBestMeasured;

  /// No description provided for @connectWaitingFirst.
  ///
  /// In es, this message translates to:
  /// **'Conectando y esperando la primera lectura...'**
  String get connectWaitingFirst;

  /// No description provided for @connectNotABms.
  ///
  /// In es, this message translates to:
  /// **'Se conectó, pero no llegó ninguna lectura de BMS. Casi seguro que ese dispositivo no es un BMS JK. Si crees que sí lo es, mira la consola de frames crudos en Ajustes.'**
  String get connectNotABms;

  /// No description provided for @storedCount.
  ///
  /// In es, this message translates to:
  /// **'{count} guardadas'**
  String storedCount(String count);

  /// No description provided for @updateBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión {version}'**
  String updateBannerTitle(String version);

  /// No description provided for @updateBannerAction.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get updateBannerAction;

  /// No description provided for @updateBannerDismiss.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get updateBannerDismiss;

  /// No description provided for @thermalProbeAbsent.
  ///
  /// In es, this message translates to:
  /// **'sin conectar'**
  String get thermalProbeAbsent;

  /// No description provided for @thermalAbsentNote.
  ///
  /// In es, this message translates to:
  /// **'Las sondas sin conectar reportan valores imposibles, del orden de -200 °C. No son frío: no hay nada cableado a esa entrada. Se muestran aparte para que no ensucien ni el máximo ni los avisos.'**
  String get thermalAbsentNote;

  /// No description provided for @backupTitle.
  ///
  /// In es, this message translates to:
  /// **'Copia de seguridad'**
  String get backupTitle;

  /// No description provided for @backupIntro.
  ///
  /// In es, this message translates to:
  /// **'Toda la base de datos en un archivo, y de vuelta. Las exportaciones a CSV y GPX son para leer los datos en otro sitio; esto es para no perderlos. Si cambias de teléfono o lo pierdes, es lo único que trae de vuelta meses de lecturas, los viajes con su recorrido y los frames crudos.'**
  String get backupIntro;

  /// No description provided for @backupExport.
  ///
  /// In es, this message translates to:
  /// **'Crear copia'**
  String get backupExport;

  /// No description provided for @backupExportLight.
  ///
  /// In es, this message translates to:
  /// **'Crear copia sin frames crudos'**
  String get backupExportLight;

  /// No description provided for @backupImport.
  ///
  /// In es, this message translates to:
  /// **'Restaurar desde un archivo'**
  String get backupImport;

  /// No description provided for @backupImportMerge.
  ///
  /// In es, this message translates to:
  /// **'Añadir a lo que ya hay'**
  String get backupImportMerge;

  /// No description provided for @backupImportReplace.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar todo'**
  String get backupImportReplace;

  /// No description provided for @backupImportChoose.
  ///
  /// In es, this message translates to:
  /// **'¿Qué hacer con lo que ya está guardado?'**
  String get backupImportChoose;

  /// No description provided for @backupReplaceWarning.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar borra todo lo que hay ahora en el teléfono antes de restaurar. No se puede deshacer.'**
  String get backupReplaceWarning;

  /// No description provided for @backupDone.
  ///
  /// In es, this message translates to:
  /// **'Restaurado: {trips} viajes, {readings} lecturas, {packs} baterías.'**
  String backupDone(String trips, String readings, String packs);

  /// No description provided for @backupFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo restaurar: {reason}'**
  String backupFailed(String reason);

  /// No description provided for @backupWorking.
  ///
  /// In es, this message translates to:
  /// **'Trabajando...'**
  String get backupWorking;

  /// No description provided for @chargeAlertsTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos de carga'**
  String get chargeAlertsTitle;

  /// No description provided for @chargeAlertsIntro.
  ///
  /// In es, this message translates to:
  /// **'Se carga de noche y nadie lo mira. Estos avisos existen para eso. Parar antes del tope no es superstición: la parte alta del rango es donde una celda de litio envejece más, así que si mañana no necesitas el pack entero, te conviene quedarte antes.'**
  String get chargeAlertsIntro;

  /// No description provided for @chargeTarget.
  ///
  /// In es, this message translates to:
  /// **'Avisar al llegar a'**
  String get chargeTarget;

  /// No description provided for @chargeTargetOff.
  ///
  /// In es, this message translates to:
  /// **'Desactivado'**
  String get chargeTargetOff;

  /// No description provided for @chargeAlertTargetReached.
  ///
  /// In es, this message translates to:
  /// **'La batería llegó al {soc} %'**
  String chargeAlertTargetReached(String soc);

  /// No description provided for @chargeAlertComplete.
  ///
  /// In es, this message translates to:
  /// **'Carga terminada'**
  String get chargeAlertComplete;

  /// No description provided for @chargeAlertHot.
  ///
  /// In es, this message translates to:
  /// **'Se está calentando cargando'**
  String get chargeAlertHot;

  /// No description provided for @chargeAlertSpread.
  ///
  /// In es, this message translates to:
  /// **'Las celdas se separan arriba'**
  String get chargeAlertSpread;

  /// No description provided for @compareTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparar baterías'**
  String get compareTitle;

  /// No description provided for @compareIntro.
  ///
  /// In es, this message translates to:
  /// **'Las mismas cifras de siempre, pero juntas. En verde la mejor de cada fila, y solo cuando hay diferencia de verdad.'**
  String get compareIntro;

  /// No description provided for @compareNeedsTwo.
  ///
  /// In es, this message translates to:
  /// **'Hace falta haberse conectado a por lo menos dos baterías para poder compararlas.'**
  String get compareNeedsTwo;

  /// No description provided for @compareHealth.
  ///
  /// In es, this message translates to:
  /// **'Salud medida'**
  String get compareHealth;

  /// No description provided for @compareHonestCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos reales'**
  String get compareHonestCycles;

  /// No description provided for @compareConsumption.
  ///
  /// In es, this message translates to:
  /// **'Consumo'**
  String get compareConsumption;

  /// No description provided for @compareWorstDelta.
  ///
  /// In es, this message translates to:
  /// **'Peor delta visto'**
  String get compareWorstDelta;

  /// No description provided for @compareOpen.
  ///
  /// In es, this message translates to:
  /// **'Comparar baterías'**
  String get compareOpen;

  /// No description provided for @driftTitle.
  ///
  /// In es, this message translates to:
  /// **'Celda que se está yendo'**
  String get driftTitle;

  /// No description provided for @driftNone.
  ///
  /// In es, this message translates to:
  /// **'Ninguna celda se está separando del resto.'**
  String get driftNone;

  /// No description provided for @driftNotEnough.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay historial suficiente. Hacen falta unas semanas de lecturas en reposo para distinguir una celda que empeora de una que siempre estuvo algo baja.'**
  String get driftNotEnough;

  /// No description provided for @driftFound.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} se está separando: {now} V por debajo de la media, y baja unos {rate} V al mes.'**
  String driftFound(String cell, String now, String rate);

  /// No description provided for @driftWhy.
  ///
  /// In es, this message translates to:
  /// **'Una celda que siempre estuvo baja es un pack que se armó así. Una que hace seis semanas iba a la par y ahora va por debajo es una celda en camino de irse, y esa es la diferencia entre cambiar una celda y cambiar un pack.'**
  String get driftWhy;

  /// No description provided for @updateDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Tienes la {current}. La nueva pesa {size} MB. No se descarga nada hasta que lo pidas.'**
  String updateDialogBody(String current, String size);

  /// No description provided for @widgetJustNow.
  ///
  /// In es, this message translates to:
  /// **'ahora mismo'**
  String get widgetJustNow;

  /// No description provided for @widgetMinutes.
  ///
  /// In es, this message translates to:
  /// **'hace {n} min'**
  String widgetMinutes(String n);

  /// No description provided for @widgetHours.
  ///
  /// In es, this message translates to:
  /// **'hace {n} h'**
  String widgetHours(String n);

  /// No description provided for @widgetDays.
  ///
  /// In es, this message translates to:
  /// **'hace {n} d'**
  String widgetDays(String n);

  /// No description provided for @maintTitle.
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento'**
  String get maintTitle;

  /// No description provided for @maintIntro.
  ///
  /// In es, this message translates to:
  /// **'Lo que le has hecho al pack, con fecha. El historial guarda lo que la batería hizo y se olvida de lo que le hiciste tú, que es la otra mitad. Una capacidad que da un salto o un delta que se desploma parecen ruido hasta que ves que esa semana cambiaste una celda.'**
  String get maintIntro;

  /// No description provided for @maintNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has anotado nada.'**
  String get maintNone;

  /// No description provided for @maintAdd.
  ///
  /// In es, this message translates to:
  /// **'Anotar algo'**
  String get maintAdd;

  /// No description provided for @maintDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get maintDate;

  /// No description provided for @maintKind.
  ///
  /// In es, this message translates to:
  /// **'Qué hiciste'**
  String get maintKind;

  /// No description provided for @maintNote.
  ///
  /// In es, this message translates to:
  /// **'Detalle (opcional)'**
  String get maintNote;

  /// No description provided for @maintSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get maintSave;

  /// No description provided for @maintDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get maintDelete;

  /// No description provided for @maintKindCellReplaced.
  ///
  /// In es, this message translates to:
  /// **'Cambié una celda'**
  String get maintKindCellReplaced;

  /// No description provided for @maintKindManualBalance.
  ///
  /// In es, this message translates to:
  /// **'Balanceé a mano'**
  String get maintKindManualBalance;

  /// No description provided for @maintKindConnections.
  ///
  /// In es, this message translates to:
  /// **'Limpié o apreté conexiones'**
  String get maintKindConnections;

  /// No description provided for @maintKindCharger.
  ///
  /// In es, this message translates to:
  /// **'Cambié de cargador'**
  String get maintKindCharger;

  /// No description provided for @maintKindBmsSettings.
  ///
  /// In es, this message translates to:
  /// **'Cambié ajustes del BMS'**
  String get maintKindBmsSettings;

  /// No description provided for @maintKindOther.
  ///
  /// In es, this message translates to:
  /// **'Otra cosa'**
  String get maintKindOther;

  /// No description provided for @maintSince.
  ///
  /// In es, this message translates to:
  /// **'Historial desde el cambio de celda: {date}'**
  String maintSince(String date);

  /// No description provided for @trendsMaintMarks.
  ///
  /// In es, this message translates to:
  /// **'Las líneas de puntos son cosas que anotaste en el mantenimiento.'**
  String get trendsMaintMarks;

  /// No description provided for @chargeWatchTitle.
  ///
  /// In es, this message translates to:
  /// **'Vigilar la carga'**
  String get chargeWatchTitle;

  /// No description provided for @chargeWatchHint.
  ///
  /// In es, this message translates to:
  /// **'Mientras la app está en segundo plano Android corta la conexión Bluetooth a los pocos minutos. Con esto activado, en cuanto detecta que estás cargando levanta un servicio en primer plano y mantiene la conexión, que es lo que hace falta para que los avisos lleguen de noche. Cuesta batería del teléfono mientras dura.'**
  String get chargeWatchHint;

  /// No description provided for @chargeWatchNotifTitle.
  ///
  /// In es, this message translates to:
  /// **'Cargando'**
  String get chargeWatchNotifTitle;

  /// No description provided for @chargeWatchNotifText.
  ///
  /// In es, this message translates to:
  /// **'{soc} % · {volts} V · {amps} A'**
  String chargeWatchNotifText(String soc, String volts, String amps);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'es':
      return AppL10nEs();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
