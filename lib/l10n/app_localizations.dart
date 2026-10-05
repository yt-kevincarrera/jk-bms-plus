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
  /// **'El BMS acepta una sola conexión Bluetooth a la vez. Cierra la app oficial de tu BMS antes de conectar aquí.'**
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
  /// **'No apareció nada. Casi siempre es una de estas:\n\n• La app oficial de tu BMS está conectada a él. Mientras lo está, el BMS deja de anunciarse y ningún otro teléfono lo ve. Ciérrala del todo.\n• El pack está dormido. Enciende la moto o muévela para despertarlo.\n• Estás lejos. Acércate al pack.'**
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

  /// No description provided for @brandAskTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué BMS es?'**
  String get brandAskTitle;

  /// No description provided for @brandAskBody.
  ///
  /// In es, this message translates to:
  /// **'El nombre no lo dice. Elige la marca una vez; la app la recuerda.'**
  String get brandAskBody;

  /// No description provided for @brandJk.
  ///
  /// In es, this message translates to:
  /// **'JK (Jikong)'**
  String get brandJk;

  /// No description provided for @brandAnt.
  ///
  /// In es, this message translates to:
  /// **'ANT'**
  String get brandAnt;

  /// No description provided for @tapBusy.
  ///
  /// In es, this message translates to:
  /// **'Ya hay un intento en marcha. Espera a que termine: tocar otra vez no lo acelera y sí puede dejar otra conexión colgada en el teléfono.'**
  String get tapBusy;

  /// No description provided for @tapCooling.
  ///
  /// In es, this message translates to:
  /// **'Espera {seconds} s antes de reintentar con esta batería. La pausa no es un capricho: el BMS tarda unos segundos en soltar el enlace anterior, y cada intento dentro de esa ventana deja una conexión que el teléfono no cierra.'**
  String tapCooling(String seconds);

  /// No description provided for @tapStackSaturated.
  ///
  /// In es, this message translates to:
  /// **'Van {count} intentos fallidos seguidos. A estas alturas el problema es el Bluetooth del teléfono, no la batería, y otro intento solo lo empeora. Sigue los pasos de la tarjeta de arriba y después vuelve a buscar para reintentar.'**
  String tapStackSaturated(String count);

  /// No description provided for @tileConnected.
  ///
  /// In es, this message translates to:
  /// **'Conectada. Toca para volver a sus pantallas.'**
  String get tileConnected;

  /// No description provided for @tileCooling.
  ///
  /// In es, this message translates to:
  /// **'En pausa {seconds} s tras un intento fallido'**
  String tileCooling(String seconds);

  /// No description provided for @tileStackSaturated.
  ///
  /// In es, this message translates to:
  /// **'En espera: el Bluetooth del teléfono necesita reiniciarse'**
  String get tileStackSaturated;

  /// No description provided for @tilePillOpen.
  ///
  /// In es, this message translates to:
  /// **'abierta'**
  String get tilePillOpen;

  /// No description provided for @connectedCardNote.
  ///
  /// In es, this message translates to:
  /// **'El enlace sigue abierto. Salir de las pantallas de la batería ya no lo corta, así que puedes entrar y salir sin reconectar.'**
  String get connectedCardNote;

  /// No description provided for @connectedCardOpen.
  ///
  /// In es, this message translates to:
  /// **'Ver la batería'**
  String get connectedCardOpen;

  /// No description provided for @connectedCardRelease.
  ///
  /// In es, this message translates to:
  /// **'Desconectar'**
  String get connectedCardRelease;

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

  /// No description provided for @waitingWhyLinkDown.
  ///
  /// In es, this message translates to:
  /// **'El enlace Bluetooth no está conectado ahora mismo. La app sigue intentándolo sola; si no vuelve, arriba aparece el motivo.'**
  String get waitingWhyLinkDown;

  /// No description provided for @waitingWhyNoFrames.
  ///
  /// In es, this message translates to:
  /// **'Conectado, pero no ha llegado ni un frame del BMS. O la batería está callada con la app, o algo más tiene su sesión de datos.'**
  String get waitingWhyNoFrames;

  /// No description provided for @waitingWhyOnlyDeviceInfo.
  ///
  /// In es, this message translates to:
  /// **'Llegó la información del dispositivo, pero ninguna lectura de celdas. La app se la vuelve a pedir a la batería cada 3 segundos.'**
  String get waitingWhyOnlyDeviceInfo;

  /// No description provided for @waitingWhyVariantUnknown.
  ///
  /// In es, this message translates to:
  /// **'Llegan lecturas de celdas, pero la app no pudo determinar qué variante del protocolo habla esta batería y no las decodifica. Elige la variante a mano en Sistema.'**
  String get waitingWhyVariantUnknown;

  /// No description provided for @waitingWhyDecodeFailing.
  ///
  /// In es, this message translates to:
  /// **'Llegan lecturas de celdas, pero fallan al decodificar. El motivo exacto está en los avisos de abajo y en Sistema.'**
  String get waitingWhyDecodeFailing;

  /// No description provided for @waitingWhyUnexplained.
  ///
  /// In es, this message translates to:
  /// **'Llegan lecturas, se decodifican y se emiten, pero ninguna alcanzó esta pantalla. Eso es un fallo de la app: haz captura de esta pantalla y mándala.'**
  String get waitingWhyUnexplained;

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
  /// **'Autonomía restante'**
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
  /// **'Energía sacada del pack'**
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
  /// **'sin reposo reciente con qué comparar'**
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
  /// **'Más veces la más baja'**
  String get balanceRanking;

  /// No description provided for @resistanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Cables de balanceo'**
  String get resistanceTitle;

  /// No description provided for @resistanceSource.
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get resistanceSource;

  /// No description provided for @resistanceSourceValue.
  ///
  /// In es, this message translates to:
  /// **'medición de cada cable de balanceo del propio BMS, no de la celda'**
  String get resistanceSourceValue;

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

  /// No description provided for @historyItemCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad medida en cada descarga completa, y cómo cambia con los meses'**
  String get historyItemCapacity;

  /// No description provided for @historyItemTrips.
  ///
  /// In es, this message translates to:
  /// **'Lista de viajes con distancia, Wh y Wh/km'**
  String get historyItemTrips;

  /// No description provided for @historyItemDelta.
  ///
  /// In es, this message translates to:
  /// **'Delta contra el nivel de carga, que es donde una celda corta se delata'**
  String get historyItemDelta;

  /// No description provided for @historyItemSag.
  ///
  /// In es, this message translates to:
  /// **'Resistencia aparente de cada viaje, sacada de la caída de tensión para la corriente pedida'**
  String get historyItemSag;

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

  /// No description provided for @systemBrand.
  ///
  /// In es, this message translates to:
  /// **'Marca'**
  String get systemBrand;

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

  /// No description provided for @systemVariantProved.
  ///
  /// In es, this message translates to:
  /// **'Comprobado contra una lectura real: los números que salen con este formato describen una batería posible.'**
  String get systemVariantProved;

  /// No description provided for @systemVariantCorrected.
  ///
  /// In es, this message translates to:
  /// **'La app cambió de formato por su cuenta. La versión del firmware apuntaba a otro, y con ese los números eran imposibles: este es el que cuadra con la lectura.'**
  String get systemVariantCorrected;

  /// No description provided for @antStatusTitle.
  ///
  /// In es, this message translates to:
  /// **'Estado ANT'**
  String get antStatusTitle;

  /// No description provided for @antBatteryState.
  ///
  /// In es, this message translates to:
  /// **'Estado de la batería'**
  String get antBatteryState;

  /// No description provided for @antChargeMosfet.
  ///
  /// In es, this message translates to:
  /// **'MOSFET de carga'**
  String get antChargeMosfet;

  /// No description provided for @antDischargeMosfet.
  ///
  /// In es, this message translates to:
  /// **'MOSFET de descarga'**
  String get antDischargeMosfet;

  /// No description provided for @antBalancer.
  ///
  /// In es, this message translates to:
  /// **'Balanceador'**
  String get antBalancer;

  /// No description provided for @antBalancerTemp.
  ///
  /// In es, this message translates to:
  /// **'Temperatura del balanceador'**
  String get antBalancerTemp;

  /// No description provided for @antBatteryStateCode.
  ///
  /// In es, this message translates to:
  /// **'{code, select, 0{Desconocido} 1{Inactiva} 2{Cargando} 3{Descargando} 4{En espera} 5{Error} other{Desconocido}}'**
  String antBatteryStateCode(String code);

  /// No description provided for @antChargeMosfetCode.
  ///
  /// In es, this message translates to:
  /// **'{code, select, 0{Apagado} 1{Encendido} 2{Protección por sobrecarga} 3{Protección por sobrecorriente} 4{Batería llena} 5{Sobretensión del pack} 6{Sobretemperatura de la batería} 7{Sobretemperatura del MOSFET} 8{Corriente anómala} 9{Cable de balanceo desconectado} 10{Sobretemperatura de la placa} 11{Reservado} 12{No se pudo encender} 13{Fallo del MOSFET de descarga} 14{En espera} 15{Apagado manualmente} 16{Sobretensión de segundo nivel} 17{Protección por baja temperatura} 18{Diferencia de voltaje excesiva} 19{Reservado} 20{Error de autodiagnóstico} other{Desconocido}}'**
  String antChargeMosfetCode(String code);

  /// No description provided for @antDischargeMosfetCode.
  ///
  /// In es, this message translates to:
  /// **'{code, select, 0{Apagado} 1{Encendido} 2{Protección por sobredescarga} 3{Protección por sobrecorriente} 4{Sobrecorriente de segundo nivel} 5{Subtensión del pack} 6{Sobretemperatura de la batería} 7{Sobretemperatura del MOSFET} 8{Corriente anómala} 9{Cable de balanceo desconectado} 10{Sobretemperatura de la placa} 11{MOSFET de carga encendido} 12{Protección por cortocircuito} 13{Fallo del MOSFET de descarga} 14{No se pudo encender} 15{Apagado manualmente} 16{Subtensión de segundo nivel} 17{Protección por baja temperatura} 18{Diferencia de voltaje excesiva} 19{Error de autodiagnóstico} other{Desconocido}}'**
  String antDischargeMosfetCode(String code);

  /// No description provided for @antBalancerCode.
  ///
  /// In es, this message translates to:
  /// **'{code, select, 0{Apagado} 1{Balanceo por límite superado} 2{Balanceo por diferencia de voltaje en carga} 3{Sobretemperatura del balanceo} 4{Balanceo automático} 10{Sobretemperatura de la placa} other{Desconocido}}'**
  String antBalancerCode(String code);

  /// No description provided for @antUnknownCode.
  ///
  /// In es, this message translates to:
  /// **'Desconocido (0x{hex})'**
  String antUnknownCode(String hex);

  /// No description provided for @antBatteryType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de celda según el BMS'**
  String get antBatteryType;

  /// No description provided for @antBatteryTypeName.
  ///
  /// In es, this message translates to:
  /// **'{type, select, ternary{Litio ternario (NMC/NCA)} lfp{LiFePO4 (LFP)} lto{Titanato de litio (LTO)} custom{Personalizado} other{Desconocido}}'**
  String antBatteryTypeName(String type);

  /// No description provided for @antTotalCharged.
  ///
  /// In es, this message translates to:
  /// **'Carga acumulada'**
  String get antTotalCharged;

  /// No description provided for @antTotalDischarged.
  ///
  /// In es, this message translates to:
  /// **'Descarga acumulada'**
  String get antTotalDischarged;

  /// No description provided for @antChargingTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo cargando'**
  String get antChargingTime;

  /// No description provided for @antDischargingTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo descargando'**
  String get antDischargingTime;

  /// No description provided for @antCountersHint.
  ///
  /// In es, this message translates to:
  /// **'Contadores del propio BMS: cuentan todo lo que la placa ha visto, también lo que pasó sin esta app conectada.'**
  String get antCountersHint;

  /// No description provided for @antSettingsPending.
  ///
  /// In es, this message translates to:
  /// **'Un ANT no manda su configuración por su cuenta: la app se la pide ajuste por ajuste durante el primer minuto de conexión, con peticiones de lectura. Si no contesta, este BMS no la expone.'**
  String get antSettingsPending;

  /// No description provided for @antSettingShortCircuit.
  ///
  /// In es, this message translates to:
  /// **'Corte por cortocircuito'**
  String get antSettingShortCircuit;

  /// No description provided for @antProtocol.
  ///
  /// In es, this message translates to:
  /// **'Protocolo'**
  String get antProtocol;

  /// No description provided for @antProtocol2021.
  ///
  /// In es, this message translates to:
  /// **'ANT de 2021 en adelante'**
  String get antProtocol2021;

  /// No description provided for @antProtocolLegacy.
  ///
  /// In es, this message translates to:
  /// **'ANT anterior a 2021'**
  String get antProtocolLegacy;

  /// No description provided for @antSettingsLegacy.
  ///
  /// In es, this message translates to:
  /// **'Este ANT habla el protocolo anterior a 2021, y en ese la app no tiene cómo pedirle su configuración por Bluetooth: no se lee.'**
  String get antSettingsLegacy;

  /// No description provided for @demoScenarioAntRiding.
  ///
  /// In es, this message translates to:
  /// **'ANT, rodando'**
  String get demoScenarioAntRiding;

  /// No description provided for @demoScenarioAntRidingDesc.
  ///
  /// In es, this message translates to:
  /// **'Un ANT 20S simulado que contesta las peticiones de lectura de la app, en marcha'**
  String get demoScenarioAntRidingDesc;

  /// No description provided for @demoScenarioAntCharging.
  ///
  /// In es, this message translates to:
  /// **'ANT, cargando'**
  String get demoScenarioAntCharging;

  /// No description provided for @demoScenarioAntChargingDesc.
  ///
  /// In es, this message translates to:
  /// **'Un ANT 20S simulado en el cargador; manda la corriente de carga en negativo, como uno real'**
  String get demoScenarioAntChargingDesc;

  /// No description provided for @demoExplanationAnt.
  ///
  /// In es, this message translates to:
  /// **'Un ANT 20S simulado contesta las peticiones de lectura de la app con frames reales del protocolo de 2021, con su CRC. Pasan por el mismo ensamblado, CRC y parser que un ANT de verdad. Los valores en sí son modelados, no medidos.'**
  String get demoExplanationAnt;

  /// No description provided for @antSettingsNote.
  ///
  /// In es, this message translates to:
  /// **'Leído del propio BMS, un ajuste por petición. Un ANT no informa sus cortes de temperatura, así que aquí no salen.'**
  String get antSettingsNote;

  /// No description provided for @verdictConfigVoltagesLookSaneBody.
  ///
  /// In es, this message translates to:
  /// **'Los cortes de voltaje están donde deberían para esta química. Este BMS no informa sus cortes de temperatura ni sus interruptores, así que esos no se revisaron. Esto no dice nada sobre el estado de las celdas: es una revisión de los ajustes, no de la batería.'**
  String get verdictConfigVoltagesLookSaneBody;

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

  /// No description provided for @settingsNotExposed.
  ///
  /// In es, this message translates to:
  /// **'Este BMS no expone su configuración a la app.'**
  String get settingsNotExposed;

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
  /// **'La app no cambia nada en el BMS: solo le envía peticiones de lectura. Todo lo de arriba es solo lectura.'**
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

  /// No description provided for @consoleViewDecoded.
  ///
  /// In es, this message translates to:
  /// **'Decodificado'**
  String get consoleViewDecoded;

  /// No description provided for @consoleViewBytes.
  ///
  /// In es, this message translates to:
  /// **'Bytes'**
  String get consoleViewBytes;

  /// No description provided for @consoleCopyAll.
  ///
  /// In es, this message translates to:
  /// **'Copiar todo para diagnóstico'**
  String get consoleCopyAll;

  /// No description provided for @consoleCopiedAll.
  ///
  /// In es, this message translates to:
  /// **'Copiado: contadores, avisos, registro y bytes'**
  String get consoleCopiedAll;

  /// No description provided for @consoleLiveFromHere.
  ///
  /// In es, this message translates to:
  /// **'--- en vivo desde aquí ---'**
  String get consoleLiveFromHere;

  /// No description provided for @consoleNoBytes.
  ///
  /// In es, this message translates to:
  /// **'Todavía no pasó ningún byte por el enlace desde que se abrió la app.'**
  String get consoleNoBytes;

  /// No description provided for @consoleBytesLegend.
  ///
  /// In es, this message translates to:
  /// **'← recibido del BMS · → escrito por la app. Se conserva entre conexiones.'**
  String get consoleBytesLegend;

  /// No description provided for @consoleThisConnection.
  ///
  /// In es, this message translates to:
  /// **'Esta conexión'**
  String get consoleThisConnection;

  /// No description provided for @consoleLastReading.
  ///
  /// In es, this message translates to:
  /// **'última lectura hace {seconds} s'**
  String consoleLastReading(int seconds);

  /// No description provided for @consoleReportTitle.
  ///
  /// In es, this message translates to:
  /// **'Consola de frames crudos'**
  String get consoleReportTitle;

  /// No description provided for @consoleReportNotices.
  ///
  /// In es, this message translates to:
  /// **'Avisos, del más antiguo al más reciente'**
  String get consoleReportNotices;

  /// No description provided for @consoleReportDecoded.
  ///
  /// In es, this message translates to:
  /// **'Registro decodificado'**
  String get consoleReportDecoded;

  /// No description provided for @consoleReportBytes.
  ///
  /// In es, this message translates to:
  /// **'Bytes, del más antiguo al más reciente'**
  String get consoleReportBytes;

  /// No description provided for @systemCountersThisConnection.
  ///
  /// In es, this message translates to:
  /// **'Frames y bytes cuentan desde la última conexión. Caídas, tiempo desconectado e insistencias cuentan desde que se abrió la app.'**
  String get systemCountersThisConnection;

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
  /// **'Sin tests de capacidad, la cifra de arriba es la capacidad configurada en el BMS: el BMS calcula los Ah restantes como el SOC por esa capacidad, así que dividir una cosa por la otra la devuelve tal cual. No dice nada del desgaste; para eso hace falta medir una descarga completa.'**
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
  /// **'Ah totales que el BMS contó pasar por el pack, divididos por su capacidad configurada. El contador de ciclos del propio BMS puede quedar por encima o por debajo de esta cifra: cuenta en números enteros y cada firmware decide qué es un ciclo.'**
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
  /// **'El pack se corta cuando la celda más baja llega al límite, no cuando llega el promedio. Se mide con las celdas en reposo: el voltaje de la más baja y el de la media se pasan a nivel de carga con la curva típica de la química, y la diferencia se traduce a la energía que queda atrapada en las demás. Bajo carga o con el cargador puesto no se calcula, porque la caída o el empuje del cargador se confundirían con desequilibrio. En LFP, en la zona plana de la curva, el voltaje no dice cuánta carga hay, así que tampoco.'**
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
  /// **'La degradación medida necesita al menos dos descargas completas. La deriva de una celda y la evolución de la caída de tensión necesitan semanas de lecturas guardadas. Lo que sale de viajes y lecturas se va llenando solo; la capacidad no: cada punto es una descarga completa.'**
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
  /// **'La energía que queda son los Ah restantes que informa el BMS por el voltaje medio al que van a salir hasta el corte, leído de la curva típica de la química del pack. No por el voltaje de este momento, que sube con el cargador puesto y baja al acelerar. Después se descuenta lo que deja atrapado la celda más baja. Si no se sabe la química, se usa una cifra a la baja. Las curvas son las típicas de cada química, no medidas en este pack.'**
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
  /// **'Restante según el BMS'**
  String get healthCardCapacity;

  /// No description provided for @healthCardLoss.
  ///
  /// In es, this message translates to:
  /// **'Pérdida'**
  String get healthCardLoss;

  /// No description provided for @healthCardCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos equivalentes (según el BMS)'**
  String get healthCardCycles;

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

  /// No description provided for @tripResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia del pack (aprox.)'**
  String get tripResistance;

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
  /// **'Con la moto quieta el delta llega a {delta} V, y la más baja entonces era la celda {cell}. Sin corriente de por medio eso no es resistencia: son celdas que guardan cantidades distintas de carga. Déjala cargar hasta arriba y en reposo unas horas para que el balanceador trabaje; si en varias cargas no se cierra, esa celda tiene menos capacidad que el resto.'**
  String adviceImbalanceAtRestBody(String delta, int cell);

  /// No description provided for @adviceImbalanceUnderLoadTitle.
  ///
  /// In es, this message translates to:
  /// **'El delta se abre solo con corriente'**
  String get adviceImbalanceUnderLoadTitle;

  /// No description provided for @adviceImbalanceUnderLoadBody.
  ///
  /// In es, this message translates to:
  /// **'En reposo las celdas están parejas, pero bajo carga se separan {delta} V más, en varias lecturas. Eso es resistencia: puede ser una conexión o una celda con más resistencia que las demás. Revisa primero la conexión de la celda {cell}, que era la más baja con esa carga: es lo más barato de descartar.'**
  String adviceImbalanceUnderLoadBody(String delta, int cell);

  /// No description provided for @adviceWeakCellTitle.
  ///
  /// In es, this message translates to:
  /// **'Siempre es la misma celda'**
  String get adviceWeakCellTitle;

  /// No description provided for @adviceWeakCellBody.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} fue claramente la más baja en el {percent}% de las lecturas que cuentan: con las celdas separadas al menos 10 mV, sin empate y sin contar dos veces una lectura repetida. Esa celda es la que define tu autonomía real y la que llega primero al corte.'**
  String adviceWeakCellBody(int cell, String percent);

  /// No description provided for @adviceSocCounterAheadTitle.
  ///
  /// In es, this message translates to:
  /// **'El porcentaje de carga va por delante del pack'**
  String get adviceSocCounterAheadTitle;

  /// No description provided for @adviceSocCounterAheadBody.
  ///
  /// In es, this message translates to:
  /// **'El BMS dice {soc} %, pero la celda más alta está {gap} V por debajo de donde termina una carga. Ese porcentaje no se mide: el BMS suma amperios por tiempo contra la capacidad que tiene configurada, y ese contador deriva. Se vuelve a anclar solo si dejas que una carga llegue hasta el corte de una sentada. Si el desajuste vuelve después de eso, la capacidad configurada no es la que tiene el pack: mídela con un test de capacidad antes de cambiarla.'**
  String adviceSocCounterAheadBody(String gap, String soc);

  /// No description provided for @adviceSocCounterBehindTitle.
  ///
  /// In es, this message translates to:
  /// **'Queda más carga de la que dice'**
  String get adviceSocCounterBehindTitle;

  /// No description provided for @adviceSocCounterBehindBody.
  ///
  /// In es, this message translates to:
  /// **'El BMS dice {soc} %, pero la celda más baja está {gap} V por encima de donde el propio BMS llama vacío. Hay batería aquí que la pantalla no está contando. Ese porcentaje no se mide: es amperios por tiempo contra la capacidad configurada, y ese contador deriva. Si se repite, la capacidad configurada se queda corta frente a la real: mídela con un test de capacidad antes de cambiarla.'**
  String adviceSocCounterBehindBody(String gap, String soc);

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
  /// **'Da menos de lo que decía la etiqueta'**
  String get adviceCapacityBelowTitle;

  /// No description provided for @adviceCapacityBelowBody.
  ///
  /// In es, this message translates to:
  /// **'Los números del BMS implican un {percent}% menos de lo que se anunció. Eso no significa que la batería esté fallando: lo más común es que nunca fuera esa capacidad. Un test de capacidad completo separa las dos cosas, y a partir de ahí la degradación se mide contra lo que esta batería dio de verdad.'**
  String adviceCapacityBelowBody(String percent);

  /// No description provided for @adviceNoCapacityTestTitle.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay una medición real de capacidad'**
  String get adviceNoCapacityTestTitle;

  /// No description provided for @adviceNoCapacityTestBody.
  ///
  /// In es, this message translates to:
  /// **'No tienes que hacer nada especial: la app revisa las lecturas guardadas y toma como medición cualquier descarga completa que ocurra. Hace falta que sea completa porque el resto es circular: el porcentaje que reporta el BMS lo calcula contando amperios y dividiendo entre la capacidad que tiene configurada, así que medir una descarga parcial contra ese porcentaje devuelve la capacidad configurada otra vez, no la real. Solo una carga al tope y una descarga hasta el corte tienen los dos extremos anclados al voltaje.'**
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
  /// **'Las celdas están desparejas en reposo pero el balanceador no ha trabajado desde que se conectó el pack. O está apagado, o su voltaje de arranque ({voltage} V) está por encima de donde llegan tus celdas. Se revisa en los ajustes del BMS con su app oficial: esta app no cambia nada en el BMS, solo le envía peticiones de lectura.'**
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
  /// **'Un {percent}% de la energía que el pack todavía guarda queda atrapada arriba del corte, porque la celda más baja llega antes que las demás. Si el delta es de desequilibrio y no de capacidad, balancear lo recupera; si la celda tiene menos capacidad, no.'**
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
  /// **'No se aprendió nada de este viaje: hacen falta al menos {m} metros con la energía medida.'**
  String tripLearnedTooShort(String m);

  /// No description provided for @tripLearnedRange.
  ///
  /// In es, this message translates to:
  /// **'Autonomía al terminar'**
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
  /// **'El delta máximo del viaje fue {delta} V. Si en reposo las celdas están parejas, eso apunta a una conexión, no a una celda mala.'**
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
  /// **'Cuando esté activado, la app busca tu BMS cada medio minuto y se conecta sola en cuanto aparece. Pensado para dejarlo un tiempo mientras calibras una batería nueva, no para siempre: mientras está conectado la app oficial de tu BMS no puede entrar, y buscar consume algo de batería del teléfono.'**
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
  /// **'La única medición real de la app. Cuenta los amperios-hora que salen desde que la celda más alta está arriba, con el cargador ya soltando, hasta que la celda más baja llega al corte o el BMS corta. Los dos extremos los marcan las celdas, no el porcentaje del BMS: ese porcentaje se calcula contra la capacidad configurada, y medir con él solo devolvería esa configuración.'**
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
  /// **'Carga el pack al tope primero. El test arranca cuando la celda más alta está arriba y el cargador ya suelta poca corriente, no cuando el BMS dice 100 %. Empezar a media carga solo mediría un pedazo.'**
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
  /// **'No hace falta que te acuerdes de nada: la app revisa las lecturas guardadas y toma como medición cualquier descarga completa que ya haya ocurrido, de celdas arriba a celda en el corte, sin cargas ni huecos largos en medio. El botón es para hacerla a propósito y ver el avance en vivo.'**
  String get capacityAutoNote;

  /// No description provided for @capacityAutoTag.
  ///
  /// In es, this message translates to:
  /// **'detectada'**
  String get capacityAutoTag;

  /// No description provided for @capacityGapWarning.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min sin ver la batería, así que no cuenta como medición de capacidad.'**
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
  /// **'Las celdas iban parejas y se abrieron al final. Ese patrón es capacidad desigual, no una conexión floja: la celda {cell} se llena antes que las demás, y la {weak} es la que va más atrás.'**
  String chargeOpensAtTop(int cell, int weak);

  /// No description provided for @chargeNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay ninguna carga grabada de esta batería. Se graba cuando la app está conectada mientras carga.'**
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
  /// **'Resistencia aparente del pack'**
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
  /// **'A lo ancho va el nivel de carga, no el tiempo. Cada punto es la mediana del delta (la celda más alta menos la más baja) de las lecturas de los últimos 90 días a ese porcentaje de carga: una línea en reposo y otra descargando a más de 5 A. Las lecturas cargando no entran. Que se abra cerca de vacía y de llena es normal en casi cualquier pack, porque ahí la curva de voltaje es empinada. Lo que dice algo es la línea de reposo abriéndose en el medio, donde la curva es plana, o la de carga muy por encima de la de reposo: eso es resistencia, y casi siempre una conexión y no una celda.'**
  String get trendsDeltaHint;

  /// No description provided for @trendsSagHint.
  ///
  /// In es, this message translates to:
  /// **'Un punto por viaje: la resistencia aparente del pack, sacada de cómo se movió el voltaje en los tramos en que la corriente subía y bajaba deprisa, la mediana de esos tramos. Incluye el cableado y el BMS, y es aproximada, porque la corriente y el voltaje de una lectura no siempre son del mismo instante. Lo que vale es la tendencia: subiendo despacio con los meses es desgaste; un salto de golpe casi siempre es una conexión. Los viajes con pocos tramos así no tienen punto.'**
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
  /// **'Lo que dice la etiqueta del pack. Se usa para dos cosas: compararlo con lo que el pack mide de verdad en un test de capacidad, y calcular la autonomía con el pack lleno mientras no haya ninguna medida. El desgaste no se mide contra este número, sino contra la mejor descarga completa del propio pack.'**
  String get settingsCatalogueHint;

  /// No description provided for @catalogueUnset.
  ///
  /// In es, this message translates to:
  /// **'Sin definir'**
  String get catalogueUnset;

  /// No description provided for @catalogueUnsetHint.
  ///
  /// In es, this message translates to:
  /// **'Nadie ha dicho todavía con cuántos amperios-hora se vendió esta batería, y la app no se lo inventa. Sin él no hay comparación con lo anunciado, y la autonomía con el pack lleno espera a un test de capacidad. El desgaste no lo necesita: sale de las descargas completas medidas.'**
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
  /// **'Rodando nadie mira la pantalla. Con la app a la vista vibra el propio teléfono; con la pantalla apagada o el teléfono en el bolsillo vibra la notificación del aviso, así que para eso tienen que estar activados los avisos en la barra de notificaciones.'**
  String get settingsHapticsHint;

  /// No description provided for @settingsRawFrames.
  ///
  /// In es, this message translates to:
  /// **'Guardar frames crudos'**
  String get settingsRawFrames;

  /// No description provided for @settingsRawFramesHint.
  ///
  /// In es, this message translates to:
  /// **'Déjalo encendido. Guarda 30 días de frames crudos para diagnosticar y reinterpretar lecturas recientes si aparece que un offset del protocolo estaba mal leído. Los más viejos se borran solos.'**
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
  /// **'Lecturas (CSV)'**
  String get exportReadings;

  /// No description provided for @exportFrames.
  ///
  /// In es, this message translates to:
  /// **'Frames crudos (hex)'**
  String get exportFrames;

  /// No description provided for @exportTrack.
  ///
  /// In es, this message translates to:
  /// **'Recorrido (GPX)'**
  String get exportTrack;

  /// No description provided for @exportDone.
  ///
  /// In es, this message translates to:
  /// **'Listo para compartir: {path}'**
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
  /// **'La app no está en ninguna tienda, así que se actualiza desde las releases de GitHub. Comprueba una vez al día si hay versión nueva y te pregunta; nunca descarga nada sin que lo pidas.'**
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

  /// No description provided for @offlineSeeTrips.
  ///
  /// In es, this message translates to:
  /// **'Ver los {count} viajes'**
  String offlineSeeTrips(String count);

  /// No description provided for @offlineNoTrips.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay viajes guardados de esta batería.'**
  String get offlineNoTrips;

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
  /// **'Tomado de la configuración del BMS, que es un número sobre este pack pero lo escribió quien lo armó. Mientras venga de ahí, la app no lo trata como lo anunciado: no compara con él lo que mide, y la autonomía con el pack lleno dice de dónde sale. Si te lo vendieron con otra capacidad, ponla.'**
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
  /// **'Desgaste medido'**
  String get offlineMeasuredHealth;

  /// No description provided for @offlineImplied.
  ///
  /// In es, this message translates to:
  /// **'Capacidad configurada en el BMS'**
  String get offlineImplied;

  /// No description provided for @offlineImpliedHint.
  ///
  /// In es, this message translates to:
  /// **'Es un ajuste dentro del BMS, no una medición de las celdas. Es contra lo que se escala cada porcentaje que reporta la batería, así que vale la pena verlo, y se queda igual por muy cansada que esté la batería.'**
  String get offlineImpliedHint;

  /// No description provided for @offlineImpliedUnusable.
  ///
  /// In es, this message translates to:
  /// **'Solo se puede leer entre un {min} % y un {max} % de carga.'**
  String offlineImpliedUnusable(String min, String max);

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
  /// **'Celda más baja en reposo'**
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

  /// No description provided for @connectLinkNeverCameUp.
  ///
  /// In es, this message translates to:
  /// **'No se pudo levantar la conexión Bluetooth con la batería en 25 segundos, y la app lo intentó más de una vez. Comprueba que la batería esté encendida y cerca, y que la app oficial de tu BMS esté cerrada del todo, no solo en segundo plano.'**
  String get connectLinkNeverCameUp;

  /// No description provided for @connectSilent.
  ///
  /// In es, this message translates to:
  /// **'Conectó pero no llegaron lecturas. Si elegiste la marca, prueba con la otra.'**
  String get connectSilent;

  /// No description provided for @connectTalkingUndecoded.
  ///
  /// In es, this message translates to:
  /// **'Se conectó y están llegando bytes, pero ninguno se decodifica como un frame JK. Abre la consola con el icono de terminal de arriba: lo que aparezca ahí es lo que hace falta para añadir soporte.'**
  String get connectTalkingUndecoded;

  /// No description provided for @antEvidence.
  ///
  /// In es, this message translates to:
  /// **'ANT: {status} de estado, {info} de info, {rejected} rechazadas'**
  String antEvidence(int status, int info, int rejected);

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
  /// **'Toda la base de datos en un archivo, y de vuelta. Las exportaciones a CSV y GPX son para leer los datos en otro sitio; esto es para no perderlos. Trae de vuelta las baterías, los viajes con su recorrido, las pruebas de capacidad, el mantenimiento, las inspecciones, el registro de la conexión y las lecturas tal como están guardadas en el teléfono: completas las del último mes y una por minuto las más viejas. Los frames crudos solo se guardan 30 días, así que la copia lleva como mucho esos. También lleva tus ajustes de alertas, carga, viajes y pantalla. No lleva la licencia ni el token de actualizaciones, que son de este teléfono.'**
  String get backupIntro;

  /// No description provided for @backupExport.
  ///
  /// In es, this message translates to:
  /// **'Guardar copia de todo'**
  String get backupExport;

  /// No description provided for @backupExportLight.
  ///
  /// In es, this message translates to:
  /// **'Guardar copia más pequeña, sin frames crudos'**
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
  /// **'Objetivo de carga'**
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
  /// **'La batería llegó al {soc} %, según el BMS'**
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
  /// **'Mientras la app está en segundo plano Android corta la conexión Bluetooth a los pocos minutos. Con esto activado, en cuanto detecta que estás cargando levanta un servicio en primer plano y mantiene la conexión, y si se corta sigue intentando reconectar hasta que la carga termina, que es lo que hace falta para que los avisos lleguen de noche. No funciona si cierras la app deslizándola. Cuesta batería del teléfono mientras dura.'**
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

  /// No description provided for @alertSilence.
  ///
  /// In es, this message translates to:
  /// **'Silenciar este aviso'**
  String get alertSilence;

  /// No description provided for @alertSilenced.
  ///
  /// In es, this message translates to:
  /// **'Silenciado. Puedes volver a activarlo en Ajustes.'**
  String get alertSilenced;

  /// No description provided for @alertsSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Qué avisos quieres'**
  String get alertsSectionTitle;

  /// No description provided for @alertsSectionHint.
  ///
  /// In es, this message translates to:
  /// **'Cada uno por separado. Apagar el que te molesta no debería costarte los que sí quieres.'**
  String get alertsSectionHint;

  /// No description provided for @autoTripTitle.
  ///
  /// In es, this message translates to:
  /// **'Grabar viajes solo'**
  String get autoTripTitle;

  /// No description provided for @autoTripHint.
  ///
  /// In es, this message translates to:
  /// **'Abre el viaje cuando el pack consume y el GPS dice que te mueves, las dos cosas durante unos 20 segundos (si sales a paso de peatón, espera a que pases de 6 km/h), y lo cierra tras unos tres minutos quieto. Lo que recorras antes de que se abra no se graba. Si lo apagas, la app solo aprende tu autonomía de los viajes que empieces a mano, y los que se olvidan no son al azar: son los cortos y los que llevabas prisa.'**
  String get autoTripHint;

  /// No description provided for @autoTripStarted.
  ///
  /// In es, this message translates to:
  /// **'Viaje iniciado solo'**
  String get autoTripStarted;

  /// No description provided for @autoTripStopped.
  ///
  /// In es, this message translates to:
  /// **'Viaje guardado'**
  String get autoTripStopped;

  /// No description provided for @degNowTitle.
  ///
  /// In es, this message translates to:
  /// **'Capacidad ahora'**
  String get degNowTitle;

  /// No description provided for @degBaseline.
  ///
  /// In es, this message translates to:
  /// **'La mejor que ha dado'**
  String get degBaseline;

  /// No description provided for @degBaselineOn.
  ///
  /// In es, this message translates to:
  /// **'medida el {date}'**
  String degBaselineOn(String date);

  /// No description provided for @degLost.
  ///
  /// In es, this message translates to:
  /// **'Degradación'**
  String get degLost;

  /// No description provided for @degLostUnknown.
  ///
  /// In es, this message translates to:
  /// **'aún no medible'**
  String get degLostUnknown;

  /// No description provided for @degLostWhy.
  ///
  /// In es, this message translates to:
  /// **'La degradación se mide contra lo mejor que ha dado esta batería, no contra lo que decía el anuncio. Hace falta más de una medición: con una sola tienes una capacidad, no una pérdida.'**
  String get degLostWhy;

  /// No description provided for @degImpliedNote.
  ///
  /// In es, this message translates to:
  /// **'Estimada del contador del BMS, no medida. Un test de capacidad da la cifra de verdad.'**
  String get degImpliedNote;

  /// No description provided for @degSoldTitle.
  ///
  /// In es, this message translates to:
  /// **'Frente a lo anunciado'**
  String get degSoldTitle;

  /// No description provided for @degSoldShort.
  ///
  /// In es, this message translates to:
  /// **'Se vendió como {sold} Ah y lo mejor que ha medido son {real} Ah: alrededor de un {pct} % menos de lo anunciado. Si esa medición se hizo con el pack nuevo, no es desgaste: es que nunca fueron {sold}.'**
  String degSoldShort(String sold, String real, String pct);

  /// No description provided for @degSoldOk.
  ///
  /// In es, this message translates to:
  /// **'Lo mejor que ha medido está a la altura de lo que se anunció.'**
  String get degSoldOk;

  /// No description provided for @demoSetCharge.
  ///
  /// In es, this message translates to:
  /// **'Poner la carga a'**
  String get demoSetCharge;

  /// No description provided for @demoFull.
  ///
  /// In es, this message translates to:
  /// **'Llenar al 100 %'**
  String get demoFull;

  /// No description provided for @demoEmpty.
  ///
  /// In es, this message translates to:
  /// **'Vaciar al 10 %'**
  String get demoEmpty;

  /// No description provided for @demoSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad del simulador'**
  String get demoSpeed;

  /// No description provided for @demoSpeedHint.
  ///
  /// In es, this message translates to:
  /// **'Acelera el tiempo del pack simulado. Un test de capacidad es una descarga entera: a velocidad normal son horas, y una función que tarda una tarde en llegar no se puede juzgar. La distancia y el GPS no se aceleran, así que el consumo aprendido sigue siendo realista.'**
  String get demoSpeedHint;

  /// No description provided for @demoSpeedNormal.
  ///
  /// In es, this message translates to:
  /// **'normal'**
  String get demoSpeedNormal;

  /// No description provided for @etaFull.
  ///
  /// In es, this message translates to:
  /// **'Lleno en aprox.'**
  String get etaFull;

  /// No description provided for @etaTapering.
  ///
  /// In es, this message translates to:
  /// **'ya va bajando la corriente, y el final tarda más'**
  String get etaTapering;

  /// No description provided for @etaDone.
  ///
  /// In es, this message translates to:
  /// **'Está lleno'**
  String get etaDone;

  /// No description provided for @etaCannotSay.
  ///
  /// In es, this message translates to:
  /// **'No puedo decirlo'**
  String get etaCannotSay;

  /// No description provided for @etaCounterAhead.
  ///
  /// In es, this message translates to:
  /// **'el contador va por delante de las celdas, así que no doy minutos'**
  String get etaCounterAhead;

  /// No description provided for @socNoteAhead.
  ///
  /// In es, this message translates to:
  /// **'el contador va por delante de las celdas'**
  String get socNoteAhead;

  /// No description provided for @socNoteBehind.
  ///
  /// In es, this message translates to:
  /// **'queda más de lo que dice'**
  String get socNoteBehind;

  /// No description provided for @adviceDeepestSoFar.
  ///
  /// In es, this message translates to:
  /// **'Lo más hondo hasta ahora: del {from} % al {to} %.'**
  String adviceDeepestSoFar(String from, String to);

  /// No description provided for @adviceDeepestNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no se ha registrado ninguna descarga.'**
  String get adviceDeepestNone;

  /// No description provided for @linkLostTitle.
  ///
  /// In es, this message translates to:
  /// **'Se perdió la conexión'**
  String get linkLostTitle;

  /// No description provided for @linkLostBody.
  ///
  /// In es, this message translates to:
  /// **'Estás fuera del alcance de la batería, o algo más tiene tomado el canal Bluetooth. Sigue reintentando solo; lo que ves en pantalla es la última lectura.'**
  String get linkLostBody;

  /// No description provided for @linkReconnectingTitle.
  ///
  /// In es, this message translates to:
  /// **'Reconectando'**
  String get linkReconnectingTitle;

  /// No description provided for @linkConnectingTitle.
  ///
  /// In es, this message translates to:
  /// **'Conectando'**
  String get linkConnectingTitle;

  /// No description provided for @linkGaveUpTitle.
  ///
  /// In es, this message translates to:
  /// **'No pude reconectar'**
  String get linkGaveUpTitle;

  /// No description provided for @linkGaveUpBody.
  ///
  /// In es, this message translates to:
  /// **'Me detuve tras {attempts} intentos. Cada intento fallido consume recursos Bluetooth de todo el teléfono, así que no sigue solo.'**
  String linkGaveUpBody(String attempts);

  /// No description provided for @linkRetryNow.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get linkRetryNow;

  /// No description provided for @linkReadingAge.
  ///
  /// In es, this message translates to:
  /// **'Última lectura hace {age}'**
  String linkReadingAge(String age);

  /// No description provided for @linkStaleTitle.
  ///
  /// In es, this message translates to:
  /// **'Conectado, pero sin lecturas'**
  String get linkStaleTitle;

  /// No description provided for @linkStaleBody.
  ///
  /// In es, this message translates to:
  /// **'El enlace está arriba y la batería no manda nada que la app pueda leer. Lo que ves es la última lectura, no la actual. Si sigue así unos segundos más, la app suelta la conexión y vuelve a entrar.'**
  String get linkStaleBody;

  /// No description provided for @linkBack.
  ///
  /// In es, this message translates to:
  /// **'Leyendo otra vez'**
  String get linkBack;

  /// No description provided for @linkDetails.
  ///
  /// In es, this message translates to:
  /// **'Detalles'**
  String get linkDetails;

  /// No description provided for @troubleBusy.
  ///
  /// In es, this message translates to:
  /// **'Algo más ya está conectado a la batería. El BMS acepta una sola conexión Bluetooth a la vez, así que cierra la app oficial de tu BMS o cualquier otro registrador.'**
  String get troubleBusy;

  /// No description provided for @troubleOutOfRange.
  ///
  /// In es, this message translates to:
  /// **'La batería no respondió. O está fuera de alcance o apagada, o algo más tiene tomada su única conexión Bluetooth: la app oficial de tu BMS, u otro registrador.'**
  String get troubleOutOfRange;

  /// No description provided for @troubleBluetoothOff.
  ///
  /// In es, this message translates to:
  /// **'El Bluetooth del teléfono está apagado.'**
  String get troubleBluetoothOff;

  /// No description provided for @troublePermission.
  ///
  /// In es, this message translates to:
  /// **'La app no tiene permiso para usar Bluetooth. Concede Dispositivos cercanos en los ajustes de Android.'**
  String get troublePermission;

  /// No description provided for @troubleLocationOff.
  ///
  /// In es, this message translates to:
  /// **'La ubicación del teléfono está apagada. Android la necesita encendida para buscar dispositivos Bluetooth.'**
  String get troubleLocationOff;

  /// No description provided for @troubleGeneric.
  ///
  /// In es, this message translates to:
  /// **'Problema de Bluetooth. Sigue reintentando solo.'**
  String get troubleGeneric;

  /// No description provided for @troubleSlowFrames.
  ///
  /// In es, this message translates to:
  /// **'El teléfono concedió un tamaño de paquete Bluetooth menor del pedido. Las lecturas llegan en más trozos, lo que es más lento pero igual de correcto.'**
  String get troubleSlowFrames;

  /// No description provided for @troubleNotJkBms.
  ///
  /// In es, this message translates to:
  /// **'Ese dispositivo no tiene el servicio Bluetooth que usan los BMS compatibles. No es un BMS compatible, o no uno con el que esta app pueda hablar.'**
  String get troubleNotJkBms;

  /// No description provided for @troublePackMute.
  ///
  /// In es, this message translates to:
  /// **'La batería estuvo conectada pero muda: en 20 segundos no mandó nada que la app pudiera leer, pese a pedírselo varias veces. La app soltó la conexión a propósito y vuelve a entrar en unos segundos; es la única forma de que el módulo Bluetooth del BMS suelte la sesión que se le quedó colgada. En Detalles dice cuántos bytes llegaron.'**
  String get troublePackMute;

  /// No description provided for @screenAwakeTitle.
  ///
  /// In es, this message translates to:
  /// **'Mantener la pantalla encendida'**
  String get screenAwakeTitle;

  /// No description provided for @screenAwakeHint.
  ///
  /// In es, this message translates to:
  /// **'Antes se quedaba encendida todo el tiempo que esta pantalla estuviera abierta, lo cual está bien en un soporte de moto y mal en el sofá.'**
  String get screenAwakeHint;

  /// No description provided for @screenAwakeNever.
  ///
  /// In es, this message translates to:
  /// **'Nunca'**
  String get screenAwakeNever;

  /// No description provided for @screenAwakeRiding.
  ///
  /// In es, this message translates to:
  /// **'Mientras ruedas'**
  String get screenAwakeRiding;

  /// No description provided for @screenAwakeAlways.
  ///
  /// In es, this message translates to:
  /// **'Siempre'**
  String get screenAwakeAlways;

  /// No description provided for @linkWatchNotifTitle.
  ///
  /// In es, this message translates to:
  /// **'Leyendo la batería'**
  String get linkWatchNotifTitle;

  /// No description provided for @linkWatchNotifWaiting.
  ///
  /// In es, this message translates to:
  /// **'Esperando la primera lectura'**
  String get linkWatchNotifWaiting;

  /// No description provided for @linkWatchNotifText.
  ///
  /// In es, this message translates to:
  /// **'{soc} %  ·  {volts} V  ·  {amps} A'**
  String linkWatchNotifText(String soc, String volts, String amps);

  /// No description provided for @linkWatchTitle.
  ///
  /// In es, this message translates to:
  /// **'Seguir leyendo con la pantalla apagada'**
  String get linkWatchTitle;

  /// No description provided for @linkWatchHint.
  ///
  /// In es, this message translates to:
  /// **'Android deja de entregarle lecturas Bluetooth a una app poco después de que la pantalla se apaga, a menos que la app mantenga un servicio en primer plano. Esto lo mantiene mientras la batería está conectada, y también mientras intenta recuperar la conexión si se corta, para que la app funcione igual con la pantalla encendida o apagada. Para eso es la notificación; no es la app anunciándose. Si cierras la app deslizándola, deja de leer.'**
  String get linkWatchHint;

  /// No description provided for @screenAwakeReason.
  ///
  /// In es, this message translates to:
  /// **'Con el ajuste de arriba encendido, la pantalla puede apagarse sin que las lecturas se detengan.'**
  String get screenAwakeReason;

  /// No description provided for @backupScope.
  ///
  /// In es, this message translates to:
  /// **'Todas las baterías, no solo la conectada: {packs} baterías, {trips} viajes, {readings} lecturas.'**
  String backupScope(String packs, String trips, String readings);

  /// No description provided for @backupScopeEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay nada guardado, así que no hay nada que copiar.'**
  String get backupScopeEmpty;

  /// No description provided for @downloadNotifTitle.
  ///
  /// In es, this message translates to:
  /// **'Descargando actualización'**
  String get downloadNotifTitle;

  /// No description provided for @downloadNotifText.
  ///
  /// In es, this message translates to:
  /// **'{percent} %'**
  String downloadNotifText(String percent);

  /// No description provided for @learnWhyTitle.
  ///
  /// In es, this message translates to:
  /// **'Por qué no ha aprendido nada'**
  String get learnWhyTitle;

  /// No description provided for @learnWhyCount.
  ///
  /// In es, this message translates to:
  /// **'{used} de {considered} viajes grabados eran utilizables.'**
  String learnWhyCount(String used, String considered);

  /// No description provided for @learnWhyShort.
  ///
  /// In es, this message translates to:
  /// **'{n} fueron de menos de 200 m, demasiado corto para dividir: un temblor del GPS en esa distancia produce un consumo de cientos de Wh/km.'**
  String learnWhyShort(String n);

  /// No description provided for @learnWhyNoEnergy.
  ///
  /// In es, this message translates to:
  /// **'{n} se midieron, pero no salió energía neta de la batería. O fueron en remolque o casi todo cuesta abajo, o la batería reporta su corriente con el signo contrario al que esta app asume.'**
  String learnWhyNoEnergy(String n);

  /// No description provided for @learnWhySignWarning.
  ///
  /// In es, this message translates to:
  /// **'Si es el signo, también estaría desactivando la energía de los viajes, el consumo y la detección de capacidad, mientras cada lectura en vivo sigue pareciendo correcta. Vale la pena comprobarlo: rodando, la corriente en la pantalla principal debería ser negativa.'**
  String get learnWhySignWarning;

  /// No description provided for @learnWhyNeedMore.
  ///
  /// In es, this message translates to:
  /// **'Aprende del primer viaje de más de 200 m que consuma energía. No hay nada más que hacer.'**
  String get learnWhyNeedMore;

  /// No description provided for @trendsIntro.
  ///
  /// In es, this message translates to:
  /// **'Cuatro gráficas, y de cada una lo que sirve es la pendiente, no la altura. Un número que se queda quieto es una batería sana; uno que se va para un lado durante meses es la batería diciéndote algo.'**
  String get trendsIntro;

  /// No description provided for @trendsConsumptionHint.
  ///
  /// In es, this message translates to:
  /// **'Un punto por viaje medido que cuenta para la autonomía: lo que costó por kilómetro. Lo mueven sobre todo la ruta, cómo manejas, el viento, la temperatura y las llantas, no la batería, así que no es una medida de desgaste: sirve para ver cómo vas gastando. Los viajes sin medir, los marcados como excepción y los de un consumo imposible no entran.'**
  String get trendsConsumptionHint;

  /// No description provided for @trendsCapacityHint.
  ///
  /// In es, this message translates to:
  /// **'Un punto por descarga completa medida, la más vieja a la izquierda: de celdas arriba a celda en el corte, vigilada entera y sin carga en medio. La altura es los amperios-hora que salieron esa vez. Es la única medida real de desgaste que hay aquí, y la más lenta en llenarse: espera que baje un poco cada año, y desconfía de una caída de golpe.'**
  String get trendsCapacityHint;

  /// No description provided for @trendsAxisTime.
  ///
  /// In es, this message translates to:
  /// **'a lo ancho, el tiempo: del más viejo al más nuevo, con los huecos donde no hubo datos'**
  String get trendsAxisTime;

  /// No description provided for @trendsAxisCharge.
  ///
  /// In es, this message translates to:
  /// **'de izquierda a derecha: de vacía a llena'**
  String get trendsAxisCharge;

  /// No description provided for @learnWhyImplausible.
  ///
  /// In es, this message translates to:
  /// **'{n} dieron un consumo que ninguna moto puede producir, así que se rechazaron. Eso fue un fallo de esta app y no algo del manejo, y está arreglado: los viajes grabados desde entonces deberían salir bien. Los viejos que conservan sus lecturas se pueden medir de nuevo con «Volver a medir» en su detalle.'**
  String learnWhyImplausible(String n);

  /// No description provided for @connectCouldNotSearch.
  ///
  /// In es, this message translates to:
  /// **'La radio nunca confirmó que la búsqueda empezara, así que en realidad no se buscó nada. Normalmente es el Bluetooth despertando justo al abrir la app. Prueba otra vez.'**
  String get connectCouldNotSearch;

  /// No description provided for @backupShare.
  ///
  /// In es, this message translates to:
  /// **'Enviar la copia pequeña, sin frames crudos, a otra app'**
  String get backupShare;

  /// No description provided for @backupSaveDialog.
  ///
  /// In es, this message translates to:
  /// **'Dónde guardar la copia'**
  String get backupSaveDialog;

  /// No description provided for @backupSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardada como {name}.'**
  String backupSaved(String name);

  /// No description provided for @rangeFull.
  ///
  /// In es, this message translates to:
  /// **'Con la batería llena'**
  String get rangeFull;

  /// No description provided for @rangeFullBand.
  ///
  /// In es, this message translates to:
  /// **'unos {low} a {high} km'**
  String rangeFullBand(String low, String high);

  /// No description provided for @rangeFullUnknown.
  ///
  /// In es, this message translates to:
  /// **'Hace falta una capacidad medida para poder decir esto.'**
  String get rangeFullUnknown;

  /// No description provided for @rangeFullFromAdvert.
  ///
  /// In es, this message translates to:
  /// **'Sale de la capacidad que pusiste tú, no de una medida.'**
  String get rangeFullFromAdvert;

  /// No description provided for @rangeFullFromMeasured.
  ///
  /// In es, this message translates to:
  /// **'Sale de una descarga completa medida en esta batería, de celdas arriba a celda en el corte.'**
  String get rangeFullFromMeasured;

  /// No description provided for @rangeNoneLearned.
  ///
  /// In es, this message translates to:
  /// **'Todavía no ha aprendido nada, así que no hay distancia que valga la pena decir, a ninguna carga.'**
  String get rangeNoneLearned;

  /// No description provided for @offlineRangeAtLastSeen.
  ///
  /// In es, this message translates to:
  /// **'Con la carga de la última lectura'**
  String get offlineRangeAtLastSeen;

  /// No description provided for @offlineHealthNeedsTests.
  ///
  /// In es, this message translates to:
  /// **'Hacen falta dos descargas completas para poder medir desgaste. Una da una capacidad; hacen falta dos para ver una caída.'**
  String get offlineHealthNeedsTests;

  /// No description provided for @offlineHealthOneTest.
  ///
  /// In es, this message translates to:
  /// **'Una medición hasta ahora: {ah} Ah. La segunda, dentro de unos meses, es la que la convierte en desgaste.'**
  String offlineHealthOneTest(String ah);

  /// No description provided for @systemDrops.
  ///
  /// In es, this message translates to:
  /// **'Caídas del enlace'**
  String get systemDrops;

  /// No description provided for @systemTimeDisconnected.
  ///
  /// In es, this message translates to:
  /// **'Tiempo desconectado'**
  String get systemTimeDisconnected;

  /// No description provided for @systemNudges.
  ///
  /// In es, this message translates to:
  /// **'Veces que hubo que insistirle'**
  String get systemNudges;

  /// No description provided for @systemNudgesHint.
  ///
  /// In es, this message translates to:
  /// **'La app solo le escribe a la batería cuando lleva seis segundos sin hablar. Antes escribía cada cinco segundos sin importar nada, y eso es lo que parece interrumpir el flujo. Si esto se queda cerca de cero en un viaje con lecturas continuas, esa era la causa.'**
  String get systemNudgesHint;

  /// No description provided for @settingsSectionRides.
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get settingsSectionRides;

  /// No description provided for @settingsSectionLink.
  ///
  /// In es, this message translates to:
  /// **'Conexión y pantalla'**
  String get settingsSectionLink;

  /// No description provided for @settingsSectionLinkHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que mantiene a la app leyendo. Estos dos van juntos: si se mantiene la conexión abierta, la pantalla puede dormirse.'**
  String get settingsSectionLinkHint;

  /// No description provided for @offlineRangeStale.
  ///
  /// In es, this message translates to:
  /// **'Esa lectura tiene {age}, así que esto es un recuerdo y no una cifra: la batería puede haberse usado o haber estado ahí parada desde entonces.'**
  String offlineRangeStale(String age);

  /// No description provided for @licenseTitle.
  ///
  /// In es, this message translates to:
  /// **'Licencia'**
  String get licenseTitle;

  /// No description provided for @licenseStatusFree.
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get licenseStatusFree;

  /// No description provided for @licenseStatusTrial.
  ///
  /// In es, this message translates to:
  /// **'Prueba Pro'**
  String get licenseStatusTrial;

  /// No description provided for @licenseStatusPro.
  ///
  /// In es, this message translates to:
  /// **'Pro'**
  String get licenseStatusPro;

  /// No description provided for @licenseStatusWorkshop.
  ///
  /// In es, this message translates to:
  /// **'Pro Taller'**
  String get licenseStatusWorkshop;

  /// No description provided for @licenseStatusWorkshopExpired.
  ///
  /// In es, this message translates to:
  /// **'Taller vencido'**
  String get licenseStatusWorkshopExpired;

  /// No description provided for @licenseTrialLeft.
  ///
  /// In es, this message translates to:
  /// **'Quedan {days} días de prueba con todo lo Pro. Después la app sigue funcionando: el visor en vivo completo, gratis y para siempre.'**
  String licenseTrialLeft(String days);

  /// No description provided for @licenseFreeBody.
  ///
  /// In es, this message translates to:
  /// **'Visor completo en vivo y las últimas 24 horas de historial, gratis. Lo demás (historial ilimitado, degradación, veredictos, vigilar la carga toda la noche, copia de seguridad) es Pro: un pago único, de por vida, para este teléfono.'**
  String get licenseFreeBody;

  /// No description provided for @licenseProBody.
  ///
  /// In es, this message translates to:
  /// **'Pro activo en este teléfono. Pago único, sin caducidad.'**
  String get licenseProBody;

  /// No description provided for @licenseWorkshopBody.
  ///
  /// In es, this message translates to:
  /// **'Pro Taller activo hasta el {date}.'**
  String licenseWorkshopBody(String date);

  /// No description provided for @licenseWorkshopNoEnd.
  ///
  /// In es, this message translates to:
  /// **'Pro Taller activo.'**
  String get licenseWorkshopNoEnd;

  /// No description provided for @licenseWorkshopExpiredBody.
  ///
  /// In es, this message translates to:
  /// **'La licencia de Taller venció. La app volvió al nivel gratis; renueva para recuperar lo Pro.'**
  String get licenseWorkshopExpiredBody;

  /// No description provided for @licenseCreditsLeft.
  ///
  /// In es, this message translates to:
  /// **'Chequeos disponibles: {count}'**
  String licenseCreditsLeft(String count);

  /// No description provided for @licenseCertificatesLeft.
  ///
  /// In es, this message translates to:
  /// **'Certificados disponibles: {count}'**
  String licenseCertificatesLeft(String count);

  /// No description provided for @licenseLabel.
  ///
  /// In es, this message translates to:
  /// **'A nombre de {label}'**
  String licenseLabel(String label);

  /// No description provided for @licenseDeviceCode.
  ///
  /// In es, this message translates to:
  /// **'Código de este teléfono'**
  String get licenseDeviceCode;

  /// No description provided for @licenseDeviceCodeHint.
  ///
  /// In es, this message translates to:
  /// **'La clave va atada a este código. Mándalo junto con el comprobante de pago y recibirás una clave para pegar aquí. Se comprueba en el teléfono, sin internet.'**
  String get licenseDeviceCodeHint;

  /// No description provided for @licenseCopyCode.
  ///
  /// In es, this message translates to:
  /// **'Copiar código'**
  String get licenseCopyCode;

  /// No description provided for @licenseCopied.
  ///
  /// In es, this message translates to:
  /// **'Copiado'**
  String get licenseCopied;

  /// No description provided for @licenseCopyRequest.
  ///
  /// In es, this message translates to:
  /// **'Copiar mensaje de solicitud'**
  String get licenseCopyRequest;

  /// No description provided for @licenseRequestMessage.
  ///
  /// In es, this message translates to:
  /// **'Hola, quiero activar JK BMS + Pro.\nCódigo del teléfono: {code}\nVersión de la app: {version}'**
  String licenseRequestMessage(String code, String version);

  /// No description provided for @licensePasteTitle.
  ///
  /// In es, this message translates to:
  /// **'Pegar clave'**
  String get licensePasteTitle;

  /// No description provided for @licensePasteHint.
  ///
  /// In es, this message translates to:
  /// **'Pega la clave completa, desde JKB1 hasta el final. Los saltos de línea del chat no importan.'**
  String get licensePasteHint;

  /// No description provided for @licenseActivate.
  ///
  /// In es, this message translates to:
  /// **'Activar'**
  String get licenseActivate;

  /// No description provided for @licenseActivated.
  ///
  /// In es, this message translates to:
  /// **'Clave activada.'**
  String get licenseActivated;

  /// No description provided for @licenseAlreadyActive.
  ///
  /// In es, this message translates to:
  /// **'Esa clave ya estaba activada en este teléfono.'**
  String get licenseAlreadyActive;

  /// No description provided for @licenseRejectedMalformed.
  ///
  /// In es, this message translates to:
  /// **'Eso no es una clave. Revisa que la copiaste completa, de JKB1 hasta el final.'**
  String get licenseRejectedMalformed;

  /// No description provided for @licenseRejectedSignature.
  ///
  /// In es, this message translates to:
  /// **'La clave no es válida: o le falta un carácter, o no fue emitida por el autor.'**
  String get licenseRejectedSignature;

  /// No description provided for @licenseRejectedDevice.
  ///
  /// In es, this message translates to:
  /// **'Esta clave es de otro teléfono. Cada clave va atada al código del teléfono que la pidió.'**
  String get licenseRejectedDevice;

  /// No description provided for @licenseRejectedExpired.
  ///
  /// In es, this message translates to:
  /// **'Esta clave ya venció.'**
  String get licenseRejectedExpired;

  /// No description provided for @licenseNotConfigured.
  ///
  /// In es, this message translates to:
  /// **'Esta compilación no lleva clave pública de licencias y no puede activar ninguna. Es una compilación de desarrollo; ver docs/LICENSING.md.'**
  String get licenseNotConfigured;

  /// No description provided for @licenseActiveKeys.
  ///
  /// In es, this message translates to:
  /// **'Claves en este teléfono'**
  String get licenseActiveKeys;

  /// No description provided for @licenseKeyActivated.
  ///
  /// In es, this message translates to:
  /// **'Activada el {date}'**
  String licenseKeyActivated(String date);

  /// No description provided for @licenseKeyExpires.
  ///
  /// In es, this message translates to:
  /// **'Vence el {date}'**
  String licenseKeyExpires(String date);

  /// No description provided for @licenseKeyExpired.
  ///
  /// In es, this message translates to:
  /// **'Venció el {date}'**
  String licenseKeyExpired(String date);

  /// No description provided for @licenseKeyCredits.
  ///
  /// In es, this message translates to:
  /// **'{inspections} chequeos, {certificates} certificados'**
  String licenseKeyCredits(String inspections, String certificates);

  /// No description provided for @licenseRemoveKey.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get licenseRemoveKey;

  /// No description provided for @licenseRemoveConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar esta clave?'**
  String get licenseRemoveConfirmTitle;

  /// No description provided for @licenseRemoveConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'La app pierde lo que esta clave desbloquea. La clave sigue siendo válida: si la guardaste, puedes pegarla otra vez.'**
  String get licenseRemoveConfirmBody;

  /// No description provided for @licenseWhyTitle.
  ///
  /// In es, this message translates to:
  /// **'Por qué se cobra'**
  String get licenseWhyTitle;

  /// No description provided for @licenseWhyBody.
  ///
  /// In es, this message translates to:
  /// **'Lo gratis iguala a la app oficial de tu BMS y no se recorta nunca. Lo Pro es lo que esa app no puede hacer por diseño: recordar, comparar y concluir. Un pago único; nada de suscripciones. Sin cuenta, sin servidor y sin internet: la clave se comprueba en el teléfono con la firma del autor.'**
  String get licenseWhyBody;

  /// No description provided for @licenseOpen.
  ///
  /// In es, this message translates to:
  /// **'Ver licencia'**
  String get licenseOpen;

  /// No description provided for @proBadge.
  ///
  /// In es, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @proGateTitle.
  ///
  /// In es, this message translates to:
  /// **'Función Pro'**
  String get proGateTitle;

  /// No description provided for @proGateBody.
  ///
  /// In es, this message translates to:
  /// **'{feature} es parte de Pro. Un pago único, de por vida, para este teléfono.'**
  String proGateBody(String feature);

  /// No description provided for @proGateTrialEnded.
  ///
  /// In es, this message translates to:
  /// **'La prueba de 7 días terminó.'**
  String get proGateTrialEnded;

  /// No description provided for @proFeatureHistory.
  ///
  /// In es, this message translates to:
  /// **'El historial de más de 24 horas'**
  String get proFeatureHistory;

  /// No description provided for @proFeatureDegradation.
  ///
  /// In es, this message translates to:
  /// **'La degradación y las curvas a largo plazo'**
  String get proFeatureDegradation;

  /// No description provided for @proFeatureVerdicts.
  ///
  /// In es, this message translates to:
  /// **'Los veredictos sobre el estado del pack'**
  String get proFeatureVerdicts;

  /// No description provided for @proFeatureBackgroundAlerts.
  ///
  /// In es, this message translates to:
  /// **'Vigilar la carga toda la noche, sin dejar de reconectar si la conexión se corta'**
  String get proFeatureBackgroundAlerts;

  /// No description provided for @proFeatureBackup.
  ///
  /// In es, this message translates to:
  /// **'La copia de seguridad y su restauración'**
  String get proFeatureBackup;

  /// No description provided for @proFeatureConfigAudit.
  ///
  /// In es, this message translates to:
  /// **'La auditoría de la configuración del BMS'**
  String get proFeatureConfigAudit;

  /// No description provided for @proFeatureBatteryReport.
  ///
  /// In es, this message translates to:
  /// **'El informe PDF de la batería'**
  String get proFeatureBatteryReport;

  /// No description provided for @proFeatureInspection.
  ///
  /// In es, this message translates to:
  /// **'La inspección rápida de otra batería'**
  String get proFeatureInspection;

  /// No description provided for @proFeatureCertificate.
  ///
  /// In es, this message translates to:
  /// **'El certificado de vendedor'**
  String get proFeatureCertificate;

  /// No description provided for @proFeatureWorkshop.
  ///
  /// In es, this message translates to:
  /// **'Las funciones de taller'**
  String get proFeatureWorkshop;

  /// No description provided for @historyOlderLocked.
  ///
  /// In es, this message translates to:
  /// **'{count} viajes de más de 24 horas no se muestran. Verlos es Pro.'**
  String historyOlderLocked(String count);

  /// No description provided for @chargeWatchProHint.
  ///
  /// In es, this message translates to:
  /// **'Es Pro: requiere licencia para vigilar la carga toda la noche, reconectando si se corta. Seguir leyendo con la pantalla apagada es gratis.'**
  String get chargeWatchProHint;

  /// No description provided for @licenseStatusAdmin.
  ///
  /// In es, this message translates to:
  /// **'Admin'**
  String get licenseStatusAdmin;

  /// No description provided for @licenseAdminBody.
  ///
  /// In es, this message translates to:
  /// **'Acceso total en este teléfono: todo desbloqueado, sin límites ni caducidad.'**
  String get licenseAdminBody;

  /// No description provided for @adviceWhy.
  ///
  /// In es, this message translates to:
  /// **'POR QUÉ'**
  String get adviceWhy;

  /// No description provided for @adviceWhyHide.
  ///
  /// In es, this message translates to:
  /// **'OCULTAR'**
  String get adviceWhyHide;

  /// No description provided for @adviceHonestyNote.
  ///
  /// In es, this message translates to:
  /// **'Cada frase se apoya en un dato: tócala para verlo. Los ciclos y la capacidad configurada del BMS se pueden editar desde su app oficial, así que aquí se contrastan con lo que la app mide por su cuenta siempre que puede.'**
  String get adviceHonestyNote;

  /// No description provided for @verdictHealthMeasuredTitle.
  ///
  /// In es, this message translates to:
  /// **'Capacidad frente a la mejor que ha dado'**
  String get verdictHealthMeasuredTitle;

  /// No description provided for @verdictHealthMeasuredBody.
  ///
  /// In es, this message translates to:
  /// **'Tu batería está al {pct} % de la mejor medición que ha hecho: {now} Ah en la última frente a {best} Ah, la mejor. Medido en descargas completas, no estimado.'**
  String verdictHealthMeasuredBody(String pct, String now, String best);

  /// No description provided for @verdictHealthNotMeasurableTitle.
  ///
  /// In es, this message translates to:
  /// **'El desgaste todavía no se puede medir'**
  String get verdictHealthNotMeasurableTitle;

  /// No description provided for @verdictHealthNotMeasurableBody.
  ///
  /// In es, this message translates to:
  /// **'Hay {count} descarga(s) completa(s) medidas. Hacen falta dos para hablar de pérdida: una da una capacidad, no una caída. La app toma la siguiente sola cuando ocurra.'**
  String verdictHealthNotMeasurableBody(String count);

  /// No description provided for @verdictCellDriftingTitle.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} se está separando del resto'**
  String verdictCellDriftingTitle(String cell);

  /// No description provided for @verdictCellDriftingBody.
  ///
  /// In es, this message translates to:
  /// **'En {days} días con lecturas en reposo se ha ido separando: va {dev} V por debajo de la media del pack y la tendencia es de unos {rate} V más al mes. Coherente con una celda en camino de irse. Revísala antes de que el pack se apague en la calle.'**
  String verdictCellDriftingBody(String days, String dev, String rate);

  /// No description provided for @verdictNoCellDriftingTitle.
  ///
  /// In es, this message translates to:
  /// **'Ninguna celda se está yendo'**
  String get verdictNoCellDriftingTitle;

  /// No description provided for @verdictNoCellDriftingBody.
  ///
  /// In es, this message translates to:
  /// **'En {days} días con lecturas en reposo, todas entre el 40 y el 80 % de carga, ninguna celda se separa del resto. La más baja, la {cell}, va {dev} V bajo la media y no empeora. Nada que hacer.'**
  String verdictNoCellDriftingBody(String days, String cell, String dev);

  /// No description provided for @verdictRangeNowTitle.
  ///
  /// In es, this message translates to:
  /// **'Te quedan ~{km} km con cómo tú manejas'**
  String verdictRangeNowTitle(String km);

  /// No description provided for @verdictRangeNowBody.
  ///
  /// In es, this message translates to:
  /// **'Sale de {wh} Wh/km aprendidos en {learned} km tuyos, aplicados a la energía que el pack puede entregar ahora. Es una estimación: cambia con el terreno, la carga y el acelerador.'**
  String verdictRangeNowBody(String wh, String learned);

  /// No description provided for @verdictDeltaNormalTitle.
  ///
  /// In es, this message translates to:
  /// **'Delta bajo carga normal'**
  String get verdictDeltaNormalTitle;

  /// No description provided for @verdictDeltaNormalBody.
  ///
  /// In es, this message translates to:
  /// **'Con carga fuerte el delta llega a {loaded} V, contra {rest} V en reposo. No hay nada resistivo que perseguir. Nada que hacer.'**
  String verdictDeltaNormalBody(String loaded, String rest);

  /// No description provided for @evidenceRestingDelta.
  ///
  /// In es, this message translates to:
  /// **'Delta en reposo (el más alto desde que se conectó)'**
  String get evidenceRestingDelta;

  /// No description provided for @evidenceLoadedDelta.
  ///
  /// In es, this message translates to:
  /// **'Delta bajo carga (el que alcanzaron varias lecturas desde que se conectó)'**
  String get evidenceLoadedDelta;

  /// No description provided for @evidenceWeakCellShare.
  ///
  /// In es, this message translates to:
  /// **'Lecturas en que la celda {cell} fue la más baja'**
  String evidenceWeakCellShare(String cell);

  /// No description provided for @evidenceReadingsInSession.
  ///
  /// In es, this message translates to:
  /// **'Lecturas que cuentan desde que se conectó'**
  String get evidenceReadingsInSession;

  /// No description provided for @evidenceReportedCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos según el BMS (dato editable)'**
  String get evidenceReportedCycles;

  /// No description provided for @evidenceEquivalentCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos equivalentes (Ah que contó el BMS entre la capacidad configurada)'**
  String get evidenceEquivalentCycles;

  /// No description provided for @evidenceReportedSoh.
  ///
  /// In es, this message translates to:
  /// **'SOH según el BMS'**
  String get evidenceReportedSoh;

  /// No description provided for @evidenceReportedSoc.
  ///
  /// In es, this message translates to:
  /// **'Carga según el BMS'**
  String get evidenceReportedSoc;

  /// No description provided for @evidenceSocFullAnchor.
  ///
  /// In es, this message translates to:
  /// **'Donde termina la carga (por celda)'**
  String get evidenceSocFullAnchor;

  /// No description provided for @evidenceSocEmptyAnchor.
  ///
  /// In es, this message translates to:
  /// **'Donde el BMS llama vacío (por celda)'**
  String get evidenceSocEmptyAnchor;

  /// No description provided for @evidenceLowestCell.
  ///
  /// In es, this message translates to:
  /// **'Celda más baja (celda {cell})'**
  String evidenceLowestCell(String cell);

  /// No description provided for @evidenceHighestCell.
  ///
  /// In es, this message translates to:
  /// **'Celda más alta (celda {cell})'**
  String evidenceHighestCell(String cell);

  /// No description provided for @evidenceImpliedCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad configurada en el BMS (editable)'**
  String get evidenceImpliedCapacity;

  /// No description provided for @evidenceCatalogueCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad anunciada'**
  String get evidenceCatalogueCapacity;

  /// No description provided for @evidenceCapacityTests.
  ///
  /// In es, this message translates to:
  /// **'Descargas completas medidas'**
  String get evidenceCapacityTests;

  /// No description provided for @evidenceHottestProbe.
  ///
  /// In es, this message translates to:
  /// **'Sonda más caliente'**
  String get evidenceHottestProbe;

  /// No description provided for @evidenceBalanceStart.
  ///
  /// In es, this message translates to:
  /// **'Voltaje de arranque del balanceador'**
  String get evidenceBalanceStart;

  /// No description provided for @evidenceCellOvp.
  ///
  /// In es, this message translates to:
  /// **'Límite de sobretensión por celda'**
  String get evidenceCellOvp;

  /// No description provided for @evidenceLearnedKm.
  ///
  /// In es, this message translates to:
  /// **'Kilómetros aprendidos'**
  String get evidenceLearnedKm;

  /// No description provided for @evidenceWhPerKm.
  ///
  /// In es, this message translates to:
  /// **'Consumo aprendido'**
  String get evidenceWhPerKm;

  /// No description provided for @evidenceUsableWh.
  ///
  /// In es, this message translates to:
  /// **'Energía aprovechable ahora'**
  String get evidenceUsableWh;

  /// No description provided for @evidenceStrandedFraction.
  ///
  /// In es, this message translates to:
  /// **'Energía atrapada sobre el corte'**
  String get evidenceStrandedFraction;

  /// No description provided for @evidenceRangeBand.
  ///
  /// In es, this message translates to:
  /// **'Banda de la estimación'**
  String get evidenceRangeBand;

  /// No description provided for @evidenceBaselineCapacity.
  ///
  /// In es, this message translates to:
  /// **'Lo mejor que ha dado ({date})'**
  String evidenceBaselineCapacity(String date);

  /// No description provided for @evidenceCurrentCapacity.
  ///
  /// In es, this message translates to:
  /// **'Última medición ({date})'**
  String evidenceCurrentCapacity(String date);

  /// No description provided for @evidenceDriftDeviation.
  ///
  /// In es, this message translates to:
  /// **'Celda {cell} bajo la media del pack'**
  String evidenceDriftDeviation(String cell);

  /// No description provided for @evidenceDriftRate.
  ///
  /// In es, this message translates to:
  /// **'Ritmo de separación'**
  String get evidenceDriftRate;

  /// No description provided for @evidencePerMonth.
  ///
  /// In es, this message translates to:
  /// **'mes'**
  String get evidencePerMonth;

  /// No description provided for @evidenceDriftSamples.
  ///
  /// In es, this message translates to:
  /// **'Lecturas en reposo analizadas'**
  String get evidenceDriftSamples;

  /// No description provided for @evidenceDriftDays.
  ///
  /// In es, this message translates to:
  /// **'Días con lecturas en reposo'**
  String get evidenceDriftDays;

  /// No description provided for @verdictTitle.
  ///
  /// In es, this message translates to:
  /// **'Veredicto'**
  String get verdictTitle;

  /// No description provided for @demoScenarioInspection.
  ///
  /// In es, this message translates to:
  /// **'Ensayo de inspección'**
  String get demoScenarioInspection;

  /// No description provided for @demoScenarioInspectionDesc.
  ///
  /// In es, this message translates to:
  /// **'35 s quieta, luces 20 s, tirón fuerte 8 s y suelta. La celda 7 es la débil.'**
  String get demoScenarioInspectionDesc;

  /// No description provided for @inspectionEntry.
  ///
  /// In es, this message translates to:
  /// **'Inspeccionar otra batería'**
  String get inspectionEntry;

  /// No description provided for @inspectionModeTitle.
  ///
  /// In es, this message translates to:
  /// **'Modo inspección'**
  String get inspectionModeTitle;

  /// No description provided for @inspectionModeBanner.
  ///
  /// In es, this message translates to:
  /// **'La batería que conectes ahora no se guarda en tu historial ni enseña nada a tu autonomía. Pide al vendedor que cierre su app JK y elige su BMS en la lista.'**
  String get inspectionModeBanner;

  /// No description provided for @inspectionModeExit.
  ///
  /// In es, this message translates to:
  /// **'Salir del modo inspección'**
  String get inspectionModeExit;

  /// No description provided for @inspectionRehearse.
  ///
  /// In es, this message translates to:
  /// **'Ensayar con el pack demo'**
  String get inspectionRehearse;

  /// No description provided for @inspectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Inspección rápida'**
  String get inspectionTitle;

  /// No description provided for @inspectionWaitingReadings.
  ///
  /// In es, this message translates to:
  /// **'Esperando lecturas del BMS…'**
  String get inspectionWaitingReadings;

  /// No description provided for @inspectionStepRestTitle.
  ///
  /// In es, this message translates to:
  /// **'No toques nada'**
  String get inspectionStepRestTitle;

  /// No description provided for @inspectionStepRestBody.
  ///
  /// In es, this message translates to:
  /// **'La app toma la foto en reposo. Que nadie acelere ni encienda nada.'**
  String get inspectionStepRestBody;

  /// No description provided for @inspectionStepLightTitle.
  ///
  /// In es, this message translates to:
  /// **'Enciende las luces'**
  String get inspectionStepLightTitle;

  /// No description provided for @inspectionStepLightBody.
  ///
  /// In es, this message translates to:
  /// **'Una carga pequeña y estable. La app avanza sola cuando la detecta.'**
  String get inspectionStepLightBody;

  /// No description provided for @inspectionStepHeavyTitle.
  ///
  /// In es, this message translates to:
  /// **'Ahora una carga fuerte'**
  String get inspectionStepHeavyTitle;

  /// No description provided for @inspectionStepHeavyBody.
  ///
  /// In es, this message translates to:
  /// **'Tres formas, cualquiera sirve: rodar 50 metros acelerando de verdad, o apretar el freno trasero en el caballete y abrir gas, o enchufar el cargador medio minuto. La rueda girando libre al aire NO sirve: el motor no tiene contra qué empujar y la corriente se queda casi en cero por mucho que gires el puño.'**
  String get inspectionStepHeavyBody;

  /// No description provided for @inspectionStepRecoveryTitle.
  ///
  /// In es, this message translates to:
  /// **'Suelta todo y espera'**
  String get inspectionStepRecoveryTitle;

  /// No description provided for @inspectionStepRecoveryBody.
  ///
  /// In es, this message translates to:
  /// **'Sin corriente. La app mira cuánto tarda cada celda en volver a su voltaje de reposo.'**
  String get inspectionStepRecoveryBody;

  /// No description provided for @inspectionStepDoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get inspectionStepDoneTitle;

  /// No description provided for @inspectionCurrentNow.
  ///
  /// In es, this message translates to:
  /// **'Corriente ahora'**
  String get inspectionCurrentNow;

  /// No description provided for @inspectionLoadEnough.
  ///
  /// In es, this message translates to:
  /// **'Carga detectada: {amps} A, suficiente.'**
  String inspectionLoadEnough(String amps);

  /// No description provided for @inspectionLoadTooLow.
  ///
  /// In es, this message translates to:
  /// **'Veo {amps} A y hacen falta {need} A sostenidos.'**
  String inspectionLoadTooLow(String amps, String need);

  /// No description provided for @inspectionNotQuiet.
  ///
  /// In es, this message translates to:
  /// **'Hay corriente ({amps} A). Hace falta reposo.'**
  String inspectionNotQuiet(String amps);

  /// No description provided for @inspectionQuietOk.
  ///
  /// In es, this message translates to:
  /// **'En reposo.'**
  String get inspectionQuietOk;

  /// No description provided for @inspectionSecondsLeft.
  ///
  /// In es, this message translates to:
  /// **'{seconds} s'**
  String inspectionSecondsLeft(String seconds);

  /// No description provided for @inspectionStepSkipHint.
  ///
  /// In es, this message translates to:
  /// **'Si esta carga no se puede generar, la app pasa al siguiente paso sola en {seconds} s y lo dice en el veredicto.'**
  String inspectionStepSkipHint(String seconds);

  /// No description provided for @inspectionSkipStep.
  ///
  /// In es, this message translates to:
  /// **'Saltar este paso'**
  String get inspectionSkipStep;

  /// No description provided for @inspectionAbort.
  ///
  /// In es, this message translates to:
  /// **'Terminar ahora'**
  String get inspectionAbort;

  /// No description provided for @inspectionQuickTestLabel.
  ///
  /// In es, this message translates to:
  /// **'TEST RÁPIDO · ESTIMACIÓN'**
  String get inspectionQuickTestLabel;

  /// No description provided for @inspectionLightGood.
  ///
  /// In es, this message translates to:
  /// **'Nada grave a la vista'**
  String get inspectionLightGood;

  /// No description provided for @inspectionLightWatch.
  ///
  /// In es, this message translates to:
  /// **'Hay algo que mirar'**
  String get inspectionLightWatch;

  /// No description provided for @inspectionLightProblem.
  ///
  /// In es, this message translates to:
  /// **'No compres a ciegas: hay un problema'**
  String get inspectionLightProblem;

  /// No description provided for @inspectionLightUnmeasured.
  ///
  /// In es, this message translates to:
  /// **'Sin veredicto: nunca se cargó el pack'**
  String get inspectionLightUnmeasured;

  /// No description provided for @inspectionUnmeasuredBody.
  ///
  /// In es, this message translates to:
  /// **'Este test saca su respuesta de la caída por celda bajo carga, y nunca llegó una carga suficiente, así que aquí no hay nada sobre esta batería ni a favor ni en contra. Repítelo y dale una de estas: rodar cincuenta metros acelerando de verdad, o apretar el freno trasero en el caballete y abrir gas, o enchufar el cargador medio minuto. La rueda girando al aire no es carga: el motor no tiene contra qué empujar, así que la corriente se queda casi en cero por mucho que gires el puño.'**
  String get inspectionUnmeasuredBody;

  /// No description provided for @inspectionFidelityNote.
  ///
  /// In es, this message translates to:
  /// **'Un test rápido detecta la celda que se aparta de las demás bajo carga (a la carga de esta prueba, desde unos {floor} mΩ de resistencia de más) y la estafa obvia; no mide capacidad real. Para capacidad real hace falta una descarga completa.'**
  String inspectionFidelityNote(String floor);

  /// No description provided for @inspectionCaveatsTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que este test no pudo ver'**
  String get inspectionCaveatsTitle;

  /// No description provided for @inspectionCaveatNoHeavyLoad.
  ///
  /// In es, this message translates to:
  /// **'Sin carga fuerte: la caída por celda no se pudo medir.'**
  String get inspectionCaveatNoHeavyLoad;

  /// No description provided for @inspectionCaveatHeavyWasCharge.
  ///
  /// In es, this message translates to:
  /// **'La carga fue un cargador, así que las celdas subieron en vez de bajar. La cuenta es la misma; la dirección no.'**
  String get inspectionCaveatHeavyWasCharge;

  /// No description provided for @inspectionCaveatNoLightLoad.
  ///
  /// In es, this message translates to:
  /// **'Sin carga ligera: el paso de las luces no ocurrió.'**
  String get inspectionCaveatNoLightLoad;

  /// No description provided for @inspectionCaveatRestNoisy.
  ///
  /// In es, this message translates to:
  /// **'El pack nunca estuvo quieto del todo: la foto en reposo es aproximada.'**
  String get inspectionCaveatRestNoisy;

  /// No description provided for @inspectionCaveatNoRecovery.
  ///
  /// In es, this message translates to:
  /// **'La carga no se soltó: la recuperación no se midió.'**
  String get inspectionCaveatNoRecovery;

  /// No description provided for @inspectionCaveatStepTooSmall.
  ///
  /// In es, this message translates to:
  /// **'El salto de corriente fue pequeño: la resistencia estimada es ruido.'**
  String get inspectionCaveatStepTooSmall;

  /// No description provided for @inspectionCaveatFewReadings.
  ///
  /// In es, this message translates to:
  /// **'Pocas lecturas: el BMS habló poco.'**
  String get inspectionCaveatFewReadings;

  /// No description provided for @inspectionCellsTitle.
  ///
  /// In es, this message translates to:
  /// **'Celda por celda'**
  String get inspectionCellsTitle;

  /// No description provided for @inspectionCellHeaderRest.
  ///
  /// In es, this message translates to:
  /// **'Reposo'**
  String get inspectionCellHeaderRest;

  /// No description provided for @inspectionCellHeaderSag.
  ///
  /// In es, this message translates to:
  /// **'Caída'**
  String get inspectionCellHeaderSag;

  /// No description provided for @inspectionCellHeaderIr.
  ///
  /// In es, this message translates to:
  /// **'R est.'**
  String get inspectionCellHeaderIr;

  /// No description provided for @inspectionCellHeaderRec.
  ///
  /// In es, this message translates to:
  /// **'Recup.'**
  String get inspectionCellHeaderRec;

  /// No description provided for @inspectionReportedTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que dice el BMS (editable)'**
  String get inspectionReportedTitle;

  /// No description provided for @inspectionReportedHint.
  ///
  /// In es, this message translates to:
  /// **'Ciclos, capacidad configurada y SOH se cambian desde la app oficial en un minuto. Se muestran; no se creen.'**
  String get inspectionReportedHint;

  /// No description provided for @inspectionReportedCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos'**
  String get inspectionReportedCycles;

  /// No description provided for @inspectionReportedCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad configurada'**
  String get inspectionReportedCapacity;

  /// No description provided for @inspectionReportedSoc.
  ///
  /// In es, this message translates to:
  /// **'Carga'**
  String get inspectionReportedSoc;

  /// No description provided for @inspectionReportedSoh.
  ///
  /// In es, this message translates to:
  /// **'SOH'**
  String get inspectionReportedSoh;

  /// No description provided for @inspectionReportedModel.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get inspectionReportedModel;

  /// No description provided for @inspectionSummaryLine.
  ///
  /// In es, this message translates to:
  /// **'{cells} celdas · pico {amps} A · {seconds} s · {readings} lecturas'**
  String inspectionSummaryLine(
    String cells,
    String amps,
    String seconds,
    String readings,
  );

  /// No description provided for @inspectionSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar inspección'**
  String get inspectionSave;

  /// No description provided for @inspectionSaved.
  ///
  /// In es, this message translates to:
  /// **'Inspección guardada.'**
  String get inspectionSaved;

  /// No description provided for @inspectionDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get inspectionDiscard;

  /// No description provided for @inspectionNoteHint.
  ///
  /// In es, this message translates to:
  /// **'Nota: vendedor, precio pedido, lo que dijo…'**
  String get inspectionNoteHint;

  /// No description provided for @inspectionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Inspecciones'**
  String get inspectionsTitle;

  /// No description provided for @inspectionsIntro.
  ///
  /// In es, this message translates to:
  /// **'Baterías ajenas que has mirado con el test rápido. No forman parte de tu historial.'**
  String get inspectionsIntro;

  /// No description provided for @inspectionsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has inspeccionado ninguna batería.'**
  String get inspectionsEmpty;

  /// No description provided for @inspectionsOpen.
  ///
  /// In es, this message translates to:
  /// **'Ver inspecciones'**
  String get inspectionsOpen;

  /// No description provided for @inspectionDeleted.
  ///
  /// In es, this message translates to:
  /// **'Inspección borrada.'**
  String get inspectionDeleted;

  /// No description provided for @inspectionDeleteConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar esta inspección?'**
  String get inspectionDeleteConfirmTitle;

  /// No description provided for @inspectionDeleteConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se pierden el veredicto y las lecturas capturadas.'**
  String get inspectionDeleteConfirmBody;

  /// No description provided for @inspectionCreditsLeft.
  ///
  /// In es, this message translates to:
  /// **'Esta inspección consume un chequeo. Te quedan {count}.'**
  String inspectionCreditsLeft(String count);

  /// No description provided for @inspectionCreditsGone.
  ///
  /// In es, this message translates to:
  /// **'No te quedan chequeos. Consigue más en Licencia.'**
  String get inspectionCreditsGone;

  /// No description provided for @verdictInspCellSaggingTitle.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} cae mucho más que las demás'**
  String verdictInspCellSaggingTitle(String cell);

  /// No description provided for @verdictInspCellSaggingBody.
  ///
  /// In es, this message translates to:
  /// **'Bajo la carga fuerte cayó {excess} V más que la mediana del pack: unos {ohms} mΩ de resistencia de más. Coherente con una celda gastada o con una conexión mala en esa celda. Es la razón principal para no pagar el precio pedido sin más pruebas.'**
  String verdictInspCellSaggingBody(String excess, String ohms);

  /// No description provided for @verdictInspSagUniformTitle.
  ///
  /// In es, this message translates to:
  /// **'Todas las celdas caen parejo'**
  String get verdictInspSagUniformTitle;

  /// No description provided for @verdictInspSagUniformBody.
  ///
  /// In es, this message translates to:
  /// **'Con la carga fuerte ({amps} A) la peor celda cayó solo {excess} V más que la mediana. A esta corriente ya se distinguiría una celda con unos {floor} mΩ de resistencia de más, y ninguna se rinde antes que las demás.'**
  String verdictInspSagUniformBody(String amps, String excess, String floor);

  /// No description provided for @verdictInspRestDeltaWideTitle.
  ///
  /// In es, this message translates to:
  /// **'Las celdas están desparejas en reposo'**
  String get verdictInspRestDeltaWideTitle;

  /// No description provided for @verdictInspRestDeltaWideBody.
  ///
  /// In es, this message translates to:
  /// **'Con la moto quieta el delta es de {delta} V y la más baja es la celda {cell}. Sin corriente eso no es resistencia: son celdas que guardan cantidades distintas de carga, o un balanceador que no trabaja.'**
  String verdictInspRestDeltaWideBody(String delta, String cell);

  /// No description provided for @verdictInspRestDeltaOkTitle.
  ///
  /// In es, this message translates to:
  /// **'Celdas parejas en reposo'**
  String get verdictInspRestDeltaOkTitle;

  /// No description provided for @verdictInspRestDeltaOkBody.
  ///
  /// In es, this message translates to:
  /// **'Delta de {delta} V con la moto quieta. Bien.'**
  String verdictInspRestDeltaOkBody(String delta);

  /// No description provided for @verdictInspWeakLightTitle.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} cae con casi nada'**
  String verdictInspWeakLightTitle(String cell);

  /// No description provided for @verdictInspWeakLightBody.
  ///
  /// In es, this message translates to:
  /// **'Con solo las luces ({amps} A) cayó {extra} V más que las demás. Una celda que se rinde con la carga de las luces (menos de un amperio) es una celda muy cansada.'**
  String verdictInspWeakLightBody(String amps, String extra);

  /// No description provided for @verdictInspSlowRecoveryTitle.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} rebota lento'**
  String verdictInspSlowRecoveryTitle(String cell);

  /// No description provided for @verdictInspSlowRecoveryBody.
  ///
  /// In es, this message translates to:
  /// **'Tardó {extra} s más que la mediana en volver a su voltaje de reposo tras soltar la carga, o no volvió. Las celdas cansadas rebotan lento.'**
  String verdictInspSlowRecoveryBody(String extra);

  /// No description provided for @verdictInspRecoveryOkTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperación pareja'**
  String get verdictInspRecoveryOkTitle;

  /// No description provided for @verdictInspRecoveryOkBody.
  ///
  /// In es, this message translates to:
  /// **'Tras soltar la carga las celdas volvieron a su reposo en unos {seconds} s, todas al mismo paso. Después de un tirón así de fuerte, la recuperación es un indicador poco mirado y muy bueno.'**
  String verdictInspRecoveryOkBody(String seconds);

  /// No description provided for @verdictInspHotTitle.
  ///
  /// In es, this message translates to:
  /// **'El pack estaba caliente'**
  String get verdictInspHotTitle;

  /// No description provided for @verdictInspHotBody.
  ///
  /// In es, this message translates to:
  /// **'Llegó a {temp} °C durante el test. Para una prueba de unos minutos es mucho: pregunta de dónde viene ese calor.'**
  String verdictInspHotBody(String temp);

  /// No description provided for @verdictInspAlarmsTitle.
  ///
  /// In es, this message translates to:
  /// **'El BMS tuvo alarmas durante el test'**
  String get verdictInspAlarmsTitle;

  /// No description provided for @verdictInspAlarmsBody.
  ///
  /// In es, this message translates to:
  /// **'{count} alarma(s) activas en algún momento. Pregunta por qué: un BMS que protesta en dos minutos protesta en la calle.'**
  String verdictInspAlarmsBody(String count);

  /// No description provided for @verdictInspCountersTitle.
  ///
  /// In es, this message translates to:
  /// **'Ciclos y capacidad según el BMS: no confiar'**
  String get verdictInspCountersTitle;

  /// No description provided for @verdictInspCountersBody.
  ///
  /// In es, this message translates to:
  /// **'El BMS reporta {cycles} ciclos. Ese dato y la capacidad configurada se editan desde la app oficial en un minuto. El veredicto se apoya en la física de arriba, no en estos contadores.'**
  String verdictInspCountersBody(String cycles);

  /// No description provided for @verdictInspNoHeavyLoadTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin carga fuerte: fidelidad reducida'**
  String get verdictInspNoHeavyLoadTitle;

  /// No description provided for @verdictInspNoHeavyLoadBody.
  ///
  /// In es, this message translates to:
  /// **'La corriente máxima vista fue {amps} A. Sin un tirón fuerte sostenido unos segundos no se puede medir cuánto cae cada celda, que es donde sale la verdad. Repite rodando con carga real (una cuesta o acelerar fuerte), o con el cargador.'**
  String verdictInspNoHeavyLoadBody(String amps);

  /// No description provided for @evidenceCellSag.
  ///
  /// In es, this message translates to:
  /// **'Caída de la celda {cell} bajo carga'**
  String evidenceCellSag(String cell);

  /// No description provided for @evidenceMedianSag.
  ///
  /// In es, this message translates to:
  /// **'Caída mediana del pack'**
  String get evidenceMedianSag;

  /// No description provided for @evidenceCurrentStep.
  ///
  /// In es, this message translates to:
  /// **'Salto de corriente (carga menos reposo)'**
  String get evidenceCurrentStep;

  /// No description provided for @evidenceCellResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia estimada de la celda {cell}'**
  String evidenceCellResistance(String cell);

  /// No description provided for @evidenceMedianResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia estimada mediana'**
  String get evidenceMedianResistance;

  /// No description provided for @evidenceLowestRestCell.
  ///
  /// In es, this message translates to:
  /// **'Celda más baja en reposo (celda {cell})'**
  String evidenceLowestRestCell(String cell);

  /// No description provided for @evidenceLightLoadAmps.
  ///
  /// In es, this message translates to:
  /// **'Corriente con las luces'**
  String get evidenceLightLoadAmps;

  /// No description provided for @evidenceRecoverySeconds.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de la celda {cell}'**
  String evidenceRecoverySeconds(String cell);

  /// No description provided for @evidenceMedianRecoverySeconds.
  ///
  /// In es, this message translates to:
  /// **'Recuperación mediana'**
  String get evidenceMedianRecoverySeconds;

  /// No description provided for @evidenceAlarmCount.
  ///
  /// In es, this message translates to:
  /// **'Alarmas vistas'**
  String get evidenceAlarmCount;

  /// No description provided for @evidencePeakCurrent.
  ///
  /// In es, this message translates to:
  /// **'Corriente máxima vista'**
  String get evidencePeakCurrent;

  /// No description provided for @reportPackTitle.
  ///
  /// In es, this message translates to:
  /// **'Informe de batería'**
  String get reportPackTitle;

  /// No description provided for @reportInspectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Informe de inspección'**
  String get reportInspectionTitle;

  /// No description provided for @reportCertificateTitle.
  ///
  /// In es, this message translates to:
  /// **'Certificado de inspección'**
  String get reportCertificateTitle;

  /// No description provided for @reportGeneratedAt.
  ///
  /// In es, this message translates to:
  /// **'Generado el {date}'**
  String reportGeneratedAt(String date);

  /// No description provided for @reportAppVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión {version}'**
  String reportAppVersion(String version);

  /// No description provided for @reportPageOf.
  ///
  /// In es, this message translates to:
  /// **'Página {page} de {total}'**
  String reportPageOf(String page, String total);

  /// No description provided for @reportUnknownPack.
  ///
  /// In es, this message translates to:
  /// **'Batería sin nombre'**
  String get reportUnknownPack;

  /// No description provided for @reportSectionNow.
  ///
  /// In es, this message translates to:
  /// **'Cómo está ahora'**
  String get reportSectionNow;

  /// No description provided for @reportLastReading.
  ///
  /// In es, this message translates to:
  /// **'Última lectura'**
  String get reportLastReading;

  /// No description provided for @reportPackVoltage.
  ///
  /// In es, this message translates to:
  /// **'Tensión del pack'**
  String get reportPackVoltage;

  /// No description provided for @reportCellCount.
  ///
  /// In es, this message translates to:
  /// **'Celdas'**
  String get reportCellCount;

  /// No description provided for @reportDelta.
  ///
  /// In es, this message translates to:
  /// **'Diferencia entre celdas'**
  String get reportDelta;

  /// No description provided for @reportCellRange.
  ///
  /// In es, this message translates to:
  /// **'Celda más baja y más alta'**
  String get reportCellRange;

  /// No description provided for @reportMaxTemperature.
  ///
  /// In es, this message translates to:
  /// **'Temperatura máxima'**
  String get reportMaxTemperature;

  /// No description provided for @reportSectionCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad'**
  String get reportSectionCapacity;

  /// No description provided for @reportConfiguredCapacity.
  ///
  /// In es, this message translates to:
  /// **'Configurada en el BMS'**
  String get reportConfiguredCapacity;

  /// No description provided for @reportAdvertisedCapacity.
  ///
  /// In es, this message translates to:
  /// **'Anunciada al comprarla'**
  String get reportAdvertisedCapacity;

  /// No description provided for @reportCapacityTests.
  ///
  /// In es, this message translates to:
  /// **'Tests de capacidad completados'**
  String get reportCapacityTests;

  /// No description provided for @reportCapacityNote.
  ///
  /// In es, this message translates to:
  /// **'Solo la mejor medición real proviene de una descarga completa contada por la app. La capacidad configurada es un ajuste del BMS, no una medida, y se puede cambiar en un minuto.'**
  String get reportCapacityNote;

  /// No description provided for @reportSectionRange.
  ///
  /// In es, this message translates to:
  /// **'Autonomía'**
  String get reportSectionRange;

  /// No description provided for @reportConsumption.
  ///
  /// In es, this message translates to:
  /// **'Consumo aprendido'**
  String get reportConsumption;

  /// No description provided for @reportRangeBasis.
  ///
  /// In es, this message translates to:
  /// **'Calculada a partir de'**
  String get reportRangeBasis;

  /// No description provided for @reportRangeFromMeasured.
  ///
  /// In es, this message translates to:
  /// **'capacidad medida'**
  String get reportRangeFromMeasured;

  /// No description provided for @reportRangeFromCatalogue.
  ///
  /// In es, this message translates to:
  /// **'capacidad anunciada'**
  String get reportRangeFromCatalogue;

  /// No description provided for @reportSectionCells.
  ///
  /// In es, this message translates to:
  /// **'Celdas'**
  String get reportSectionCells;

  /// No description provided for @reportCell.
  ///
  /// In es, this message translates to:
  /// **'Celda'**
  String get reportCell;

  /// No description provided for @reportDeviation.
  ///
  /// In es, this message translates to:
  /// **'Bajo la media'**
  String get reportDeviation;

  /// No description provided for @reportTrend.
  ///
  /// In es, this message translates to:
  /// **'Tendencia'**
  String get reportTrend;

  /// No description provided for @reportSpan.
  ///
  /// In es, this message translates to:
  /// **'Medido sobre'**
  String get reportSpan;

  /// No description provided for @reportDays.
  ///
  /// In es, this message translates to:
  /// **'{count} días'**
  String reportDays(String count);

  /// No description provided for @reportCellsNote.
  ///
  /// In es, this message translates to:
  /// **'Una celda que siempre estuvo baja es un pack fabricado así. Una que se separa mes a mes es una celda que se va.'**
  String get reportCellsNote;

  /// No description provided for @reportSectionHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get reportSectionHistory;

  /// No description provided for @reportReadings.
  ///
  /// In es, this message translates to:
  /// **'Lecturas guardadas'**
  String get reportReadings;

  /// No description provided for @reportSectionMaintenance.
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento registrado'**
  String get reportSectionMaintenance;

  /// No description provided for @reportDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get reportDate;

  /// No description provided for @reportEvent.
  ///
  /// In es, this message translates to:
  /// **'Evento'**
  String get reportEvent;

  /// No description provided for @reportNote.
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get reportNote;

  /// No description provided for @reportHonestyPack.
  ///
  /// In es, this message translates to:
  /// **'Las cifras vienen de lo que informa el BMS y de lo que esta app ha contado durante el uso. La autonomía es una estimación aprendida de viajes reales, no una promesa. La capacidad medida requiere una descarga completa registrada por la app; sin ella, no hay medida, hay lo que dice el BMS.'**
  String get reportHonestyPack;

  /// No description provided for @reportSectionTest.
  ///
  /// In es, this message translates to:
  /// **'El test'**
  String get reportSectionTest;

  /// No description provided for @reportTestedAt.
  ///
  /// In es, this message translates to:
  /// **'Realizado el'**
  String get reportTestedAt;

  /// No description provided for @reportPeakCurrent.
  ///
  /// In es, this message translates to:
  /// **'Corriente máxima alcanzada'**
  String get reportPeakCurrent;

  /// No description provided for @reportRestDelta.
  ///
  /// In es, this message translates to:
  /// **'Diferencia en reposo'**
  String get reportRestDelta;

  /// No description provided for @reportMedianSag.
  ///
  /// In es, this message translates to:
  /// **'Caída mediana bajo carga'**
  String get reportMedianSag;

  /// No description provided for @reportMedianResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia mediana'**
  String get reportMedianResistance;

  /// No description provided for @reportMedianRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación mediana'**
  String get reportMedianRecovery;

  /// No description provided for @reportDuration.
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get reportDuration;

  /// No description provided for @reportReadingsInline.
  ///
  /// In es, this message translates to:
  /// **'({count} lecturas)'**
  String reportReadingsInline(String count);

  /// No description provided for @reportRestVolts.
  ///
  /// In es, this message translates to:
  /// **'Reposo (V)'**
  String get reportRestVolts;

  /// No description provided for @reportSag.
  ///
  /// In es, this message translates to:
  /// **'Caída (V)'**
  String get reportSag;

  /// No description provided for @reportResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia (mOhm)'**
  String get reportResistance;

  /// No description provided for @reportRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación (s)'**
  String get reportRecovery;

  /// No description provided for @reportNotRecovered.
  ///
  /// In es, this message translates to:
  /// **'no volvió'**
  String get reportNotRecovered;

  /// No description provided for @reportCellTableNote.
  ///
  /// In es, this message translates to:
  /// **'La caída es cuánto bajó cada celda bajo la carga fuerte. La resistencia se estima del salto de corriente, no se mide con instrumento.'**
  String get reportCellTableNote;

  /// No description provided for @reportSectionReported.
  ///
  /// In es, this message translates to:
  /// **'Lo que dice el BMS de sí mismo'**
  String get reportSectionReported;

  /// No description provided for @reportModel.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get reportModel;

  /// No description provided for @reportSerial.
  ///
  /// In es, this message translates to:
  /// **'Número de serie'**
  String get reportSerial;

  /// No description provided for @reportSoftware.
  ///
  /// In es, this message translates to:
  /// **'Versión del firmware'**
  String get reportSoftware;

  /// No description provided for @reportCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos según el BMS'**
  String get reportCycles;

  /// No description provided for @reportReportedSoh.
  ///
  /// In es, this message translates to:
  /// **'Salud declarada'**
  String get reportReportedSoh;

  /// No description provided for @reportReportedNote.
  ///
  /// In es, this message translates to:
  /// **'Estos valores son editables desde la app oficial del BMS en menos de un minuto. Se imprimen aparte a propósito: son una declaración, no una medida.'**
  String get reportReportedNote;

  /// No description provided for @reportSectionCaveats.
  ///
  /// In es, this message translates to:
  /// **'Lo que este test no pudo ver'**
  String get reportSectionCaveats;

  /// No description provided for @reportSectionNote.
  ///
  /// In es, this message translates to:
  /// **'Nota del inspector'**
  String get reportSectionNote;

  /// No description provided for @reportSectionCertificate.
  ///
  /// In es, this message translates to:
  /// **'Certificado'**
  String get reportSectionCertificate;

  /// No description provided for @reportCertificateCode.
  ///
  /// In es, this message translates to:
  /// **'Código del certificado'**
  String get reportCertificateCode;

  /// No description provided for @reportCertificateIssuer.
  ///
  /// In es, this message translates to:
  /// **'Código de emisor'**
  String get reportCertificateIssuer;

  /// No description provided for @reportCertificateIssuedAt.
  ///
  /// In es, this message translates to:
  /// **'Firmado el'**
  String get reportCertificateIssuedAt;

  /// No description provided for @reportCertificateExplain.
  ///
  /// In es, this message translates to:
  /// **'La firma demuestra que estas cifras salieron de la app en el teléfono cuyo código de emisor aparece aquí, y que no se han cambiado desde entonces. No demuestra de quién es ese teléfono: compara el código con el que publica quien te dio el certificado. Tampoco demuestra qué batería se probó (el nombre y el número de serie los da el BMS y se pueden cambiar), ni la fecha, que es la del reloj de ese teléfono, ni que la batería esté bien. Escanea el QR o pega el código en la app para comprobarlo.'**
  String get reportCertificateExplain;

  /// No description provided for @reportHonestyInspection.
  ///
  /// In es, this message translates to:
  /// **'Test rápido del {date}. Un test así detecta la celda que se aparta de las demás bajo carga, a la carga de esta prueba, y la estafa obvia; no sustituye a una revisión en taller. No mide capacidad: la capacidad que aparece es la configurada en el BMS, no una medida.'**
  String reportHonestyInspection(String date);

  /// No description provided for @reportPackButton.
  ///
  /// In es, this message translates to:
  /// **'Informe PDF'**
  String get reportPackButton;

  /// No description provided for @reportInspectionPdfButton.
  ///
  /// In es, this message translates to:
  /// **'Informe PDF'**
  String get reportInspectionPdfButton;

  /// No description provided for @reportCertificateButton.
  ///
  /// In es, this message translates to:
  /// **'Certificado firmado'**
  String get reportCertificateButton;

  /// No description provided for @reportBuilding.
  ///
  /// In es, this message translates to:
  /// **'Preparando el PDF...'**
  String get reportBuilding;

  /// No description provided for @reportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el PDF.'**
  String get reportFailed;

  /// No description provided for @reportShareText.
  ///
  /// In es, this message translates to:
  /// **'Informe generado con JK BMS +'**
  String get reportShareText;

  /// No description provided for @certificateVerifyTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificar certificado'**
  String get certificateVerifyTitle;

  /// No description provided for @certificateVerifyIntro.
  ///
  /// In es, this message translates to:
  /// **'Pega aquí el código que acompaña a un certificado, o el texto del QR. La app comprueba la firma y te muestra las cifras que se firmaron, todas, con el veredicto que la app saca de ellas.'**
  String get certificateVerifyIntro;

  /// No description provided for @certificateVerifyHint.
  ///
  /// In es, this message translates to:
  /// **'JKC1....'**
  String get certificateVerifyHint;

  /// No description provided for @certificateVerifyButton.
  ///
  /// In es, this message translates to:
  /// **'Comprobar'**
  String get certificateVerifyButton;

  /// No description provided for @certificateVerifyOpen.
  ///
  /// In es, this message translates to:
  /// **'Verificar un certificado'**
  String get certificateVerifyOpen;

  /// No description provided for @certificateValid.
  ///
  /// In es, this message translates to:
  /// **'Firma válida para el emisor {issuer}. Comprueba que ese código es el de quien te dio el certificado.'**
  String certificateValid(String issuer);

  /// No description provided for @certificateBadSignature.
  ///
  /// In es, this message translates to:
  /// **'La firma no cuadra: el contenido se modificó después de firmarlo.'**
  String get certificateBadSignature;

  /// No description provided for @certificateMalformed.
  ///
  /// In es, this message translates to:
  /// **'Eso no es un certificado válido.'**
  String get certificateMalformed;

  /// No description provided for @certificateCreditsLeft.
  ///
  /// In es, this message translates to:
  /// **'Firmar un certificado consume un crédito. Te quedan {count}.'**
  String certificateCreditsLeft(String count);

  /// No description provided for @certificateCreditsGone.
  ///
  /// In es, this message translates to:
  /// **'No te quedan créditos de certificado. Consigue más en Licencia.'**
  String get certificateCreditsGone;

  /// No description provided for @verdictInspRepeatSameCellTitle.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} vuelve a fallar: {times} de {runs} pruebas'**
  String verdictInspRepeatSameCellTitle(String cell, String times, String runs);

  /// No description provided for @verdictInspRepeatSameCellBody.
  ///
  /// In es, this message translates to:
  /// **'Repetida la prueba con una carga parecida, la misma celda vuelve a hundirse antes que las demás, y las dos veces por encima del umbral. Ya no parece una lectura rara: es esa celda o su conexión, y un taller puede decir cuál.'**
  String get verdictInspRepeatSameCellBody;

  /// No description provided for @verdictInspRepeatCellMovedTitle.
  ///
  /// In es, this message translates to:
  /// **'Esta vez se hundió otra celda'**
  String verdictInspRepeatCellMovedTitle(String cell);

  /// No description provided for @verdictInspRepeatCellMovedBody.
  ///
  /// In es, this message translates to:
  /// **'La prueba anterior señaló la celda {before} y esta señala la {cell}. Cuando el dedo cambia de sitio entre pruebas, casi siempre es que no se tiró igual de la batería, no que haya dos celdas malas. Repite el test pidiendo el mismo acelerón que la vez anterior.'**
  String verdictInspRepeatCellMovedBody(String before, String cell);

  /// No description provided for @verdictInspRepeatWorseTitle.
  ///
  /// In es, this message translates to:
  /// **'Mide peor que en la prueba anterior'**
  String get verdictInspRepeatWorseTitle;

  /// No description provided for @verdictInspRepeatWorseBody.
  ///
  /// In es, this message translates to:
  /// **'Respecto a la prueba anterior el pack mide peor; las cifras de las dos están en el detalle. Las caídas solo se comparan cuando las dos cargas fueron parecidas, y el reposo solo cuando el pack estaba a una carga parecida. Dos pruebas apuntan a un cambio; una tercera lo confirmaría.'**
  String get verdictInspRepeatWorseBody;

  /// No description provided for @verdictInspRepeatSteadyTitle.
  ///
  /// In es, this message translates to:
  /// **'Repite lo mismo que la vez anterior'**
  String get verdictInspRepeatSteadyTitle;

  /// No description provided for @verdictInspRepeatSteadyBody.
  ///
  /// In es, this message translates to:
  /// **'Las cifras de esta prueba caen dentro del ruido de la anterior. La primera prueba no fue una casualidad y esta no ha encontrado nada nuevo.'**
  String get verdictInspRepeatSteadyBody;

  /// No description provided for @verdictInspRepeatCountersResetTitle.
  ///
  /// In es, this message translates to:
  /// **'Los contadores del BMS bajaron entre visitas'**
  String get verdictInspRepeatCountersResetTitle;

  /// No description provided for @verdictInspRepeatCountersResetBody.
  ///
  /// In es, this message translates to:
  /// **'Los ciclos y la energía total que cuenta el BMS solo suben. Si entre las dos pruebas bajaron, el BMS se reseteó o se cambió. Pregunta por qué. Lo físico de arriba no se resetea con un botón; eso es lo que hay que mirar.'**
  String get verdictInspRepeatCountersResetBody;

  /// No description provided for @verdictInspRepeatLoadDiffersTitle.
  ///
  /// In es, this message translates to:
  /// **'Las dos pruebas no tiraron igual'**
  String get verdictInspRepeatLoadDiffersTitle;

  /// No description provided for @verdictInspRepeatLoadDiffersBody.
  ///
  /// In es, this message translates to:
  /// **'La caída de voltaje depende de cuánta corriente se pida. Con acelerones muy distintos, comparar las caídas no dice nada. Para comparar de verdad, repite el test pidiendo un tirón parecido.'**
  String get verdictInspRepeatLoadDiffersBody;

  /// No description provided for @evidenceRunCount.
  ///
  /// In es, this message translates to:
  /// **'Pruebas a este pack'**
  String get evidenceRunCount;

  /// No description provided for @evidenceTimesSameCell.
  ///
  /// In es, this message translates to:
  /// **'Veces que salió la celda {cell}'**
  String evidenceTimesSameCell(String cell);

  /// No description provided for @evidencePreviousSag.
  ///
  /// In es, this message translates to:
  /// **'Caída el {date}'**
  String evidencePreviousSag(String date);

  /// No description provided for @evidencePreviousRestDelta.
  ///
  /// In es, this message translates to:
  /// **'Delta en reposo el {date}'**
  String evidencePreviousRestDelta(String date);

  /// No description provided for @evidencePreviousResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia mediana el {date}'**
  String evidencePreviousResistance(String date);

  /// No description provided for @evidencePreviousCycles.
  ///
  /// In es, this message translates to:
  /// **'Ciclos según el BMS el {date}'**
  String evidencePreviousCycles(String date);

  /// No description provided for @evidencePreviousSoh.
  ///
  /// In es, this message translates to:
  /// **'SOH según el BMS el {date}'**
  String evidencePreviousSoh(String date);

  /// No description provided for @evidencePreviousConfiguredCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad configurada el {date}'**
  String evidencePreviousConfiguredCapacity(String date);

  /// No description provided for @evidencePreviousPeakCurrent.
  ///
  /// In es, this message translates to:
  /// **'Salto de corriente el {date}'**
  String evidencePreviousPeakCurrent(String date);

  /// No description provided for @inspectionSeriesTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparado con las pruebas anteriores'**
  String get inspectionSeriesTitle;

  /// No description provided for @inspectionSeriesIntro.
  ///
  /// In es, this message translates to:
  /// **'Este pack ya se había inspeccionado. Repetir el test es lo que separa una lectura rara de un fallo real.'**
  String get inspectionSeriesIntro;

  /// No description provided for @inspectionSeriesRun.
  ///
  /// In es, this message translates to:
  /// **'Prueba {number} de {total} a este pack'**
  String inspectionSeriesRun(String number, String total);

  /// No description provided for @inspectionSeriesPrevious.
  ///
  /// In es, this message translates to:
  /// **'Prueba del {date}'**
  String inspectionSeriesPrevious(String date);

  /// No description provided for @inspectionSeriesFirstRun.
  ///
  /// In es, this message translates to:
  /// **'Primera inspección de este pack. Repítela otro día para confirmar lo que has visto.'**
  String get inspectionSeriesFirstRun;

  /// No description provided for @inspectionRepeatButton.
  ///
  /// In es, this message translates to:
  /// **'Repetir la prueba'**
  String get inspectionRepeatButton;

  /// No description provided for @inspectionRepeatHint.
  ///
  /// In es, this message translates to:
  /// **'Guárdala antes de repetir para poder compararlas: solo se comparan las pruebas guardadas.'**
  String get inspectionRepeatHint;

  /// No description provided for @inspectionAlreadySeen.
  ///
  /// In es, this message translates to:
  /// **'Ya inspeccionada {count} vez/veces'**
  String inspectionAlreadySeen(String count);

  /// No description provided for @reportSectionSeries.
  ///
  /// In es, this message translates to:
  /// **'Pruebas anteriores a este pack'**
  String get reportSectionSeries;

  /// No description provided for @reportSeriesNote.
  ///
  /// In es, this message translates to:
  /// **'Cada fila es una inspección guardada en el teléfono que firmó esta hoja, incluida esta, que es la última. Repetir el test es lo que distingue una celda mala de una lectura mala.'**
  String get reportSeriesNote;

  /// No description provided for @reportSeriesWorstCell.
  ///
  /// In es, this message translates to:
  /// **'Peor celda'**
  String get reportSeriesWorstCell;

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil de la batería'**
  String get profileTitle;

  /// No description provided for @profileIntro.
  ///
  /// In es, this message translates to:
  /// **'Cuatro cosas que el BMS no puede saber y que cambian lo que la app puede decirte. Todas se pueden dejar en blanco.'**
  String get profileIntro;

  /// No description provided for @profileName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get profileName;

  /// No description provided for @profileSoldAs.
  ///
  /// In es, this message translates to:
  /// **'Vendida como'**
  String get profileSoldAs;

  /// No description provided for @profileSoldAsHint.
  ///
  /// In es, this message translates to:
  /// **'Capacidad que te dijeron'**
  String get profileSoldAsHint;

  /// No description provided for @profileChemistry.
  ///
  /// In es, this message translates to:
  /// **'Química de las celdas'**
  String get profileChemistry;

  /// No description provided for @profileChemistryWhy.
  ///
  /// In es, this message translates to:
  /// **'De esto dependen los rangos seguros. LFP a 4,2 V por celda es un incendio; NMC a 3,6 V es una batería a medio cargar. Si no lo sabes, déjalo en \"No lo sé\" y la app no auditará voltajes.'**
  String get profileChemistryWhy;

  /// No description provided for @profileChemistryFromOvp.
  ///
  /// In es, this message translates to:
  /// **'El BMS está configurado a {value} V por celda, lo que sugiere {chemistry}.'**
  String profileChemistryFromOvp(String chemistry, String value);

  /// No description provided for @profileChemistryFromCell.
  ///
  /// In es, this message translates to:
  /// **'Se ha visto una celda a {value} V, así que no es LFP: sugiere {chemistry}.'**
  String profileChemistryFromCell(String chemistry, String value);

  /// No description provided for @profileAcquired.
  ///
  /// In es, this message translates to:
  /// **'La tengo desde'**
  String get profileAcquired;

  /// No description provided for @profileAcquiredUnknown.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha'**
  String get profileAcquiredUnknown;

  /// No description provided for @profileAcquiredClear.
  ///
  /// In es, this message translates to:
  /// **'Quitar la fecha'**
  String get profileAcquiredClear;

  /// No description provided for @profileAgeYears.
  ///
  /// In es, this message translates to:
  /// **'{years} años contigo'**
  String profileAgeYears(String years);

  /// No description provided for @profileCaptureBaseline.
  ///
  /// In es, this message translates to:
  /// **'Guardar el estado de hoy como día uno'**
  String get profileCaptureBaseline;

  /// No description provided for @profileCaptureBaselineHint.
  ///
  /// In es, this message translates to:
  /// **'Celdas, resistencias y configuración del BMS tal como están ahora. Todo lo que la app diga después sobre derivas se compara contra esto. Mejor con la batería en reposo.'**
  String get profileCaptureBaselineHint;

  /// No description provided for @profileSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get profileSave;

  /// No description provided for @profileLater.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get profileLater;

  /// No description provided for @profileEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar el perfil'**
  String get profileEdit;

  /// No description provided for @profileComplete.
  ///
  /// In es, this message translates to:
  /// **'Completar el perfil'**
  String get profileComplete;

  /// No description provided for @profileBaseline.
  ///
  /// In es, this message translates to:
  /// **'Día uno'**
  String get profileBaseline;

  /// No description provided for @profileBaselineMissing.
  ///
  /// In es, this message translates to:
  /// **'Sin guardar'**
  String get profileBaselineMissing;

  /// No description provided for @profileNoBaselineIntro.
  ///
  /// In es, this message translates to:
  /// **'Sin un día uno, \"el delta se ha abierto\" solo significa \"desde que la app empezó a mirar\". Guardar el estado de hoy le da a todo lo demás un punto de partida.'**
  String get profileNoBaselineIntro;

  /// No description provided for @profileSinceDayOne.
  ///
  /// In es, this message translates to:
  /// **'Desde el día uno ({date})'**
  String profileSinceDayOne(String date);

  /// No description provided for @profileNotComparable.
  ///
  /// In es, this message translates to:
  /// **'Una de las dos lecturas se tomó con la batería tirando corriente, así que las celdas no son comparables. Mira esto con la moto parada.'**
  String get profileNotComparable;

  /// No description provided for @profileDeltaThenNow.
  ///
  /// In es, this message translates to:
  /// **'Diferencia entre celdas'**
  String get profileDeltaThenNow;

  /// No description provided for @profileWorstDrift.
  ///
  /// In es, this message translates to:
  /// **'La que más se ha ido'**
  String get profileWorstDrift;

  /// No description provided for @profileWorstDriftValue.
  ///
  /// In es, this message translates to:
  /// **'Celda {cell}, {mv} mV'**
  String profileWorstDriftValue(String cell, String mv);

  /// No description provided for @profileCyclesSince.
  ///
  /// In es, this message translates to:
  /// **'Ciclos desde entonces'**
  String get profileCyclesSince;

  /// No description provided for @profileConfigChanged.
  ///
  /// In es, this message translates to:
  /// **'Configuración del BMS'**
  String get profileConfigChanged;

  /// No description provided for @profileConfigUnchanged.
  ///
  /// In es, this message translates to:
  /// **'Igual que el día uno'**
  String get profileConfigUnchanged;

  /// No description provided for @profileConfigChangedCount.
  ///
  /// In es, this message translates to:
  /// **'{count} ajuste(s) cambiado(s)'**
  String profileConfigChangedCount(String count);

  /// No description provided for @chemistryLfp.
  ///
  /// In es, this message translates to:
  /// **'LFP'**
  String get chemistryLfp;

  /// No description provided for @chemistryNmc.
  ///
  /// In es, this message translates to:
  /// **'NMC / Li-ion'**
  String get chemistryNmc;

  /// No description provided for @chemistryUnknown.
  ///
  /// In es, this message translates to:
  /// **'No lo sé'**
  String get chemistryUnknown;

  /// No description provided for @configCellOvp.
  ///
  /// In es, this message translates to:
  /// **'Corte por celda alta'**
  String get configCellOvp;

  /// No description provided for @configCellUvp.
  ///
  /// In es, this message translates to:
  /// **'Corte por celda baja'**
  String get configCellUvp;

  /// No description provided for @configBalanceStart.
  ///
  /// In es, this message translates to:
  /// **'Empieza a balancear'**
  String get configBalanceStart;

  /// No description provided for @configSoc100.
  ///
  /// In es, this message translates to:
  /// **'Voltaje del 100 %'**
  String get configSoc100;

  /// No description provided for @configSoc0.
  ///
  /// In es, this message translates to:
  /// **'Voltaje del 0 %'**
  String get configSoc0;

  /// No description provided for @configMaxCharge.
  ///
  /// In es, this message translates to:
  /// **'Corriente máxima de carga'**
  String get configMaxCharge;

  /// No description provided for @configMaxDischarge.
  ///
  /// In es, this message translates to:
  /// **'Corriente máxima de descarga'**
  String get configMaxDischarge;

  /// No description provided for @configMaxBalance.
  ///
  /// In es, this message translates to:
  /// **'Corriente de balanceo'**
  String get configMaxBalance;

  /// No description provided for @configChargeOtp.
  ///
  /// In es, this message translates to:
  /// **'Corte por calor cargando'**
  String get configChargeOtp;

  /// No description provided for @configDischargeOtp.
  ///
  /// In es, this message translates to:
  /// **'Corte por calor descargando'**
  String get configDischargeOtp;

  /// No description provided for @configChargeUtp.
  ///
  /// In es, this message translates to:
  /// **'Corte por frío cargando'**
  String get configChargeUtp;

  /// No description provided for @configMosfetOtp.
  ///
  /// In es, this message translates to:
  /// **'Corte por calor del MOSFET'**
  String get configMosfetOtp;

  /// No description provided for @configNominalCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad configurada'**
  String get configNominalCapacity;

  /// No description provided for @configCellCount.
  ///
  /// In es, this message translates to:
  /// **'Número de celdas'**
  String get configCellCount;

  /// No description provided for @configChargeSwitch.
  ///
  /// In es, this message translates to:
  /// **'Carga habilitada'**
  String get configChargeSwitch;

  /// No description provided for @configDischargeSwitch.
  ///
  /// In es, this message translates to:
  /// **'Descarga habilitada'**
  String get configDischargeSwitch;

  /// No description provided for @configBalancerSwitch.
  ///
  /// In es, this message translates to:
  /// **'Balanceador'**
  String get configBalancerSwitch;

  /// No description provided for @configOn.
  ///
  /// In es, this message translates to:
  /// **'Sí'**
  String get configOn;

  /// No description provided for @configOff.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get configOff;

  /// No description provided for @reportSectionDayOne.
  ///
  /// In es, this message translates to:
  /// **'El día uno de esta batería'**
  String get reportSectionDayOne;

  /// No description provided for @reportDayOneNote.
  ///
  /// In es, this message translates to:
  /// **'Comparación contra el estado guardado el día que se dio de alta la batería. No es una medida de capacidad: una foto de los voltajes no puede medir lo que aguanta un pack, y aquí no se presenta como tal.'**
  String get reportDayOneNote;

  /// No description provided for @verdictConfigOvpDangerousTitle.
  ///
  /// In es, this message translates to:
  /// **'El corte de carga está por encima de lo que aguantan las celdas'**
  String get verdictConfigOvpDangerousTitle;

  /// No description provided for @verdictConfigOvpDangerousBody.
  ///
  /// In es, this message translates to:
  /// **'El BMS corta la carga a {value} V por celda y el máximo seguro para esta química es {limit} V. Cada carga completa está haciendo daño. Se cambia desde la app oficial del BMS, bajo tu responsabilidad. La app no cambia nada en el BMS: solo le envía peticiones de lectura.'**
  String verdictConfigOvpDangerousBody(String value, String limit);

  /// No description provided for @verdictConfigOvpHighTitle.
  ///
  /// In es, this message translates to:
  /// **'El corte de carga está alto'**
  String get verdictConfigOvpHighTitle;

  /// No description provided for @verdictConfigOvpHighBody.
  ///
  /// In es, this message translates to:
  /// **'Cortas a {value} V por celda cuando con {limit} V la batería ya está prácticamente llena. Lo que ganas en autonomía es casi nada y lo que pierdes en vida útil no lo es.'**
  String verdictConfigOvpHighBody(String value, String limit);

  /// No description provided for @verdictConfigUvpDangerousTitle.
  ///
  /// In es, this message translates to:
  /// **'El corte de descarga deja las celdas por debajo de lo recuperable'**
  String get verdictConfigUvpDangerousTitle;

  /// No description provided for @verdictConfigUvpDangerousBody.
  ///
  /// In es, this message translates to:
  /// **'El BMS deja bajar hasta {value} V por celda y el mínimo seguro es {limit} V. Una celda que baja de ahí puede no volver, y las que vuelven lo hacen con menos capacidad.'**
  String verdictConfigUvpDangerousBody(String value, String limit);

  /// No description provided for @verdictConfigUvpLowTitle.
  ///
  /// In es, this message translates to:
  /// **'El corte de descarga está bajo'**
  String get verdictConfigUvpLowTitle;

  /// No description provided for @verdictConfigUvpLowBody.
  ///
  /// In es, this message translates to:
  /// **'Cortas a {value} V por celda. Por debajo de {limit} V se aprieta a las celdas para sacar unos pocos kilómetros que salen caros en vida útil.'**
  String verdictConfigUvpLowBody(String value, String limit);

  /// No description provided for @verdictConfigChargesWhenFrozenTitle.
  ///
  /// In es, this message translates to:
  /// **'El BMS cargará la batería por debajo de cero'**
  String get verdictConfigChargesWhenFrozenTitle;

  /// No description provided for @verdictConfigChargesWhenFrozenBody.
  ///
  /// In es, this message translates to:
  /// **'El corte por frío está en {value} °C. Cargar litio bajo cero deposita metal dentro de la celda: es permanente, no aparece en ningún número que el BMS reporte y es la forma más común de arruinar un pack en invierno. Súbelo a 2 °C o más desde la app oficial.'**
  String verdictConfigChargesWhenFrozenBody(String value);

  /// No description provided for @verdictConfigColdCutoffOkTitle.
  ///
  /// In es, this message translates to:
  /// **'No cargará con la batería helada'**
  String get verdictConfigColdCutoffOkTitle;

  /// No description provided for @verdictConfigColdCutoffOkBody.
  ///
  /// In es, this message translates to:
  /// **'El corte por frío está en {value} °C, así que el BMS se niega a cargar antes de que empiece el daño. Es de los ajustes que más vida salvan y este está bien puesto.'**
  String verdictConfigColdCutoffOkBody(String value);

  /// No description provided for @verdictConfigChargeHotLimitTitle.
  ///
  /// In es, this message translates to:
  /// **'El corte por calor cargando está alto'**
  String get verdictConfigChargeHotLimitTitle;

  /// No description provided for @verdictConfigChargeHotLimitBody.
  ///
  /// In es, this message translates to:
  /// **'Deja cargar hasta {value} °C, y por encima de {limit} °C cargar ya envejece las celdas más rápido de lo normal.'**
  String verdictConfigChargeHotLimitBody(String value, String limit);

  /// No description provided for @verdictConfigDischargeHotLimitTitle.
  ///
  /// In es, this message translates to:
  /// **'El corte por calor descargando está alto'**
  String get verdictConfigDischargeHotLimitTitle;

  /// No description provided for @verdictConfigDischargeHotLimitBody.
  ///
  /// In es, this message translates to:
  /// **'Deja tirar hasta {value} °C. Por encima de {limit} °C ni siquiera descargar es gratis.'**
  String verdictConfigDischargeHotLimitBody(String value, String limit);

  /// No description provided for @verdictConfigCapacityDisagreesTitle.
  ///
  /// In es, this message translates to:
  /// **'La capacidad configurada no es la que te vendieron'**
  String get verdictConfigCapacityDisagreesTitle;

  /// No description provided for @verdictConfigCapacityDisagreesBody.
  ///
  /// In es, this message translates to:
  /// **'El BMS está configurado a {value} Ah y tú anotaste que se vendió como {sold} Ah. El número del BMS lo escribió quien montó el pack: no mide nada, pero de él salen el porcentaje de carga y los amperios-hora restantes de todas las pantallas.'**
  String verdictConfigCapacityDisagreesBody(String value, String sold);

  /// No description provided for @verdictConfigCellCountDisagreesTitle.
  ///
  /// In es, this message translates to:
  /// **'El BMS está configurado para otro número de celdas'**
  String get verdictConfigCellCountDisagreesTitle;

  /// No description provided for @verdictConfigCellCountDisagreesBody.
  ///
  /// In es, this message translates to:
  /// **'Configurado para {value} celdas y se están leyendo {seen}. Con esto mal, el voltaje del pack, el porcentaje y los cortes de protección se calculan sobre una batería que no es esta.'**
  String verdictConfigCellCountDisagreesBody(String value, String seen);

  /// No description provided for @verdictConfigChargeCurrentHighTitle.
  ///
  /// In es, this message translates to:
  /// **'La corriente de carga es alta para el tamaño del pack'**
  String get verdictConfigChargeCurrentHighTitle;

  /// No description provided for @verdictConfigChargeCurrentHighBody.
  ///
  /// In es, this message translates to:
  /// **'Hasta {value} A en una batería configurada como de {capacity} Ah. Se puede, pero cargar por encima de 1C calienta y envejece; si no tienes prisa, bajarlo alarga la vida.'**
  String verdictConfigChargeCurrentHighBody(String value, String capacity);

  /// No description provided for @verdictConfigBalancerOffTitle.
  ///
  /// In es, this message translates to:
  /// **'El balanceador está apagado'**
  String get verdictConfigBalancerOffTitle;

  /// No description provided for @verdictConfigBalancerOffBody.
  ///
  /// In es, this message translates to:
  /// **'Sin balanceo, las celdas se van separando solas y la más débil marca el final de cada carga y de cada descarga. Es la causa número uno de packs que pierden autonomía sin que ninguna celda esté realmente mal.'**
  String get verdictConfigBalancerOffBody;

  /// No description provided for @verdictConfigChargeOffTitle.
  ///
  /// In es, this message translates to:
  /// **'La carga está deshabilitada en el BMS'**
  String get verdictConfigChargeOffTitle;

  /// No description provided for @verdictConfigChargeOffBody.
  ///
  /// In es, this message translates to:
  /// **'Si la batería no coge carga, esto lo explica. Puede ser a propósito, o puede que se quedara así después de una protección.'**
  String get verdictConfigChargeOffBody;

  /// No description provided for @verdictConfigDischargeOffTitle.
  ///
  /// In es, this message translates to:
  /// **'La descarga está deshabilitada en el BMS'**
  String get verdictConfigDischargeOffTitle;

  /// No description provided for @verdictConfigDischargeOffBody.
  ///
  /// In es, this message translates to:
  /// **'Si la moto no arranca, esto lo explica. Puede ser a propósito, o puede que se quedara así después de una protección.'**
  String get verdictConfigDischargeOffBody;

  /// No description provided for @verdictConfigBalanceStartLowTitle.
  ///
  /// In es, this message translates to:
  /// **'El balanceo empieza donde el voltaje no dice nada'**
  String get verdictConfigBalanceStartLowTitle;

  /// No description provided for @verdictConfigBalanceStartLowBody.
  ///
  /// In es, this message translates to:
  /// **'Empieza a {value} V por celda, y para esta química lo normal es cerca de {limit} V. En la parte plana de la curva un milivoltio no significa carga, así que el balanceador puede mover energía en la dirección equivocada.'**
  String verdictConfigBalanceStartLowBody(String value, String limit);

  /// No description provided for @verdictConfigChangedSinceDayOneTitle.
  ///
  /// In es, this message translates to:
  /// **'La configuración no es la del día uno'**
  String get verdictConfigChangedSinceDayOneTitle;

  /// No description provided for @verdictConfigChangedSinceDayOneBody.
  ///
  /// In es, this message translates to:
  /// **'{count} ajuste(s) han cambiado desde que se guardó el estado inicial. Si no fuiste tú, alguien ha tocado el BMS.'**
  String verdictConfigChangedSinceDayOneBody(String count);

  /// No description provided for @verdictConfigChemistryUnknownTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin química declarada no se auditan voltajes'**
  String get verdictConfigChemistryUnknownTitle;

  /// No description provided for @verdictConfigChemistryUnknownBody.
  ///
  /// In es, this message translates to:
  /// **'LFP y NMC se llevan casi un voltio por celda: con la química equivocada esta pantalla bendeciría un ajuste peligroso o condenaría uno normal. Dilo en el perfil de la batería y vuelve.'**
  String get verdictConfigChemistryUnknownBody;

  /// No description provided for @verdictConfigLooksSaneTitle.
  ///
  /// In es, this message translates to:
  /// **'La configuración es razonable'**
  String get verdictConfigLooksSaneTitle;

  /// No description provided for @verdictConfigLooksSaneBody.
  ///
  /// In es, this message translates to:
  /// **'Los cortes de voltaje, los de temperatura y los interruptores están donde deberían para esta química. Esto no dice nada sobre el estado de las celdas: es una revisión de los ajustes, no de la batería.'**
  String get verdictConfigLooksSaneBody;

  /// No description provided for @evidenceConfiguredSetting.
  ///
  /// In es, this message translates to:
  /// **'Configurado'**
  String get evidenceConfiguredSetting;

  /// No description provided for @evidenceSafeLimit.
  ///
  /// In es, this message translates to:
  /// **'Límite seguro'**
  String get evidenceSafeLimit;

  /// No description provided for @evidenceCellsSeen.
  ///
  /// In es, this message translates to:
  /// **'Celdas que se están leyendo'**
  String get evidenceCellsSeen;

  /// No description provided for @configAuditTitle.
  ///
  /// In es, this message translates to:
  /// **'Auditoría de configuración'**
  String get configAuditTitle;

  /// No description provided for @configAuditIntro.
  ///
  /// In es, this message translates to:
  /// **'Lo que el BMS está configurado para hacer, comparado con lo que aguantan las celdas que dijiste que lleva.'**
  String get configAuditIntro;

  /// No description provided for @configAuditOpen.
  ///
  /// In es, this message translates to:
  /// **'Auditar la configuración'**
  String get configAuditOpen;

  /// No description provided for @configAuditReadOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo lectura. La app no cambia nada en el BMS: solo le envía peticiones de lectura. Un valor mal escrito en una batería es un incendio, y el camino de escritura del protocolo está sacado a base de ingeniería inversa. Lo que haya que cambiar se cambia desde la app oficial del BMS, y esa decisión es tuya.'**
  String get configAuditReadOnly;

  /// No description provided for @configAuditSettings.
  ///
  /// In es, this message translates to:
  /// **'Todo lo que se ha mirado'**
  String get configAuditSettings;

  /// No description provided for @configAuditNoSettings.
  ///
  /// In es, this message translates to:
  /// **'El BMS todavía no ha mandado su configuración. Espera unos segundos con la batería conectada.'**
  String get configAuditNoSettings;

  /// No description provided for @configAuditChemistryRow.
  ///
  /// In es, this message translates to:
  /// **'Química declarada'**
  String get configAuditChemistryRow;

  /// No description provided for @configAuditNeedsProfile.
  ///
  /// In es, this message translates to:
  /// **'Completar el perfil'**
  String get configAuditNeedsProfile;

  /// No description provided for @alertNearCurrentLimit.
  ///
  /// In es, this message translates to:
  /// **'Corriente cerca del límite del BMS'**
  String get alertNearCurrentLimit;

  /// No description provided for @alertLinkLost.
  ///
  /// In es, this message translates to:
  /// **'Se perdió la conexión con la batería'**
  String get alertLinkLost;

  /// No description provided for @alertsNotifyTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos en la barra de notificaciones'**
  String get alertsNotifyTitle;

  /// No description provided for @alertsNotifyIntro.
  ///
  /// In es, this message translates to:
  /// **'Los avisos suenan en la barra de notificaciones con la app en segundo plano o la pantalla apagada (no si cierras la app deslizándola: entonces deja de leer la batería). Sin esto, un aviso a las tres de la mañana con el móvil en otra habitación no lo ve nadie.'**
  String get alertsNotifyIntro;

  /// No description provided for @alertsNotifyEnable.
  ///
  /// In es, this message translates to:
  /// **'Avisar en la barra de notificaciones'**
  String get alertsNotifyEnable;

  /// No description provided for @alertsNotifyDenied.
  ///
  /// In es, this message translates to:
  /// **'Android no ha dado permiso para notificar. Los avisos seguirán saliendo en pantalla y con vibración mientras mires la app, pero no llegarán con la app en segundo plano ni con la pantalla apagada.'**
  String get alertsNotifyDenied;

  /// No description provided for @alertsNotifyOneConnection.
  ///
  /// In es, this message translates to:
  /// **'Recuerda: el BMS acepta una sola conexión Bluetooth. Mientras el móvil esté conectado en segundo plano, la app oficial de tu BMS no podrá conectarse, y al revés.'**
  String get alertsNotifyOneConnection;

  /// No description provided for @alertsThresholdsTitle.
  ///
  /// In es, this message translates to:
  /// **'A partir de cuándo avisar'**
  String get alertsThresholdsTitle;

  /// No description provided for @alertsThresholdsIntro.
  ///
  /// In es, this message translates to:
  /// **'Los valores por defecto son conservadores. Si un aviso salta de más, muévelo hacia el lado que avisa menos: la diferencia entre celdas y la temperatura, hacia arriba; la carga baja, hacia abajo.'**
  String get alertsThresholdsIntro;

  /// No description provided for @alertsDeltaWarn.
  ///
  /// In es, this message translates to:
  /// **'Diferencia entre celdas'**
  String get alertsDeltaWarn;

  /// No description provided for @alertsTempWarn.
  ///
  /// In es, this message translates to:
  /// **'Temperatura'**
  String get alertsTempWarn;

  /// No description provided for @alertsLowChargeWarn.
  ///
  /// In es, this message translates to:
  /// **'Carga baja'**
  String get alertsLowChargeWarn;

  /// No description provided for @alertsResetDefaults.
  ///
  /// In es, this message translates to:
  /// **'Volver a los valores por defecto'**
  String get alertsResetDefaults;

  /// No description provided for @alertNotificationBodyDelta.
  ///
  /// In es, this message translates to:
  /// **'Las celdas se han separado {value} V. La más baja marca cuándo se acaba la batería.'**
  String alertNotificationBodyDelta(String value);

  /// No description provided for @alertNotificationBodyTemp.
  ///
  /// In es, this message translates to:
  /// **'{value} °C. Para y déjala enfriar antes de seguir.'**
  String alertNotificationBodyTemp(String value);

  /// No description provided for @alertNotificationBodyLow.
  ///
  /// In es, this message translates to:
  /// **'Queda {value} % de carga.'**
  String alertNotificationBodyLow(String value);

  /// No description provided for @alertNotificationBodyCritical.
  ///
  /// In es, this message translates to:
  /// **'Queda {value} % de carga. Busca dónde parar.'**
  String alertNotificationBodyCritical(String value);

  /// No description provided for @alertNotificationBodyCell.
  ///
  /// In es, this message translates to:
  /// **'Una celda está a {value} V, cerca del corte del BMS. Se puede quedar sin batería aunque el porcentaje aún parezca razonable.'**
  String alertNotificationBodyCell(String value);

  /// No description provided for @alertNotificationBodyFault.
  ///
  /// In es, this message translates to:
  /// **'El BMS ha levantado una protección. Mira la pantalla antes de seguir.'**
  String get alertNotificationBodyFault;

  /// No description provided for @alertNotificationBodyNearLimit.
  ///
  /// In es, this message translates to:
  /// **'{value} A, cerca de lo que el BMS permite. Si llega al límite, corta sin avisar.'**
  String alertNotificationBodyNearLimit(String value);

  /// No description provided for @alertNotificationBodyLinkLost.
  ///
  /// In es, this message translates to:
  /// **'La app dejó de recibir lecturas de la batería. Si estabas vigilando una carga, ya no se está vigilando.'**
  String get alertNotificationBodyLinkLost;

  /// No description provided for @alertNotificationBodyChargeTarget.
  ///
  /// In es, this message translates to:
  /// **'El BMS marca {value} %, lo que pediste. Es su contador, no una medición de las celdas.'**
  String alertNotificationBodyChargeTarget(String value);

  /// No description provided for @alertNotificationBodyChargeComplete.
  ///
  /// In es, this message translates to:
  /// **'La celda más alta está arriba y el cargador ya casi no mete corriente: la carga ha terminado.'**
  String get alertNotificationBodyChargeComplete;

  /// No description provided for @alertNotificationBodyChargeHot.
  ///
  /// In es, this message translates to:
  /// **'{value} °C mientras carga. Desenchufa y déjala enfriar.'**
  String alertNotificationBodyChargeHot(String value);

  /// No description provided for @alertNotificationBodyChargeSpread.
  ///
  /// In es, this message translates to:
  /// **'Las celdas se han separado {value} V al final de la carga. Es donde mejor se ve un desbalance.'**
  String alertNotificationBodyChargeSpread(String value);

  /// No description provided for @autoTripBlocked.
  ///
  /// In es, this message translates to:
  /// **'No pude grabar el viaje: falta el permiso de ubicación. Sin él la app no aprende tu autonomía.'**
  String get autoTripBlocked;

  /// No description provided for @rideSavedNotif.
  ///
  /// In es, this message translates to:
  /// **'Viaje guardado: {km} km, {whPerKm} Wh/km'**
  String rideSavedNotif(String km, String whPerKm);

  /// No description provided for @rideSavedNotifNoConsumption.
  ///
  /// In es, this message translates to:
  /// **'Viaje guardado: {km} km'**
  String rideSavedNotifNoConsumption(String km);

  /// No description provided for @representativeAsk.
  ///
  /// In es, this message translates to:
  /// **'¿Este viaje te representa?'**
  String get representativeAsk;

  /// No description provided for @representativeAskBodyUp.
  ///
  /// In es, this message translates to:
  /// **'Salió en {whPerKm} Wh/km, un {percent}% por encima de lo tuyo. Ya lo conté: tu autonomía pasó de {before} a {after} km.'**
  String representativeAskBodyUp(
    String whPerKm,
    String percent,
    String before,
    String after,
  );

  /// No description provided for @representativeAskBodyDown.
  ///
  /// In es, this message translates to:
  /// **'Salió en {whPerKm} Wh/km, un {percent}% por debajo de lo tuyo. Ya lo conté: tu autonomía pasó de {before} a {after} km.'**
  String representativeAskBodyDown(
    String whPerKm,
    String percent,
    String before,
    String after,
  );

  /// No description provided for @representativeAskBodyUpNoKm.
  ///
  /// In es, this message translates to:
  /// **'Salió en {whPerKm} Wh/km, un {percent}% por encima de lo tuyo. Ya lo conté: tu consumo aprendido pasó de {before} a {after} Wh/km.'**
  String representativeAskBodyUpNoKm(
    String whPerKm,
    String percent,
    String before,
    String after,
  );

  /// No description provided for @representativeAskBodyDownNoKm.
  ///
  /// In es, this message translates to:
  /// **'Salió en {whPerKm} Wh/km, un {percent}% por debajo de lo tuyo. Ya lo conté: tu consumo aprendido pasó de {before} a {after} Wh/km.'**
  String representativeAskBodyDownNoKm(
    String whPerKm,
    String percent,
    String before,
    String after,
  );

  /// No description provided for @representativeYes.
  ///
  /// In es, this message translates to:
  /// **'Es normal'**
  String get representativeYes;

  /// No description provided for @representativeNo.
  ///
  /// In es, this message translates to:
  /// **'Fue una excepción'**
  String get representativeNo;

  /// No description provided for @representativeDone.
  ///
  /// In es, this message translates to:
  /// **'Listo. Tu autonomía queda en {km} km.'**
  String representativeDone(String km);

  /// No description provided for @representativeDoneNoKm.
  ///
  /// In es, this message translates to:
  /// **'Listo. Tu consumo aprendido sigue en {whPerKm} Wh/km.'**
  String representativeDoneNoKm(String whPerKm);

  /// No description provided for @representativeMarkedException.
  ///
  /// In es, this message translates to:
  /// **'Listo. Ya no cuenta: tu autonomía queda en {km} km.'**
  String representativeMarkedException(String km);

  /// No description provided for @representativeMarkedExceptionNoKm.
  ///
  /// In es, this message translates to:
  /// **'Listo. Ya no cuenta: tu consumo aprendido queda en {whPerKm} Wh/km.'**
  String representativeMarkedExceptionNoKm(String whPerKm);

  /// No description provided for @representativeChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get representativeChange;

  /// No description provided for @tripRemeasure.
  ///
  /// In es, this message translates to:
  /// **'Volver a medir'**
  String get tripRemeasure;

  /// No description provided for @tripRemeasureWhy.
  ///
  /// In es, this message translates to:
  /// **'Si el Bluetooth se cortó durante el viaje, el consumo pudo quedar muy por debajo de lo real. Esto lo vuelve a calcular desde las lecturas guardadas del pack.'**
  String get tripRemeasureWhy;

  /// No description provided for @tripRemeasureDone.
  ///
  /// In es, this message translates to:
  /// **'Medido de nuevo: {whPerKm} Wh/km, antes {before} Wh/km.'**
  String tripRemeasureDone(String whPerKm, String before);

  /// No description provided for @tripRemeasureSame.
  ///
  /// In es, this message translates to:
  /// **'Ya estaba bien medido. No hay nada que cambiar.'**
  String get tripRemeasureSame;

  /// No description provided for @tripRemeasureFailed.
  ///
  /// In es, this message translates to:
  /// **'No quedan lecturas para volver a medir este viaje, así que se queda como estaba.'**
  String get tripRemeasureFailed;

  /// No description provided for @tripUphill.
  ///
  /// In es, this message translates to:
  /// **'Cuesta arriba'**
  String get tripUphill;

  /// No description provided for @tripFlat.
  ///
  /// In es, this message translates to:
  /// **'Llano'**
  String get tripFlat;

  /// No description provided for @tripDownhill.
  ///
  /// In es, this message translates to:
  /// **'Cuesta abajo'**
  String get tripDownhill;

  /// No description provided for @healthCardCyclesBms.
  ///
  /// In es, this message translates to:
  /// **'el BMS dice {n}'**
  String healthCardCyclesBms(String n);

  /// No description provided for @healthWeakCell.
  ///
  /// In es, this message translates to:
  /// **'La celda que manda'**
  String get healthWeakCell;

  /// No description provided for @healthWeakCellWhy.
  ///
  /// In es, this message translates to:
  /// **'El pack se apaga cuando la celda más baja llega al corte, no cuando la media llega. Todo lo que las demás todavía tienen por encima de ese punto no lo vas a usar.'**
  String get healthWeakCellWhy;

  /// No description provided for @healthWeakCellWhich.
  ///
  /// In es, this message translates to:
  /// **'Cuál es'**
  String get healthWeakCellWhich;

  /// No description provided for @healthWeakCellStrands.
  ///
  /// In es, this message translates to:
  /// **'Lo que deja sin usar'**
  String get healthWeakCellStrands;

  /// No description provided for @healthWeakCellResistance.
  ///
  /// In es, this message translates to:
  /// **'Cable de balanceo desde el día uno'**
  String get healthWeakCellResistance;

  /// No description provided for @healthWeakCellResistanceUp.
  ///
  /// In es, this message translates to:
  /// **'+{pct} % en el cable de la celda {cell}'**
  String healthWeakCellResistanceUp(String pct, String cell);

  /// No description provided for @healthWeakCellResistanceFlat.
  ///
  /// In es, this message translates to:
  /// **'Ningún cable se ha movido'**
  String get healthWeakCellResistanceFlat;

  /// No description provided for @healthWeakCellResistanceNoBaseline.
  ///
  /// In es, this message translates to:
  /// **'Hace falta una foto del día uno para comparar'**
  String get healthWeakCellResistanceNoBaseline;

  /// No description provided for @subjectCells.
  ///
  /// In es, this message translates to:
  /// **'Celdas'**
  String get subjectCells;

  /// No description provided for @subjectCapacity.
  ///
  /// In es, this message translates to:
  /// **'Capacidad'**
  String get subjectCapacity;

  /// No description provided for @subjectRange.
  ///
  /// In es, this message translates to:
  /// **'Autonomía'**
  String get subjectRange;

  /// No description provided for @subjectTemperature.
  ///
  /// In es, this message translates to:
  /// **'Temperatura'**
  String get subjectTemperature;

  /// No description provided for @subjectConfiguration.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get subjectConfiguration;

  /// No description provided for @subjectBmsClaims.
  ///
  /// In es, this message translates to:
  /// **'Lo que el BMS dice de sí mismo'**
  String get subjectBmsClaims;

  /// No description provided for @adviceCheckedAllFine.
  ///
  /// In es, this message translates to:
  /// **'Revisé {subjects}. Todo bien.'**
  String adviceCheckedAllFine(String subjects);

  /// No description provided for @adviceCheckedSomeFine.
  ///
  /// In es, this message translates to:
  /// **'Revisé {subjects}: bien.'**
  String adviceCheckedSomeFine(String subjects);

  /// No description provided for @adviceNotChecked.
  ///
  /// In es, this message translates to:
  /// **'De {subjects} todavía no puedo decir nada.'**
  String adviceNotChecked(String subjects);

  /// No description provided for @adviceCaveatsTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuánto vale esta medición'**
  String get adviceCaveatsTitle;

  /// No description provided for @chargeWatchRedundant.
  ///
  /// In es, this message translates to:
  /// **'Con el ajuste de arriba encendido la conexión ya se mantiene con la pantalla apagada, también mientras se recupera de un corte. Esto añade una cosa: mientras carga, la app no deja nunca de intentar reconectar. Sin esto se rinde tras unos seis minutos sin respuesta de la batería.'**
  String get chargeWatchRedundant;

  /// No description provided for @alertGroupSpread.
  ///
  /// In es, this message translates to:
  /// **'Celdas separadas'**
  String get alertGroupSpread;

  /// No description provided for @alertGroupHeat.
  ///
  /// In es, this message translates to:
  /// **'Temperatura'**
  String get alertGroupHeat;

  /// No description provided for @alertGroupRunningOut.
  ///
  /// In es, this message translates to:
  /// **'Te estás quedando sin carga'**
  String get alertGroupRunningOut;

  /// No description provided for @alertGroupChargeDone.
  ///
  /// In es, this message translates to:
  /// **'La carga terminó'**
  String get alertGroupChargeDone;

  /// No description provided for @alertGroupFaults.
  ///
  /// In es, this message translates to:
  /// **'Fallos y límites'**
  String get alertGroupFaults;

  /// No description provided for @alertWhenRiding.
  ///
  /// In es, this message translates to:
  /// **'Rodando'**
  String get alertWhenRiding;

  /// No description provided for @alertWhenCharging.
  ///
  /// In es, this message translates to:
  /// **'Cargando'**
  String get alertWhenCharging;

  /// No description provided for @alertWhenTopOfCharge.
  ///
  /// In es, this message translates to:
  /// **'Al final de la carga'**
  String get alertWhenTopOfCharge;

  /// No description provided for @alertTargetReachedShort.
  ///
  /// In es, this message translates to:
  /// **'Llegó al objetivo que pusiste'**
  String get alertTargetReachedShort;

  /// No description provided for @alertBmsHot.
  ///
  /// In es, this message translates to:
  /// **'El BMS está caliente'**
  String get alertBmsHot;

  /// No description provided for @alertWhenBmsMosfet.
  ///
  /// In es, this message translates to:
  /// **'El BMS (MOSFET)'**
  String get alertWhenBmsMosfet;

  /// No description provided for @alertNotificationBodyBmsHot.
  ///
  /// In es, this message translates to:
  /// **'El MOSFET del BMS está a {value} °C. No es la batería: es la pieza que corta la corriente si sigue subiendo. Afloja y dale aire.'**
  String alertNotificationBodyBmsHot(String value);

  /// No description provided for @statusBmsHotWatch.
  ///
  /// In es, this message translates to:
  /// **'BMS caliente: {temp} °C'**
  String statusBmsHotWatch(String temp);

  /// No description provided for @statusBmsHotBad.
  ///
  /// In es, this message translates to:
  /// **'BMS demasiado caliente: {temp} °C'**
  String statusBmsHotBad(String temp);

  /// No description provided for @adviceBmsHotTitle.
  ///
  /// In es, this message translates to:
  /// **'El BMS está caliente'**
  String get adviceBmsHotTitle;

  /// No description provided for @adviceBmsHotBody.
  ///
  /// In es, this message translates to:
  /// **'Su MOSFET llegó a {temp} °C. No es la batería, pero es la pieza que corta la corriente si sigue subiendo. Fíjate que el BMS tenga aire y no esté pegado a algo que dé calor.'**
  String adviceBmsHotBody(String temp);

  /// No description provided for @evidenceMosfetTemp.
  ///
  /// In es, this message translates to:
  /// **'MOSFET del BMS'**
  String get evidenceMosfetTemp;

  /// No description provided for @thermalMirrorNote.
  ///
  /// In es, this message translates to:
  /// **'La sonda 5 de este BMS repite la temperatura del MOSFET, así que no se cuenta como sonda de la batería.'**
  String get thermalMirrorNote;

  /// No description provided for @thermalLegendMosfet.
  ///
  /// In es, this message translates to:
  /// **'MOSFET (sin sondas en la batería)'**
  String get thermalLegendMosfet;

  /// No description provided for @balanceWhichCellsReported.
  ///
  /// In es, this message translates to:
  /// **'{cells} (lo informa el BMS)'**
  String balanceWhichCellsReported(String cells);

  /// No description provided for @balanceWhichCellsNoneReported.
  ///
  /// In es, this message translates to:
  /// **'ninguna ahora (lo informa el BMS)'**
  String get balanceWhichCellsNoneReported;

  /// No description provided for @balancerStoppedByHeat.
  ///
  /// In es, this message translates to:
  /// **'detenido por calor'**
  String get balancerStoppedByHeat;

  /// No description provided for @alertNotificationBodyCellTypical.
  ///
  /// In es, this message translates to:
  /// **'Una celda está a {value} V, cerca de {cutoff} V, el corte habitual para esta química (el BMS no informó el suyo). Se puede quedar sin batería aunque el porcentaje aún parezca razonable.'**
  String alertNotificationBodyCellTypical(String value, String cutoff);

  /// No description provided for @alertNotificationBodyCellAssumed.
  ///
  /// In es, this message translates to:
  /// **'Una celda está a {value} V, cerca de {cutoff} V, un corte supuesto: el BMS no informó el suyo y no se sabe la química del pack. Se puede quedar sin batería aunque el porcentaje aún parezca razonable.'**
  String alertNotificationBodyCellAssumed(String value, String cutoff);

  /// No description provided for @alertNearLimitUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No disponible por ahora: este BMS no ha informado su límite de corriente. Un ANT lo da cuando la app se lo pide, si contesta.'**
  String get alertNearLimitUnavailable;

  /// No description provided for @sessionEnergyIn.
  ///
  /// In es, this message translates to:
  /// **'Energía que entró al pack'**
  String get sessionEnergyIn;

  /// No description provided for @sessionEnergyHint.
  ///
  /// In es, this message translates to:
  /// **'Desde que se conectó el pack. Solo cuenta los momentos en que llegaban lecturas.'**
  String get sessionEnergyHint;

  /// No description provided for @healthWeakCellStrandsNeedsRest.
  ///
  /// In es, this message translates to:
  /// **'Hace falta una lectura en reposo, sin corriente. En LFP, además, fuera de la zona plana de la curva.'**
  String get healthWeakCellStrandsNeedsRest;

  /// No description provided for @healthWeakCellStrandsAge.
  ///
  /// In es, this message translates to:
  /// **'De la última lectura en reposo, hace {minutes} min.'**
  String healthWeakCellStrandsAge(String minutes);

  /// No description provided for @degSoldUnmeasured.
  ///
  /// In es, this message translates to:
  /// **'Todavía sin medir contra lo anunciado: hace falta una descarga completa.'**
  String get degSoldUnmeasured;

  /// No description provided for @degConfiguredTitle.
  ///
  /// In es, this message translates to:
  /// **'Capacidad configurada'**
  String get degConfiguredTitle;

  /// No description provided for @healthVerdictReported.
  ///
  /// In es, this message translates to:
  /// **'Sin medir todavía'**
  String get healthVerdictReported;

  /// No description provided for @healthWeakCellResistanceHint.
  ///
  /// In es, this message translates to:
  /// **'El BMS mide la resistencia del cable de balanceo y su conexión, no la de la celda. Si sube, lo primero a revisar es ese cable.'**
  String get healthWeakCellResistanceHint;

  /// No description provided for @cellsResistanceNote.
  ///
  /// In es, this message translates to:
  /// **'Los mΩ bajo cada celda son la resistencia de su cable de balanceo y la conexión, que es lo que mide el BMS. No son la resistencia interna de la celda.'**
  String get cellsResistanceNote;

  /// No description provided for @rangeFullFromBms.
  ///
  /// In es, this message translates to:
  /// **'Sale de la capacidad configurada en el BMS, no de una medida.'**
  String get rangeFullFromBms;

  /// No description provided for @reportRangeFromBmsConfig.
  ///
  /// In es, this message translates to:
  /// **'capacidad configurada en el BMS'**
  String get reportRangeFromBmsConfig;

  /// No description provided for @capacityOfConfigured.
  ///
  /// In es, this message translates to:
  /// **'{pct} % de la configurada'**
  String capacityOfConfigured(String pct);

  /// No description provided for @historyItemDrift.
  ///
  /// In es, this message translates to:
  /// **'Qué celda se va separando de las demás con las semanas'**
  String get historyItemDrift;

  /// No description provided for @trendsCapacityNotEnough.
  ///
  /// In es, this message translates to:
  /// **'Cada punto es una descarga completa medida con la app conectada, así que no se llena sola: hacen falta al menos tres.'**
  String get trendsCapacityNotEnough;

  /// No description provided for @profileCaptureBaselineHintNoSettings.
  ///
  /// In es, this message translates to:
  /// **'Las celdas tal como están ahora. Este BMS no informa resistencias, y su configuración no entra en la foto, así que la foto guarda lo demás. Todo lo que la app diga después sobre derivas se compara contra esto. Mejor con la batería en reposo.'**
  String get profileCaptureBaselineHintNoSettings;

  /// No description provided for @profileConfigNotCompared.
  ///
  /// In es, this message translates to:
  /// **'Sin comparar'**
  String get profileConfigNotCompared;

  /// No description provided for @profileDriftOtherCharge.
  ///
  /// In es, this message translates to:
  /// **'a otro nivel de carga, no comparable'**
  String get profileDriftOtherCharge;

  /// No description provided for @adviceCycleMismatchTitle.
  ///
  /// In es, this message translates to:
  /// **'El contador de ciclos no cuadra'**
  String get adviceCycleMismatchTitle;

  /// No description provided for @adviceCycleMismatchBody.
  ///
  /// In es, this message translates to:
  /// **'El BMS dice {bms} ciclos, y la carga que él mismo contó pasar por el pack da {equivalent} ciclos equivalentes. Cada firmware cuenta los ciclos a su manera y ese contador se puede editar, así que la diferencia puede ir para cualquier lado. Si vas a comprar o vender un pack, cita los dos.'**
  String adviceCycleMismatchBody(String bms, String equivalent);

  /// No description provided for @verdictDeltaLightTitle.
  ///
  /// In es, this message translates to:
  /// **'Bajo carga ligera no se ve nada raro'**
  String get verdictDeltaLightTitle;

  /// No description provided for @verdictDeltaLightBody.
  ///
  /// In es, this message translates to:
  /// **'Con corriente el delta llega a {loaded} V, contra {rest} V en reposo. Pero no ha habido carga fuerte suficiente para que una mala conexión se note, así que esto todavía no descarta nada.'**
  String verdictDeltaLightBody(String loaded, String rest);

  /// No description provided for @adviceBmsClaimsOkTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que el BMS dice cuadra'**
  String get adviceBmsClaimsOkTitle;

  /// No description provided for @adviceBmsClaimsOkBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que se pudo comprobar de lo que el BMS dice de sí mismo coincide con lo que se mide: el contador de ciclos con la carga que pasó, o el porcentaje con las celdas en un extremo de la carga.'**
  String get adviceBmsClaimsOkBody;

  /// No description provided for @adviceTemperatureOkTitle.
  ///
  /// In es, this message translates to:
  /// **'Temperatura normal'**
  String get adviceTemperatureOkTitle;

  /// No description provided for @adviceTemperatureOkBody.
  ///
  /// In es, this message translates to:
  /// **'La sonda más caliente de la batería marca {temp} °C, y el BMS tampoco está caliente.'**
  String adviceTemperatureOkBody(String temp);

  /// No description provided for @adviceConfigNothingFlaggedTitle.
  ///
  /// In es, this message translates to:
  /// **'Nada que objetar aquí'**
  String get adviceConfigNothingFlaggedTitle;

  /// No description provided for @adviceConfigNothingFlaggedBody.
  ///
  /// In es, this message translates to:
  /// **'El límite de carga por celda está en {voltage} V, que no pasa de lo razonable. Esta pantalla solo mira eso; la revisión completa está en Auditar la configuración, en Sistema.'**
  String adviceConfigNothingFlaggedBody(String voltage);

  /// No description provided for @verdictConfigColdCutoffMarginalTitle.
  ///
  /// In es, this message translates to:
  /// **'El corte por frío tiene poco margen'**
  String get verdictConfigColdCutoffMarginalTitle;

  /// No description provided for @verdictConfigColdCutoffMarginalBody.
  ///
  /// In es, this message translates to:
  /// **'El corte por frío está en {value} °C: por encima de cero, pero justo. La sonda mide el exterior del pack y las celdas por dentro tardan en calentarse. Súbelo a {limit} °C o más desde la app oficial del BMS.'**
  String verdictConfigColdCutoffMarginalBody(String value, String limit);

  /// No description provided for @balanceRankingEntry.
  ///
  /// In es, this message translates to:
  /// **'celda {cell}: {pct} %'**
  String balanceRankingEntry(String cell, String pct);

  /// No description provided for @capacityNoFullMark.
  ///
  /// In es, this message translates to:
  /// **'No se sabe dónde está lleno este pack: el BMS no ha dicho a cuánto carga y la química no se conoce. Indícala en los datos del pack para poder empezar el test.'**
  String get capacityNoFullMark;

  /// No description provided for @capacityStopEarly.
  ///
  /// In es, this message translates to:
  /// **'Terminar aquí'**
  String get capacityStopEarly;

  /// No description provided for @capacityStopEarlyHint.
  ///
  /// In es, this message translates to:
  /// **'Si terminas antes del corte se guarda como parcial: lo contado es real, pero es un pedazo del pack y no se convierte en capacidad.'**
  String get capacityStopEarlyHint;

  /// No description provided for @capacityPartialTag.
  ///
  /// In es, this message translates to:
  /// **'parcial'**
  String get capacityPartialTag;

  /// No description provided for @capacityLegacyTag.
  ///
  /// In es, this message translates to:
  /// **'antigua'**
  String get capacityLegacyTag;

  /// No description provided for @capacityChargedTag.
  ///
  /// In es, this message translates to:
  /// **'cargada a mitad'**
  String get capacityChargedTag;

  /// No description provided for @capacityUntrustedNote.
  ///
  /// In es, this message translates to:
  /// **'Las marcadas no cuentan como capacidad. «parcial»: terminó antes del corte. «antigua»: se cerró con el porcentaje del BMS, que se calcula contra la capacidad configurada, así que devolvía esa configuración y no lo que tiene la batería. «cargada a mitad»: entró corriente por el camino.'**
  String get capacityUntrustedNote;

  /// No description provided for @chargeGapNote.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min sin conexión por el camino: esa parte la contó el BMS, no la app.'**
  String chargeGapNote(String minutes);

  /// No description provided for @etaNearlyFull.
  ///
  /// In es, this message translates to:
  /// **'Casi lleno'**
  String get etaNearlyFull;

  /// No description provided for @chargeTargetAtTop.
  ///
  /// In es, this message translates to:
  /// **'Desde el {soc} % este aviso es el de carga terminada: el contador del BMS llega ahí antes que las celdas, así que avisa cuando la celda más alta está arriba y la corriente ya bajó.'**
  String chargeTargetAtTop(String soc);

  /// No description provided for @alertsTempWarnHint.
  ///
  /// In es, this message translates to:
  /// **'Rodando avisa desde aquí. Cargando, desde aquí o desde {limit} °C, lo que sea menor: cargar más caliente daña las celdas, así que ese límite no se sube.'**
  String alertsTempWarnHint(String limit);

  /// No description provided for @alertsDeltaWarnHint.
  ///
  /// In es, this message translates to:
  /// **'Rodando avisa desde aquí. Al final de la carga, desde aquí o desde {limit} mV, lo que sea menor: arriba la curva es empinada y esa diferencia ya es un desbalance.'**
  String alertsDeltaWarnHint(String limit);

  /// No description provided for @alertNotificationBodyCriticalIdle.
  ///
  /// In es, this message translates to:
  /// **'Queda {value} % de carga. Cárgala antes de salir.'**
  String alertNotificationBodyCriticalIdle(String value);

  /// No description provided for @alertsNotifyQuietChannel.
  ///
  /// In es, this message translates to:
  /// **'Avisos sin vibración'**
  String get alertsNotifyQuietChannel;

  /// No description provided for @alertLinkLostNeedsWatch.
  ///
  /// In es, this message translates to:
  /// **'Solo avisa con «Seguir leyendo con la pantalla apagada» o «Vigilar la carga» encendidos: sin ellos no hay nada vigilando la conexión.'**
  String get alertLinkLostNeedsWatch;

  /// No description provided for @alertLinkLostRidingHint.
  ///
  /// In es, this message translates to:
  /// **'Mientras grabas un viaje no avisa: rodando la conexión va y viene, y el viaje ya muestra en pantalla cuándo se corta.'**
  String get alertLinkLostRidingHint;

  /// No description provided for @alertsLowChargeWarnHint.
  ///
  /// In es, this message translates to:
  /// **'Avisa al bajar de aquí. Bájalo si te avisa demasiado pronto; súbelo si quieres enterarte antes.'**
  String get alertsLowChargeWarnHint;

  /// No description provided for @stuckTitle.
  ///
  /// In es, this message translates to:
  /// **'El Bluetooth del teléfono parece atascado'**
  String get stuckTitle;

  /// No description provided for @stuckBody.
  ///
  /// In es, this message translates to:
  /// **'Varios intentos seguidos han fallado con la batería al alcance. Prueba esto en orden y para en cuanto vuelva a conectar:'**
  String get stuckBody;

  /// No description provided for @stuckResetButton.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar la conexión Bluetooth de la app'**
  String get stuckResetButton;

  /// No description provided for @stuckStepForceStop.
  ///
  /// In es, this message translates to:
  /// **'Si no basta, fuerza la detención de la app (Ajustes > Aplicaciones > JK BMS + > Forzar detención) y vuelve a abrirla.'**
  String get stuckStepForceStop;

  /// No description provided for @stuckStepScanning.
  ///
  /// In es, this message translates to:
  /// **'Después, desactiva «Búsqueda de Bluetooth» (Ajustes > Ubicación > Servicios de ubicación) y apaga y enciende el Bluetooth. Con esa búsqueda activada, apagar el Bluetooth no lo reinicia de verdad.'**
  String get stuckStepScanning;

  /// No description provided for @stuckStepRestart.
  ///
  /// In es, this message translates to:
  /// **'Como último recurso, reinicia el teléfono.'**
  String get stuckStepRestart;

  /// No description provided for @stuckAskWhichStep.
  ///
  /// In es, this message translates to:
  /// **'Cuando vuelva a conectar, avisa de qué paso lo arregló: eso dice si el fallo está en la app o en Android.'**
  String get stuckAskWhichStep;

  /// No description provided for @stuckResetDone.
  ///
  /// In es, this message translates to:
  /// **'Conexión Bluetooth de la app reiniciada. Vuelve a tocar la batería.'**
  String get stuckResetDone;

  /// No description provided for @stuckResetRunning.
  ///
  /// In es, this message translates to:
  /// **'Reiniciando la conexión Bluetooth de la app…'**
  String get stuckResetRunning;

  /// No description provided for @consoleReportAttempts.
  ///
  /// In es, this message translates to:
  /// **'Intentos de conexión, del más reciente al más antiguo'**
  String get consoleReportAttempts;

  /// No description provided for @tripNoGpsFixes.
  ///
  /// In es, this message translates to:
  /// **'No está llegando el GPS, así que este viaje no está midiendo distancia ni velocidad. La app lo está reintentando. Si sigue así, abre la app un momento con la pantalla encendida y comprueba que la ubicación esté activada.'**
  String get tripNoGpsFixes;

  /// No description provided for @locationApproximateOnly.
  ///
  /// In es, this message translates to:
  /// **'La app solo tiene permiso de ubicación aproximada, y con eso no se puede medir un viaje: cada posición viene con cientos de metros de error. Activa \"Usar ubicación precisa\" en Ajustes > Aplicaciones > JK BMS + > Permisos > Ubicación, y vuelve a empezar el viaje.'**
  String get locationApproximateOnly;

  /// No description provided for @inspectionCaveatRecoveryNoLoad.
  ///
  /// In es, this message translates to:
  /// **'Sin carga fuerte tampoco hay recuperación que medir.'**
  String get inspectionCaveatRecoveryNoLoad;

  /// No description provided for @inspectionCaveatEndedBeforeLoad.
  ///
  /// In es, this message translates to:
  /// **'La prueba se terminó antes de la carga: ni la caída por celda ni la recuperación se midieron.'**
  String get inspectionCaveatEndedBeforeLoad;

  /// No description provided for @inspectionCaveatEndedBeforeRecovery.
  ///
  /// In es, this message translates to:
  /// **'La prueba se terminó mientras las celdas volvían: la recuperación no se midió.'**
  String get inspectionCaveatEndedBeforeRecovery;

  /// No description provided for @inspectionCaveatRecoveryLinkGap.
  ///
  /// In es, this message translates to:
  /// **'Se cortó la conexión con el BMS mientras las celdas volvían: la recuperación no se midió, porque el tiempo habría sido el del corte.'**
  String get inspectionCaveatRecoveryLinkGap;

  /// No description provided for @inspectionCaveatLinkGaps.
  ///
  /// In es, this message translates to:
  /// **'La conexión con el BMS se cortó durante la prueba. Los pasos en los que cayó el corte volvieron a contar desde cero.'**
  String get inspectionCaveatLinkGaps;

  /// No description provided for @verdictInspCellRisingTitle.
  ///
  /// In es, this message translates to:
  /// **'La celda {cell} sube mucho más que las demás'**
  String verdictInspCellRisingTitle(String cell);

  /// No description provided for @verdictInspCellRisingBody.
  ///
  /// In es, this message translates to:
  /// **'Con el cargador subió {excess} V más que la mediana del pack: unos {ohms} mΩ de resistencia de más. Coherente con una celda gastada o con una conexión mala en esa celda. Es la razón principal para no pagar el precio pedido sin más pruebas.'**
  String verdictInspCellRisingBody(String excess, String ohms);

  /// No description provided for @verdictInspSagUniformChargeTitle.
  ///
  /// In es, this message translates to:
  /// **'Todas las celdas suben parejo'**
  String get verdictInspSagUniformChargeTitle;

  /// No description provided for @verdictInspSagUniformChargeBody.
  ///
  /// In es, this message translates to:
  /// **'Con el cargador ({amps} A) la celda que más subió lo hizo solo {excess} V más que la mediana. A esta corriente ya se distinguiría una celda con unos {floor} mΩ de resistencia de más, y ninguna se aparta de las demás.'**
  String verdictInspSagUniformChargeBody(
    String amps,
    String excess,
    String floor,
  );

  /// No description provided for @verdictInspSagUnresolvedTitle.
  ///
  /// In es, this message translates to:
  /// **'Carga insuficiente para descartar una celda mala'**
  String get verdictInspSagUnresolvedTitle;

  /// No description provided for @verdictInspSagUnresolvedBody.
  ///
  /// In es, this message translates to:
  /// **'A esta carga ({amps} A) no se distingue una celda con menos de {floor} mΩ extra, y una celda mala puede tener menos que eso. Las celdas se movieron parejas, pero con tan poca corriente eso no descarta nada. Repite rodando con carga real (una cuesta o acelerar fuerte), o con el cargador.'**
  String verdictInspSagUnresolvedBody(String amps, String floor);

  /// No description provided for @verdictInspRecoveryNotDiscriminatingTitle.
  ///
  /// In es, this message translates to:
  /// **'Con esta carga la recuperación no dice nada'**
  String get verdictInspRecoveryNotDiscriminatingTitle;

  /// No description provided for @verdictInspRecoveryNotDiscriminatingBody.
  ///
  /// In es, this message translates to:
  /// **'Las celdas volvieron a su reposo en unos {seconds} s. Con esta carga ({amps} A) la recuperación no discrimina: una celda cansada vuelve casi tan rápido como una buena. Para que cuente hace falta un tirón de al menos un tercio de la capacidad del pack.'**
  String verdictInspRecoveryNotDiscriminatingBody(String seconds, String amps);

  /// No description provided for @verdictInspHotRestBody.
  ///
  /// In es, this message translates to:
  /// **'Llegó a {temp} °C en reposo o con solo las luces. Un pack caliente sin carga no es normal: o venía de un uso fuerte justo antes, o algo dentro se calienta solo.'**
  String verdictInspHotRestBody(String temp);

  /// No description provided for @verdictInspHotLoadBody.
  ///
  /// In es, this message translates to:
  /// **'Llegó a {temp} °C durante la carga fuerte o justo después. Un tirón de unos segundos no calienta tanto un pack sano: o ya venía caliente, o algo se calienta de más bajo carga.'**
  String verdictInspHotLoadBody(String temp);

  /// No description provided for @evidenceInspectionRestDelta.
  ///
  /// In es, this message translates to:
  /// **'Delta en reposo (mediana de cada celda en reposo)'**
  String get evidenceInspectionRestDelta;

  /// No description provided for @evidenceExcessResistance.
  ///
  /// In es, this message translates to:
  /// **'Resistencia de más, celda {cell}'**
  String evidenceExcessResistance(String cell);

  /// No description provided for @evidenceDetectionFloor.
  ///
  /// In es, this message translates to:
  /// **'Lo mínimo que se distingue a esta carga'**
  String get evidenceDetectionFloor;

  /// No description provided for @evidenceLoadWasCharge.
  ///
  /// In es, this message translates to:
  /// **'Carga usada'**
  String get evidenceLoadWasCharge;

  /// No description provided for @evidenceLoadCharger.
  ///
  /// In es, this message translates to:
  /// **'el cargador'**
  String get evidenceLoadCharger;

  /// No description provided for @evidenceSeenDuringStep.
  ///
  /// In es, this message translates to:
  /// **'Cuándo se vio'**
  String get evidenceSeenDuringStep;

  /// No description provided for @evidenceStepRest.
  ///
  /// In es, this message translates to:
  /// **'en reposo'**
  String get evidenceStepRest;

  /// No description provided for @evidenceStepLight.
  ///
  /// In es, this message translates to:
  /// **'con las luces'**
  String get evidenceStepLight;

  /// No description provided for @evidenceStepHeavy.
  ///
  /// In es, this message translates to:
  /// **'con la carga fuerte'**
  String get evidenceStepHeavy;

  /// No description provided for @evidenceStepRecovery.
  ///
  /// In es, this message translates to:
  /// **'al soltar la carga'**
  String get evidenceStepRecovery;

  /// No description provided for @inspectionFidelityNoteUnmeasured.
  ///
  /// In es, this message translates to:
  /// **'Sin una carga suficiente este test no ha podido buscar la celda mala: lo de arriba es solo lo que se ve en reposo. Tampoco mide capacidad real; para eso hace falta una descarga completa.'**
  String get inspectionFidelityNoteUnmeasured;

  /// No description provided for @inspectionLightUnresolved.
  ///
  /// In es, this message translates to:
  /// **'Sin veredicto: la carga no bastó para descartar una celda mala'**
  String get inspectionLightUnresolved;

  /// No description provided for @inspectionUnresolvedBody.
  ///
  /// In es, this message translates to:
  /// **'Hubo carga, pero poca: a esa corriente una celda mala puede moverse igual que las buenas, así que aquí no hay nada sobre esta batería ni a favor ni en contra. Repítelo con más corriente: rodando con carga real (una cuesta o acelerar fuerte), o con el cargador.'**
  String get inspectionUnresolvedBody;

  /// No description provided for @inspectionLightUnmeasuredShort.
  ///
  /// In es, this message translates to:
  /// **'Sin veredicto'**
  String get inspectionLightUnmeasuredShort;

  /// No description provided for @verdictInspRepeatConfigChangedTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambió la configuración o los contadores entre visitas'**
  String get verdictInspRepeatConfigChangedTitle;

  /// No description provided for @verdictInspRepeatConfigChangedBody.
  ///
  /// In es, this message translates to:
  /// **'Entre las dos pruebas cambió la capacidad configurada, o subió la salud que reporta el BMS. Puede ser el dueño corrigiendo un ajuste o el firmware recalculando, y no tiene por qué ser un engaño, pero pregunta qué se tocó. Lo físico de arriba no depende de estos números.'**
  String get verdictInspRepeatConfigChangedBody;

  /// No description provided for @evidencePreviousCycleCapacity.
  ///
  /// In es, this message translates to:
  /// **'Energía total contada el {date}'**
  String evidencePreviousCycleCapacity(String date);

  /// No description provided for @evidenceCycleCapacity.
  ///
  /// In es, this message translates to:
  /// **'Energía total contada por el BMS'**
  String get evidenceCycleCapacity;

  /// No description provided for @certificateIssuedHere.
  ///
  /// In es, this message translates to:
  /// **'Emitido por este teléfono.'**
  String get certificateIssuedHere;

  /// No description provided for @certificateDoesNotProve.
  ///
  /// In es, this message translates to:
  /// **'Lo que la firma no demuestra: qué batería se probó (el nombre y el número de serie los da el BMS y se pueden cambiar), ni la fecha, que es la del reloj del teléfono que firmó, ni que la batería esté bien.'**
  String get certificateDoesNotProve;

  /// No description provided for @certificateSimulated.
  ///
  /// In es, this message translates to:
  /// **'PRUEBA CON PACK SIMULADO. Estas cifras salieron del simulador de la app, no de una batería.'**
  String get certificateSimulated;

  /// No description provided for @certificateSimulatedUnknown.
  ///
  /// In es, this message translates to:
  /// **'Certificado de una versión anterior de la app: no dice si la prueba se hizo con una batería o con el pack simulado.'**
  String get certificateSimulatedUnknown;

  /// No description provided for @certificateNoSimulated.
  ///
  /// In es, this message translates to:
  /// **'Un ensayo con el pack simulado no se puede firmar: un certificado dice que las cifras salieron de una batería.'**
  String get certificateNoSimulated;

  /// No description provided for @certificateLocalIssuer.
  ///
  /// In es, this message translates to:
  /// **'Código de emisor de este teléfono'**
  String get certificateLocalIssuer;

  /// No description provided for @certificateLocalIssuerHint.
  ///
  /// In es, this message translates to:
  /// **'Es el código que verá quien compruebe un certificado firmado en este teléfono. Publícalo donde te conozcan (tu anuncio, tu taller) para que puedan compararlo.'**
  String get certificateLocalIssuerHint;

  /// No description provided for @inspectionSimulatedBanner.
  ///
  /// In es, this message translates to:
  /// **'PRUEBA CON PACK SIMULADO. Nada de esto es de una batería real.'**
  String get inspectionSimulatedBanner;

  /// No description provided for @reportCertificateIssuerCheck.
  ///
  /// In es, this message translates to:
  /// **'Comprueba que este código de emisor es el que publica quien te dio el certificado.'**
  String get reportCertificateIssuerCheck;

  /// No description provided for @reportPackLabel.
  ///
  /// In es, this message translates to:
  /// **'Batería'**
  String get reportPackLabel;

  /// No description provided for @reportCurrentStep.
  ///
  /// In es, this message translates to:
  /// **'Escalón de corriente (carga menos reposo)'**
  String get reportCurrentStep;

  /// No description provided for @reportMedianRise.
  ///
  /// In es, this message translates to:
  /// **'Subida mediana con el cargador'**
  String get reportMedianRise;

  /// No description provided for @inspectionCellHeaderChange.
  ///
  /// In es, this message translates to:
  /// **'Cambio'**
  String get inspectionCellHeaderChange;

  /// No description provided for @inspectionSaveTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar esta prueba'**
  String get inspectionSaveTitle;

  /// No description provided for @reportHonestyInspectionUnmeasured.
  ///
  /// In es, this message translates to:
  /// **'Test rápido del {date} sin una carga suficiente: no se ha podido buscar la celda mala, y esta hoja no dice nada a favor ni en contra de la batería. No mide capacidad: la capacidad que aparece es la configurada en el BMS, no una medida.'**
  String reportHonestyInspectionUnmeasured(String date);

  /// No description provided for @reportSeriesNoteUnsigned.
  ///
  /// In es, this message translates to:
  /// **'Cada fila es una inspección guardada en el teléfono que hizo esta hoja, incluida esta, que es la última. Esta hoja no está firmada. Repetir el test es lo que distingue una celda mala de una lectura mala.'**
  String get reportSeriesNoteUnsigned;

  /// No description provided for @reportChange.
  ///
  /// In es, this message translates to:
  /// **'Cambio (V)'**
  String get reportChange;

  /// No description provided for @reportCellTableNoteCharge.
  ///
  /// In es, this message translates to:
  /// **'El cambio es cuánto subió cada celda con el cargador. La resistencia se estima del salto de corriente, no se mide con instrumento.'**
  String get reportCellTableNoteCharge;

  /// No description provided for @inspectionDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get inspectionDeleteConfirm;

  /// No description provided for @inspectionSaveNoStore.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar: el almacenamiento de la app no está disponible.'**
  String get inspectionSaveNoStore;

  /// No description provided for @autoTripPocketNeedsLinkWatch.
  ///
  /// In es, this message translates to:
  /// **'Con «Seguir leyendo con la pantalla apagada» desactivado, la app deja de leer el pack al apagarse la pantalla, así que con el móvil en el bolsillo no puede empezar ningún viaje.'**
  String get autoTripPocketNeedsLinkWatch;

  /// No description provided for @autoTripPocketWhileInUse.
  ///
  /// In es, this message translates to:
  /// **'Con el móvil en el bolsillo funciona mientras siga puesta la notificación que la app abrió al conectar con la pantalla encendida. Si Android la cierra, o la app se reconecta sola con la pantalla apagada, el GPS solo responde con la ubicación permitida todo el tiempo, y sin GPS el viaje no empieza.'**
  String get autoTripPocketWhileInUse;

  /// No description provided for @autoTripPocketAllowAlways.
  ///
  /// In es, this message translates to:
  /// **'Permitir la ubicación todo el tiempo'**
  String get autoTripPocketAllowAlways;

  /// No description provided for @autoTripPocketSettingsHint.
  ///
  /// In es, this message translates to:
  /// **'En los ajustes de la app, entra en Permisos, Ubicación, y elige «Permitir todo el tiempo».'**
  String get autoTripPocketSettingsHint;

  /// No description provided for @autoTripPocketAlways.
  ///
  /// In es, this message translates to:
  /// **'Ubicación permitida todo el tiempo: el viaje puede empezar con el móvil en el bolsillo aunque la app se haya reconectado sola.'**
  String get autoTripPocketAlways;

  /// No description provided for @offlineWeakestRestValue.
  ///
  /// In es, this message translates to:
  /// **'celda {index}, la más baja en el {pct} % de {count} lecturas en reposo del último mes'**
  String offlineWeakestRestValue(String index, String pct, String count);

  /// No description provided for @offlineLowestLastReading.
  ///
  /// In es, this message translates to:
  /// **'Celda más baja en la última lectura'**
  String get offlineLowestLastReading;

  /// No description provided for @historyAverageOf.
  ///
  /// In es, this message translates to:
  /// **'de {used} de {total} viajes: los medidos que cuentan para la autonomía'**
  String historyAverageOf(String used, String total);

  /// No description provided for @learnWhyUnmeasured.
  ///
  /// In es, this message translates to:
  /// **'{n} no se pudieron medir: la conexión con la batería se cortó durante buena parte del viaje y no quedaron lecturas para saber cuánta energía salió. No es algo del manejo. Si el viaje conserva lecturas, «Volver a medir» en su detalle lo intenta otra vez.'**
  String learnWhyUnmeasured(String n);

  /// No description provided for @learnWhyExcluded.
  ///
  /// In es, this message translates to:
  /// **'{n} los marcaste como una excepción, así que no cuentan.'**
  String learnWhyExcluded(String n);

  /// No description provided for @tripNotMeasured.
  ///
  /// In es, this message translates to:
  /// **'sin medir'**
  String get tripNotMeasured;

  /// No description provided for @tripEnergyUnmeasuredWhy.
  ///
  /// In es, this message translates to:
  /// **'La conexión con la batería se cortó durante buena parte del viaje y no quedaron lecturas para saber cuánta energía salió. No cuenta para la autonomía.'**
  String get tripEnergyUnmeasuredWhy;

  /// No description provided for @tripEnergySourceLabel.
  ///
  /// In es, this message translates to:
  /// **'Cómo se midió'**
  String get tripEnergySourceLabel;

  /// No description provided for @tripEnergySourceBms.
  ///
  /// In es, this message translates to:
  /// **'contador del BMS, todo el viaje'**
  String get tripEnergySourceBms;

  /// No description provided for @tripEnergySourceIntegrated.
  ///
  /// In es, this message translates to:
  /// **'sumado de las lecturas recibidas'**
  String get tripEnergySourceIntegrated;

  /// No description provided for @tripEnergySourceBracketed.
  ///
  /// In es, this message translates to:
  /// **'contador del BMS, de las lecturas de antes y después'**
  String get tripEnergySourceBracketed;

  /// No description provided for @tripEnergySourcePartial.
  ///
  /// In es, this message translates to:
  /// **'parcial: la conexión se cortó'**
  String get tripEnergySourcePartial;

  /// No description provided for @tripEnergySourceUnmeasurable.
  ///
  /// In es, this message translates to:
  /// **'no se pudo medir'**
  String get tripEnergySourceUnmeasurable;

  /// No description provided for @tripResistanceHint.
  ///
  /// In es, this message translates to:
  /// **'La mediana de la pendiente del voltaje contra la corriente en los tramos en que la corriente cambió mucho. Aproximada: sirve para seguir el mismo pack con los meses, no para compararlo con una hoja de datos.'**
  String get tripResistanceHint;

  /// No description provided for @trendsCapacityHollow.
  ///
  /// In es, this message translates to:
  /// **'Los círculos huecos son descargas que la app no da por buenas (faltaron minutos, hubo carga en medio o se cerraron por el porcentaje) o que detectó sola al rodar. Se ven, pero no entran en la tendencia.'**
  String get trendsCapacityHollow;

  /// No description provided for @maintDeleteConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar esta anotación?'**
  String get maintDeleteConfirmTitle;

  /// No description provided for @maintDeleteConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se quita del registro de mantenimiento y de las gráficas.'**
  String get maintDeleteConfirmBody;

  /// No description provided for @maintDeleteConfirmCellBody.
  ///
  /// In es, this message translates to:
  /// **'Se quita del registro, y el historial de la batería vuelve a contar desde antes del cambio de celda: la deriva, la capacidad y las gráficas incluirán otra vez las celdas viejas.'**
  String get maintDeleteConfirmCellBody;

  /// No description provided for @orphansDiscardConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar este historial?'**
  String get orphansDiscardConfirmTitle;

  /// No description provided for @orphansDiscardConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se borran para siempre {count} filas guardadas sin batería asignada. No se puede deshacer.'**
  String orphansDiscardConfirmBody(String count);

  /// No description provided for @tripEnergySoFarOffline.
  ///
  /// In es, this message translates to:
  /// **'{wh} Wh hasta que se cortó la conexión'**
  String tripEnergySoFarOffline(String wh);

  /// No description provided for @tripReadingAgeSeconds.
  ///
  /// In es, this message translates to:
  /// **'hace {s} s'**
  String tripReadingAgeSeconds(String s);

  /// No description provided for @tripReadingAgeMinutes.
  ///
  /// In es, this message translates to:
  /// **'hace {m} min'**
  String tripReadingAgeMinutes(String m);

  /// No description provided for @backupExportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo hacer la copia: {reason}'**
  String backupExportFailed(String reason);

  /// No description provided for @exportShared.
  ///
  /// In es, this message translates to:
  /// **'Enviado.'**
  String get exportShared;

  /// No description provided for @exportRange.
  ///
  /// In es, this message translates to:
  /// **'Lecturas y frames de:'**
  String get exportRange;

  /// No description provided for @exportRangeDay.
  ///
  /// In es, this message translates to:
  /// **'1 día'**
  String get exportRangeDay;

  /// No description provided for @exportRangeWeek.
  ///
  /// In es, this message translates to:
  /// **'7 días'**
  String get exportRangeWeek;

  /// No description provided for @exportRangeMonth.
  ///
  /// In es, this message translates to:
  /// **'30 días'**
  String get exportRangeMonth;

  /// No description provided for @exportRangeAll.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get exportRangeAll;

  /// No description provided for @exportRangeNote.
  ///
  /// In es, this message translates to:
  /// **'Los frames crudos se guardan 30 días, así que «Todo» trae como mucho esos. Las lecturas de más de un mes están guardadas una por minuto.'**
  String get exportRangeNote;

  /// No description provided for @tripExportGpx.
  ///
  /// In es, this message translates to:
  /// **'Exportar recorrido (GPX)'**
  String get tripExportGpx;

  /// No description provided for @settingsGroupCell.
  ///
  /// In es, this message translates to:
  /// **'Protecciones de celda'**
  String get settingsGroupCell;

  /// No description provided for @settingsGroupCurrent.
  ///
  /// In es, this message translates to:
  /// **'Corriente'**
  String get settingsGroupCurrent;

  /// No description provided for @settingsGroupTemperature.
  ///
  /// In es, this message translates to:
  /// **'Temperatura'**
  String get settingsGroupTemperature;

  /// No description provided for @settingsGroupBalance.
  ///
  /// In es, this message translates to:
  /// **'Balanceo'**
  String get settingsGroupBalance;

  /// No description provided for @settingsGroupOther.
  ///
  /// In es, this message translates to:
  /// **'Otros'**
  String get settingsGroupOther;

  /// No description provided for @settingSmartSleep.
  ///
  /// In es, this message translates to:
  /// **'Voltaje de reposo inteligente'**
  String get settingSmartSleep;

  /// No description provided for @settingRequestCharge.
  ///
  /// In es, this message translates to:
  /// **'Voltaje de carga pedido por celda'**
  String get settingRequestCharge;

  /// No description provided for @settingRequestFloat.
  ///
  /// In es, this message translates to:
  /// **'Voltaje de flotación pedido por celda'**
  String get settingRequestFloat;

  /// No description provided for @settingChargeOcpDelay.
  ///
  /// In es, this message translates to:
  /// **'Retardo de sobrecorriente en carga'**
  String get settingChargeOcpDelay;

  /// No description provided for @settingChargeOcpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de sobrecorriente en carga'**
  String get settingChargeOcpRecovery;

  /// No description provided for @settingDischargeOcpDelay.
  ///
  /// In es, this message translates to:
  /// **'Retardo de sobrecorriente en descarga'**
  String get settingDischargeOcpDelay;

  /// No description provided for @settingDischargeOcpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de sobrecorriente en descarga'**
  String get settingDischargeOcpRecovery;

  /// No description provided for @settingScpDelay.
  ///
  /// In es, this message translates to:
  /// **'Retardo de cortocircuito'**
  String get settingScpDelay;

  /// No description provided for @settingScpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de cortocircuito'**
  String get settingScpRecovery;

  /// No description provided for @settingChargeOtpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de sobretemperatura en carga'**
  String get settingChargeOtpRecovery;

  /// No description provided for @settingDischargeOtpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de sobretemperatura en descarga'**
  String get settingDischargeOtpRecovery;

  /// No description provided for @settingChargeUtpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de subtemperatura en carga'**
  String get settingChargeUtpRecovery;

  /// No description provided for @settingMosfetOtpRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación de sobretemperatura de MOSFET'**
  String get settingMosfetOtpRecovery;

  /// No description provided for @settingWireResistances.
  ///
  /// In es, this message translates to:
  /// **'Resistencia de los cables de balanceo'**
  String get settingWireResistances;

  /// No description provided for @settingWireResistancesCount.
  ///
  /// In es, this message translates to:
  /// **'{count} celdas'**
  String settingWireResistancesCount(int count);

  /// No description provided for @settingWireResistancesHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que el BMS tiene configurado para compensar el cable de cada celda, en miliohmios. Es un ajuste, no una medición de la celda.'**
  String get settingWireResistancesHint;

  /// No description provided for @systemSetupPasscode.
  ///
  /// In es, this message translates to:
  /// **'Contraseña de ajustes que entrega el BMS'**
  String get systemSetupPasscode;

  /// No description provided for @bmsStateTitle.
  ///
  /// In es, this message translates to:
  /// **'Estado del BMS'**
  String get bmsStateTitle;

  /// No description provided for @bmsStateIntro.
  ///
  /// In es, this message translates to:
  /// **'Tal como lo informa el BMS en cada lectura.'**
  String get bmsStateIntro;

  /// No description provided for @bmsStatePrecharge.
  ///
  /// In es, this message translates to:
  /// **'Precarga'**
  String get bmsStatePrecharge;

  /// No description provided for @bmsStateChargerPlugged.
  ///
  /// In es, this message translates to:
  /// **'Ve un cargador conectado'**
  String get bmsStateChargerPlugged;

  /// No description provided for @bmsStateChargeStatus.
  ///
  /// In es, this message translates to:
  /// **'Fase de carga'**
  String get bmsStateChargeStatus;

  /// No description provided for @bmsStateBatteryType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de batería configurado'**
  String get bmsStateBatteryType;

  /// No description provided for @bmsStateBatteryTypeHint.
  ///
  /// In es, this message translates to:
  /// **'Es lo que alguien eligió al configurar el BMS, no algo que el BMS mida en las celdas.'**
  String get bmsStateBatteryTypeHint;

  /// No description provided for @bmsStateRuntime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de funcionamiento total'**
  String get bmsStateRuntime;

  /// No description provided for @bmsStateEnabledCells.
  ///
  /// In es, this message translates to:
  /// **'Celdas habilitadas'**
  String get bmsStateEnabledCells;

  /// No description provided for @bmsStateCycleCapacity.
  ///
  /// In es, this message translates to:
  /// **'Carga total que pasó por el pack'**
  String get bmsStateCycleCapacity;

  /// No description provided for @bmsStateCycleCapacityHint.
  ///
  /// In es, this message translates to:
  /// **'El contador acumulado del propio BMS. Dividido por la capacidad da los ciclos completos reales.'**
  String get bmsStateCycleCapacityHint;

  /// No description provided for @chargeStatusBulk.
  ///
  /// In es, this message translates to:
  /// **'corriente constante'**
  String get chargeStatusBulk;

  /// No description provided for @chargeStatusAbsorption.
  ///
  /// In es, this message translates to:
  /// **'absorción'**
  String get chargeStatusAbsorption;

  /// No description provided for @chargeStatusFloat.
  ///
  /// In es, this message translates to:
  /// **'flotación'**
  String get chargeStatusFloat;

  /// No description provided for @batteryTypeLfp.
  ///
  /// In es, this message translates to:
  /// **'LFP (LiFePO4)'**
  String get batteryTypeLfp;

  /// No description provided for @batteryTypeLiIon.
  ///
  /// In es, this message translates to:
  /// **'Litio-ion'**
  String get batteryTypeLiIon;

  /// No description provided for @batteryTypeLto.
  ///
  /// In es, this message translates to:
  /// **'LTO'**
  String get batteryTypeLto;

  /// No description provided for @bmsUnknownCode.
  ///
  /// In es, this message translates to:
  /// **'código {code}'**
  String bmsUnknownCode(String code);

  /// No description provided for @nowChargerByBms.
  ///
  /// In es, this message translates to:
  /// **'Según el BMS'**
  String get nowChargerByBms;

  /// No description provided for @nowChargerSeen.
  ///
  /// In es, this message translates to:
  /// **'ve el cargador conectado'**
  String get nowChargerSeen;

  /// No description provided for @nowChargerNotSeen.
  ///
  /// In es, this message translates to:
  /// **'no ve ningún cargador'**
  String get nowChargerNotSeen;

  /// No description provided for @nowChargePhase.
  ///
  /// In es, this message translates to:
  /// **'fase: {phase}'**
  String nowChargePhase(String phase);

  /// No description provided for @profileBaselineNoteAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir una nota'**
  String get profileBaselineNoteAdd;

  /// No description provided for @profileBaselineNoteEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar la nota'**
  String get profileBaselineNoteEdit;

  /// No description provided for @profileBaselineNoteTitle.
  ///
  /// In es, this message translates to:
  /// **'Nota del día uno'**
  String get profileBaselineNoteTitle;

  /// No description provided for @profileBaselineNoteHint.
  ///
  /// In es, this message translates to:
  /// **'De dónde vino, qué dijo el vendedor, lo que costó.'**
  String get profileBaselineNoteHint;

  /// No description provided for @profileBaselineRedo.
  ///
  /// In es, this message translates to:
  /// **'Rehacer el día uno'**
  String get profileBaselineRedo;

  /// No description provided for @profileBaselineRedoTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Rehacer el día uno?'**
  String get profileBaselineRedoTitle;

  /// No description provided for @profileBaselineRedoBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra el día uno guardado el {date} y se guarda uno nuevo con la lectura y la configuración del BMS de ahora. Todo lo que la app compara «desde el día uno» vuelve a empezar hoy. La nota se conserva. No se puede deshacer, y conviene hacerlo con la batería en reposo.'**
  String profileBaselineRedoBody(String date);

  /// No description provided for @profileBaselineRedoConfirm.
  ///
  /// In es, this message translates to:
  /// **'Borrar y guardar el nuevo'**
  String get profileBaselineRedoConfirm;

  /// No description provided for @profileBaselineRedone.
  ///
  /// In es, this message translates to:
  /// **'Día uno guardado de nuevo, con la lectura de ahora.'**
  String get profileBaselineRedone;

  /// No description provided for @balanceRankingNeedsHistory.
  ///
  /// In es, this message translates to:
  /// **'necesita más histórico'**
  String get balanceRankingNeedsHistory;

  /// No description provided for @balanceRankingProgress.
  ///
  /// In es, this message translates to:
  /// **'{count} de {needed} lecturas en reposo con las celdas separadas al menos 10 mV, en los últimos 30 días.'**
  String balanceRankingProgress(String count, String needed);

  /// No description provided for @balanceRankingBasis.
  ///
  /// In es, this message translates to:
  /// **'De {count} lecturas en reposo de los últimos 30 días con las celdas separadas al menos 10 mV. La más baja en reposo es la que tiene menos carga: dice dónde mirar, no que esa celda esté mal.'**
  String balanceRankingBasis(String count);

  /// No description provided for @faultHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de fallos del BMS'**
  String get faultHistoryTitle;

  /// No description provided for @faultHistoryIntro.
  ///
  /// In es, this message translates to:
  /// **'Cada vez que el BMS levantó una protección o un aviso en esta batería, la más reciente primero. Sale del registro de avisos que se guarda con cada lectura, así que es solo lo que la app vio: sin conexión no hay lecturas.'**
  String get faultHistoryIntro;

  /// No description provided for @faultHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ninguna protección ni aviso del BMS en las lecturas guardadas de esta batería.'**
  String get faultHistoryEmpty;

  /// No description provided for @faultHistoryThinned.
  ///
  /// In es, this message translates to:
  /// **'Las lecturas de más de un mes se guardan una por minuto. Ahí un fallo más corto que eso puede no aparecer, y las duraciones son aproximadas.'**
  String get faultHistoryThinned;

  /// No description provided for @faultUnknownBit.
  ///
  /// In es, this message translates to:
  /// **'Aviso sin nombre (bit {bit})'**
  String faultUnknownBit(int bit);

  /// No description provided for @faultOngoing.
  ///
  /// In es, this message translates to:
  /// **'seguía en la última lectura'**
  String get faultOngoing;

  /// No description provided for @faultInstant.
  ///
  /// In es, this message translates to:
  /// **'una lectura'**
  String get faultInstant;

  /// No description provided for @faultStarted.
  ///
  /// In es, this message translates to:
  /// **'Visto por primera vez'**
  String get faultStarted;

  /// No description provided for @faultLastSeen.
  ///
  /// In es, this message translates to:
  /// **'Visto por última vez'**
  String get faultLastSeen;

  /// No description provided for @faultNoData.
  ///
  /// In es, this message translates to:
  /// **'Sin datos: la conexión estuvo caída más de 5 minutos durante el fallo o justo antes o después, así que pudo empezar antes, acabar después o ir y venir sin que nadie lo viera.'**
  String get faultNoData;

  /// No description provided for @faultReadings.
  ///
  /// In es, this message translates to:
  /// **'Lecturas con el aviso'**
  String get faultReadings;

  /// No description provided for @faultAtStart.
  ///
  /// In es, this message translates to:
  /// **'Al empezar'**
  String get faultAtStart;

  /// No description provided for @faultAtStartCells.
  ///
  /// In es, this message translates to:
  /// **'Celda más alta {max} V, más baja {min} V.'**
  String faultAtStartCells(String max, String min);

  /// No description provided for @offlineMoreHistory.
  ///
  /// In es, this message translates to:
  /// **'Más historial'**
  String get offlineMoreHistory;

  /// No description provided for @cellHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Celdas en el tiempo'**
  String get cellHistoryTitle;

  /// No description provided for @cellHistoryOpen.
  ///
  /// In es, this message translates to:
  /// **'Ver historial'**
  String get cellHistoryOpen;

  /// No description provided for @cellHistoryTripButton.
  ///
  /// In es, this message translates to:
  /// **'Celdas durante el viaje'**
  String get cellHistoryTripButton;

  /// No description provided for @cellHistoryRangeHour.
  ///
  /// In es, this message translates to:
  /// **'Última hora'**
  String get cellHistoryRangeHour;

  /// No description provided for @cellHistoryRangeDay.
  ///
  /// In es, this message translates to:
  /// **'Últimas 24 h'**
  String get cellHistoryRangeDay;

  /// No description provided for @cellHistoryRangeWeek.
  ///
  /// In es, this message translates to:
  /// **'Últimos 7 días'**
  String get cellHistoryRangeWeek;

  /// No description provided for @cellHistoryRangeTrip.
  ///
  /// In es, this message translates to:
  /// **'Este viaje'**
  String get cellHistoryRangeTrip;

  /// No description provided for @cellHistoryRangeCharge.
  ///
  /// In es, this message translates to:
  /// **'Última carga'**
  String get cellHistoryRangeCharge;

  /// No description provided for @cellHistoryAnchor.
  ///
  /// In es, this message translates to:
  /// **'Hasta la última lectura guardada, {date}.'**
  String cellHistoryAnchor(String date);

  /// No description provided for @cellHistoryModeVolts.
  ///
  /// In es, this message translates to:
  /// **'Voltaje'**
  String get cellHistoryModeVolts;

  /// No description provided for @cellHistoryModeDeviation.
  ///
  /// In es, this message translates to:
  /// **'Frente al promedio'**
  String get cellHistoryModeDeviation;

  /// No description provided for @cellHistoryAxisVolts.
  ///
  /// In es, this message translates to:
  /// **'V por celda'**
  String get cellHistoryAxisVolts;

  /// No description provided for @cellHistoryAxisDeviation.
  ///
  /// In es, this message translates to:
  /// **'mV por encima o por debajo del promedio del pack en esa lectura'**
  String get cellHistoryAxisDeviation;

  /// No description provided for @cellHistoryLowest.
  ///
  /// In es, this message translates to:
  /// **'Celda {cell}: la más baja de media en este intervalo'**
  String cellHistoryLowest(int cell);

  /// No description provided for @cellHistoryHighest.
  ///
  /// In es, this message translates to:
  /// **'Celda {cell}: la más alta de media en este intervalo'**
  String cellHistoryHighest(int cell);

  /// No description provided for @cellHistoryPicked.
  ///
  /// In es, this message translates to:
  /// **'Celda {cell}: la que elegiste'**
  String cellHistoryPicked(int cell);

  /// No description provided for @cellHistoryOthers.
  ///
  /// In es, this message translates to:
  /// **'Las demás'**
  String get cellHistoryOthers;

  /// No description provided for @cellHistoryPickCell.
  ///
  /// In es, this message translates to:
  /// **'Resaltar una celda'**
  String get cellHistoryPickCell;

  /// No description provided for @cellHistoryPoints.
  ///
  /// In es, this message translates to:
  /// **'{count} lecturas'**
  String cellHistoryPoints(int count);

  /// No description provided for @cellHistoryNote.
  ///
  /// In es, this message translates to:
  /// **'Cada punto es una lectura real, una por cada {bucket}: un pico entre dos de ellas no se dibuja. Donde las líneas se cortan no hubo lecturas durante más de 30 segundos, y no se rellena.'**
  String cellHistoryNote(String bucket);

  /// No description provided for @cellHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay lecturas guardadas en este intervalo.'**
  String get cellHistoryEmpty;

  /// No description provided for @linkEventRidingCurrentSeen.
  ///
  /// In es, this message translates to:
  /// **'Corriente de marcha vista'**
  String get linkEventRidingCurrentSeen;

  /// No description provided for @linkEventIdleSpeedSeen.
  ///
  /// In es, this message translates to:
  /// **'Velocidad vista sin viaje abierto'**
  String get linkEventIdleSpeedSeen;

  /// No description provided for @linkEventLocationArmed.
  ///
  /// In es, this message translates to:
  /// **'GPS encendido'**
  String get linkEventLocationArmed;

  /// No description provided for @linkEventLocationStoodDown.
  ///
  /// In es, this message translates to:
  /// **'GPS apagado'**
  String get linkEventLocationStoodDown;

  /// No description provided for @linkEventLocationRefused.
  ///
  /// In es, this message translates to:
  /// **'El GPS no arrancó'**
  String get linkEventLocationRefused;

  /// No description provided for @linkEventTripWithoutFixes.
  ///
  /// In es, this message translates to:
  /// **'Viaje sin posición GPS'**
  String get linkEventTripWithoutFixes;

  /// No description provided for @linkEventLocationStreamError.
  ///
  /// In es, this message translates to:
  /// **'Error del GPS'**
  String get linkEventLocationStreamError;

  /// No description provided for @linkEventForegroundServiceRefused.
  ///
  /// In es, this message translates to:
  /// **'Android no dejó arrancar el servicio'**
  String get linkEventForegroundServiceRefused;

  /// No description provided for @linkEventForegroundServiceLost.
  ///
  /// In es, this message translates to:
  /// **'Android paró el servicio'**
  String get linkEventForegroundServiceLost;

  /// No description provided for @linkEventAutoTripStarted.
  ///
  /// In es, this message translates to:
  /// **'Viaje abierto solo'**
  String get linkEventAutoTripStarted;

  /// No description provided for @linkEventAutoTripStopped.
  ///
  /// In es, this message translates to:
  /// **'Viaje cerrado solo'**
  String get linkEventAutoTripStopped;

  /// No description provided for @linkEventAutoTripBlocked.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el viaje'**
  String get linkEventAutoTripBlocked;

  /// No description provided for @linkEventReadingsResumed.
  ///
  /// In es, this message translates to:
  /// **'Vuelven las lecturas'**
  String get linkEventReadingsResumed;

  /// No description provided for @linkEventLinkDropped.
  ///
  /// In es, this message translates to:
  /// **'Conexión perdida'**
  String get linkEventLinkDropped;

  /// No description provided for @linkEventMuteLinkReleased.
  ///
  /// In es, this message translates to:
  /// **'Conexión muda soltada'**
  String get linkEventMuteLinkReleased;

  /// No description provided for @linkEventReconnectAttempted.
  ///
  /// In es, this message translates to:
  /// **'Intento de reconexión'**
  String get linkEventReconnectAttempted;

  /// No description provided for @linkEventReconnectFailed.
  ///
  /// In es, this message translates to:
  /// **'Reconexión fallida'**
  String get linkEventReconnectFailed;

  /// No description provided for @linkEventReconnectGaveUp.
  ///
  /// In es, this message translates to:
  /// **'Dejó de intentar reconectar'**
  String get linkEventReconnectGaveUp;

  /// No description provided for @linkEventReconnectPersisting.
  ///
  /// In es, this message translates to:
  /// **'Reconexión sin rendirse (viaje en curso)'**
  String get linkEventReconnectPersisting;

  /// No description provided for @linkEventReconnectRelaxed.
  ///
  /// In es, this message translates to:
  /// **'Reconexión normal otra vez'**
  String get linkEventReconnectRelaxed;

  /// No description provided for @linkEventConnectAttempt.
  ///
  /// In es, this message translates to:
  /// **'Intento de conexión'**
  String get linkEventConnectAttempt;

  /// No description provided for @linkEventBluetoothLooksStuck.
  ///
  /// In es, this message translates to:
  /// **'El Bluetooth del teléfono parece atascado'**
  String get linkEventBluetoothLooksStuck;

  /// No description provided for @linkEventBluetoothRemedy.
  ///
  /// In es, this message translates to:
  /// **'Remedio de Bluetooth'**
  String get linkEventBluetoothRemedy;

  /// No description provided for @linkEventBluetoothRecovered.
  ///
  /// In es, this message translates to:
  /// **'Conectó tras el atasco'**
  String get linkEventBluetoothRecovered;

  /// No description provided for @linkEventProtocolSwitched.
  ///
  /// In es, this message translates to:
  /// **'Cambio de protocolo'**
  String get linkEventProtocolSwitched;

  /// No description provided for @linkEventAntFrameRejected.
  ///
  /// In es, this message translates to:
  /// **'Frame ANT descartado'**
  String get linkEventAntFrameRejected;

  /// No description provided for @linkEventAntDecodeFailed.
  ///
  /// In es, this message translates to:
  /// **'Frame ANT sin descifrar'**
  String get linkEventAntDecodeFailed;

  /// No description provided for @linkEventOldAntProtocolSeen.
  ///
  /// In es, this message translates to:
  /// **'Protocolo ANT antiguo'**
  String get linkEventOldAntProtocolSeen;

  /// No description provided for @linkEventJkFrameRejected.
  ///
  /// In es, this message translates to:
  /// **'Bytes JK descartados'**
  String get linkEventJkFrameRejected;

  /// No description provided for @linkEventJkFrameUndecoded.
  ///
  /// In es, this message translates to:
  /// **'Frame JK sin descifrar'**
  String get linkEventJkFrameUndecoded;

  /// No description provided for @linkEventAntCurrentSignInverted.
  ///
  /// In es, this message translates to:
  /// **'Signo de corriente ANT invertido'**
  String get linkEventAntCurrentSignInverted;

  /// No description provided for @linkEventsTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de conexión'**
  String get linkEventsTitle;

  /// No description provided for @linkEventsIntro.
  ///
  /// In es, this message translates to:
  /// **'Lo que la app decidió y cuándo: cada intento de conexión, cada caída, cada viaje que se abrió o no. Se guarda 14 días.'**
  String get linkEventsIntro;

  /// No description provided for @linkEventsThisPack.
  ///
  /// In es, this message translates to:
  /// **'Esta batería'**
  String get linkEventsThisPack;

  /// No description provided for @linkEventsAllPacks.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get linkEventsAllPacks;

  /// No description provided for @linkEventsThisPackHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que pasa mientras se conecta casi nunca tiene batería asignada todavía: está en «Todas».'**
  String get linkEventsThisPackHint;

  /// No description provided for @linkEventsAnyKind.
  ///
  /// In es, this message translates to:
  /// **'Todos los tipos'**
  String get linkEventsAnyKind;

  /// No description provided for @linkEventsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Nada registrado con estos filtros.'**
  String get linkEventsEmpty;

  /// No description provided for @linkEventsNoPack.
  ///
  /// In es, this message translates to:
  /// **'sin batería'**
  String get linkEventsNoPack;

  /// No description provided for @linkEventsBytes.
  ///
  /// In es, this message translates to:
  /// **'{count} bytes'**
  String linkEventsBytes(int count);

  /// No description provided for @linkEventsCopyBytes.
  ///
  /// In es, this message translates to:
  /// **'Copiar los bytes'**
  String get linkEventsCopyBytes;

  /// No description provided for @linkEventsBytesCopied.
  ///
  /// In es, this message translates to:
  /// **'Bytes copiados'**
  String get linkEventsBytesCopied;

  /// No description provided for @linkEventsCopyAll.
  ///
  /// In es, this message translates to:
  /// **'Copiar todo lo mostrado'**
  String get linkEventsCopyAll;

  /// No description provided for @linkEventsCopiedAll.
  ///
  /// In es, this message translates to:
  /// **'Copiado: {count} filas'**
  String linkEventsCopiedAll(int count);

  /// No description provided for @linkEventsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} filas'**
  String linkEventsCount(int count);

  /// No description provided for @linkEventsUnknownKind.
  ///
  /// In es, this message translates to:
  /// **'Tipo desconocido: {name}'**
  String linkEventsUnknownKind(String name);

  /// No description provided for @workshopTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos del taller en los informes'**
  String get workshopTitle;

  /// No description provided for @workshopIntro.
  ///
  /// In es, this message translates to:
  /// **'Se imprimen arriba en los PDF: el de la batería y el de inspección. Las cifras siguen siendo las que mide la app, y el informe lo sigue diciendo.'**
  String get workshopIntro;

  /// No description provided for @workshopName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del taller'**
  String get workshopName;

  /// No description provided for @workshopLine.
  ///
  /// In es, this message translates to:
  /// **'Línea de contacto'**
  String get workshopLine;

  /// No description provided for @workshopLineHint.
  ///
  /// In es, this message translates to:
  /// **'Teléfono, dirección o web'**
  String get workshopLineHint;

  /// No description provided for @workshopLogo.
  ///
  /// In es, this message translates to:
  /// **'Logo'**
  String get workshopLogo;

  /// No description provided for @workshopLogoPick.
  ///
  /// In es, this message translates to:
  /// **'Elegir logo'**
  String get workshopLogoPick;

  /// No description provided for @workshopLogoChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get workshopLogoChange;

  /// No description provided for @workshopLogoRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get workshopLogoRemove;

  /// No description provided for @workshopLogoRefused.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo no sirve: tiene que ser PNG o JPEG, de menos de 1 MB.'**
  String get workshopLogoRefused;

  /// No description provided for @workshopSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardado. Sale en el próximo informe.'**
  String get workshopSaved;

  /// No description provided for @workshopSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar.'**
  String get workshopSaveFailed;

  /// No description provided for @linkEventBmsWriteRefused.
  ///
  /// In es, this message translates to:
  /// **'Cambio en el BMS rechazado por la app'**
  String get linkEventBmsWriteRefused;

  /// No description provided for @linkEventBmsWriteNotSent.
  ///
  /// In es, this message translates to:
  /// **'Cambio en el BMS sin enviar'**
  String get linkEventBmsWriteNotSent;

  /// No description provided for @linkEventBmsWriteSent.
  ///
  /// In es, this message translates to:
  /// **'Cambio enviado al BMS'**
  String get linkEventBmsWriteSent;

  /// No description provided for @linkEventBmsWriteConfirmed.
  ///
  /// In es, this message translates to:
  /// **'El BMS confirmó el cambio'**
  String get linkEventBmsWriteConfirmed;

  /// No description provided for @linkEventBmsWriteUnconfirmed.
  ///
  /// In es, this message translates to:
  /// **'El BMS no confirmó el cambio'**
  String get linkEventBmsWriteUnconfirmed;

  /// No description provided for @settingsSectionBmsWrites.
  ///
  /// In es, this message translates to:
  /// **'Cambios en el BMS'**
  String get settingsSectionBmsWrites;

  /// No description provided for @bmsWritesTitle.
  ///
  /// In es, this message translates to:
  /// **'Permitir que la app cambie el BMS'**
  String get bmsWritesTitle;

  /// No description provided for @bmsWritesHint.
  ///
  /// In es, this message translates to:
  /// **'Apagado, la app no cambia nada en el BMS. Encendido, puede encender y apagar la carga, la descarga y el balanceador desde Sistema, en Configuración del BMS, y cada vez te pide confirmación. Solo en un JK. Ningún valor de configuración (voltajes, corrientes, temperaturas) se escribe nunca.'**
  String get bmsWritesHint;

  /// No description provided for @bmsWritesConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Permitir cambios en el BMS?'**
  String get bmsWritesConfirmTitle;

  /// No description provided for @bmsWritesConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Con esto encendido, la app puede apagar la carga, la descarga y el balanceador del BMS. Apagar la descarga corta la corriente: la moto se queda sin potencia y sin luces. Cada cambio te pide confirmación, la app no apaga la descarga con la moto en marcha, y solo da un cambio por hecho cuando el BMS lo confirma. El protocolo está sacado a base de ingeniería inversa: úsalo bajo tu responsabilidad.'**
  String get bmsWritesConfirmBody;

  /// No description provided for @bmsWritesConfirmAction.
  ///
  /// In es, this message translates to:
  /// **'Permitir'**
  String get bmsWritesConfirmAction;

  /// No description provided for @bmsSwitchesLocked.
  ///
  /// In es, this message translates to:
  /// **'Solo lectura. Para cambiarlos, activa «Permitir que la app cambie el BMS» en Ajustes.'**
  String get bmsSwitchesLocked;

  /// No description provided for @bmsSwitchesHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que se ve es lo último que dijo el BMS. Cada cambio pide confirmación y se da por hecho solo cuando el BMS lo confirma.'**
  String get bmsSwitchesHint;

  /// No description provided for @bmsSwitchSending.
  ///
  /// In es, this message translates to:
  /// **'Enviado. Esperando a que el BMS lo confirme.'**
  String get bmsSwitchSending;

  /// No description provided for @bmsSwitchConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'{action, select, chargeOff{¿Apagar la carga?} chargeOn{¿Encender la carga?} dischargeOff{¿Apagar la descarga?} dischargeOn{¿Encender la descarga?} balancerOff{¿Apagar el balanceador?} balancerOn{¿Encender el balanceador?} other{¿Cambiar el interruptor?}}'**
  String bmsSwitchConfirmTitle(String action);

  /// No description provided for @bmsSwitchConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'{action, select, chargeOff{El BMS deja de aceptar carga: con el cargador enchufado, la batería no carga hasta que lo vuelvas a encender. Con la batería baja, no lo dejes así.} chargeOn{El BMS vuelve a aceptar carga. Sus propias protecciones siguen cortando como siempre.} dischargeOff{La batería deja de dar corriente: la moto se queda sin potencia, sin luces y sin controlador hasta que lo vuelvas a encender, desde aquí o desde la app oficial. Hazlo solo con la moto parada y en un sitio seguro.} dischargeOn{La batería vuelve a dar corriente. Comprueba antes que el acelerador está en reposo.} balancerOff{El balanceador deja de igualar las celdas. Con el tiempo se separan, el pack pierde capacidad útil y una celda llega antes al corte. Vuelve a encenderlo cuando termines.} balancerOn{El balanceador vuelve a igualar las celdas según su voltaje de arranque.} other{El BMS cambia este interruptor.}}'**
  String bmsSwitchConfirmBody(String action);

  /// No description provided for @bmsSwitchConfirmAction.
  ///
  /// In es, this message translates to:
  /// **'Enviar al BMS'**
  String get bmsSwitchConfirmAction;

  /// No description provided for @bmsSwitchApplied.
  ///
  /// In es, this message translates to:
  /// **'Aplicado: el BMS lo confirma.'**
  String get bmsSwitchApplied;

  /// No description provided for @bmsSwitchUnconfirmed.
  ///
  /// In es, this message translates to:
  /// **'El BMS no confirmó el cambio. Lo que ves es lo último que dijo; queda anotado en el historial de conexión.'**
  String get bmsSwitchUnconfirmed;

  /// No description provided for @bmsSwitchNotSent.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar: el Bluetooth no aceptó la escritura. No cambió nada.'**
  String get bmsSwitchNotSent;

  /// No description provided for @bmsSwitchRefused.
  ///
  /// In es, this message translates to:
  /// **'{reason, select, notPermitted{La app no tiene permiso para cambiar el BMS. Se activa en Ajustes.} notJk{Solo se puede en un JK. En un ANT la app no escribe nada.} notConnected{No hay conexión con el BMS.} variantUnsupported{Este BMS habla un formato (JK04 o desconocido) en el que la app no escribe. No se envió nada.} noSettings{El BMS todavía no mandó su configuración, así que no se sabe cómo está ahora.} noRecentReading{No hay lecturas recientes: sin ellas la app no puede saber si la moto anda ni esperar la respuesta del BMS.} readingImplausible{Las lecturas no cuadran con el formato en uso. Mientras no cuadren, la app no escribe nada.} alreadySet{El BMS ya lo tiene así.} riding{Para la moto primero: con la moto en marcha o un viaje grabándose, la app no apaga la descarga.} busy{Hay otro cambio esperando la respuesta del BMS.} other{No se envió nada.}}'**
  String bmsSwitchRefused(String reason);

  /// No description provided for @systemWritesOnNote.
  ///
  /// In es, this message translates to:
  /// **'El permiso de escritura está encendido: la app solo puede encender y apagar los tres interruptores de arriba, cada vez con tu confirmación. Ningún otro valor se escribe nunca.'**
  String get systemWritesOnNote;

  /// No description provided for @tripMapTitle.
  ///
  /// In es, this message translates to:
  /// **'Recorrido'**
  String get tripMapTitle;

  /// No description provided for @tripMapStart.
  ///
  /// In es, this message translates to:
  /// **'Salida'**
  String get tripMapStart;

  /// No description provided for @tripMapEnd.
  ///
  /// In es, this message translates to:
  /// **'Llegada'**
  String get tripMapEnd;

  /// No description provided for @tripMapBySpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get tripMapBySpeed;

  /// No description provided for @tripMapByPower.
  ///
  /// In es, this message translates to:
  /// **'Potencia'**
  String get tripMapByPower;

  /// No description provided for @tripMapPowerHint.
  ///
  /// In es, this message translates to:
  /// **'Lo que daba la batería en cada punto: su voltaje por su corriente, tal como los mandó el BMS junto a cada posición. No es consumo por kilómetro, que en cada parada se dispara aunque no se gaste nada.'**
  String get tripMapPowerHint;

  /// No description provided for @tripMapOffline.
  ///
  /// In es, this message translates to:
  /// **'El mapa de fondo se pide a OpenStreetMap por internet al abrir esta pantalla, así que sus servidores ven por qué zona fue el viaje (no el viaje en sí). Sin conexión, el recorrido se dibuja igual sobre fondo liso.'**
  String get tripMapOffline;
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
