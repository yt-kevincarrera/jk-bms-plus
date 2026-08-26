// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'JK BMS +';

  @override
  String get connectTitle => 'Connect';

  @override
  String get connectOneConnectionWarning =>
      'The JK BMS accepts one Bluetooth connection at a time. Close the official JK app before connecting here.';

  @override
  String get connectScan => 'Scan for a BMS';

  @override
  String get connectScanning => 'Scanning';

  @override
  String get connectCancelScan => 'Cancel scan';

  @override
  String get connectScanCancelled => 'Scan cancelled';

  @override
  String get connectNoDevices => 'No BMS found yet';

  @override
  String get connectNoBle => 'This phone has no Bluetooth LE.';

  @override
  String get connectBluetoothOff =>
      'Bluetooth is off. Turn it on and scan again.';

  @override
  String get connectDemoButton => 'Open demo mode';

  @override
  String get connectDemoHint =>
      'Demo mode runs a simulated 20S pack through the real parser, so you can see every screen with no BMS in the room.';

  @override
  String get tabNow => 'Now';

  @override
  String get tabCells => 'Cells';

  @override
  String get tabThermal => 'Thermal';

  @override
  String get tabHistory => 'Trips';

  @override
  String get tabSystem => 'System';

  @override
  String get demoBanner => 'DEMO — simulated pack, no BMS connected';

  @override
  String get demoTitle => 'Demo mode';

  @override
  String get demoExplanation =>
      'A simulated 20S pack is generating real 300-byte frames. They go through the same checksum, reassembly and parser the hardware will, so these screens are wired exactly as they will be in the field. The values themselves are modelled, not measured.';

  @override
  String get demoScenarioRiding => 'Riding';

  @override
  String get demoScenarioRidingDesc =>
      'Throttle swings, sag under load, charge draining';

  @override
  String get demoScenarioCharging => 'Charging';

  @override
  String get demoScenarioChargingDesc =>
      'Steady charge, delta opening up near the top';

  @override
  String get demoScenarioIdle => 'Parked';

  @override
  String get demoScenarioIdleDesc => 'No current, cells relaxed';

  @override
  String get demoScenarioWeakCell => 'Weak cell';

  @override
  String get demoScenarioWeakCellDesc =>
      'Cell 7 sagging hard, balancer working, warnings raised';

  @override
  String get demoPackName => 'Demo pack';

  @override
  String get healthGood => 'All good';

  @override
  String get healthWatch => 'Watch';

  @override
  String get healthBad => 'Problem';

  @override
  String waitingFor(String what) {
    return 'Waiting for $what';
  }

  @override
  String get waitingFirstReading => 'the first reading';

  @override
  String get waitingCellVoltages => 'cell voltages';

  @override
  String get waitingTemperatures => 'temperatures';

  @override
  String get soc => 'Charge';

  @override
  String get range => 'Range';

  @override
  String get rangeDisclaimer =>
      'Rough estimate from remaining energy. The real number comes from Wh/km measured against GPS.';

  @override
  String get power => 'Power';

  @override
  String get current => 'Current';

  @override
  String get packVoltage => 'Pack';

  @override
  String get cellDelta => 'Delta';

  @override
  String get average => 'Average';

  @override
  String get charging => 'charging';

  @override
  String get discharging => 'discharging';

  @override
  String get resting => 'at rest';

  @override
  String get sessionTitle => 'This session';

  @override
  String get sessionEnergy => 'Energy through pack';

  @override
  String get sessionDistance => 'Distance';

  @override
  String get sessionWhPerKm => 'Wh per km';

  @override
  String get sessionSamples => 'Samples buffered';

  @override
  String get needsGps => 'needs an active trip';

  @override
  String get needsDatabase => 'needs more history';

  @override
  String get needsSteps => 'needs current steps';

  @override
  String get packTitle => 'Pack';

  @override
  String get packRemaining => 'Remaining';

  @override
  String packRemainingValue(String remaining, String nominal) {
    return '$remaining of $nominal Ah';
  }

  @override
  String get packCycles => 'Cycles';

  @override
  String get packSoh => 'Health';

  @override
  String get packSag => 'Sag under load';

  @override
  String get packSagNoBaseline => 'no resting reading yet';

  @override
  String get packMosfets => 'MOSFETs';

  @override
  String get mosfetChargeOn => 'charge on';

  @override
  String get mosfetChargeOff => 'charge off';

  @override
  String get mosfetDischargeOn => 'discharge on';

  @override
  String get mosfetDischargeOff => 'discharge off';

  @override
  String cellsLowest(int index, String voltage) {
    return 'Lowest: cell $index at $voltage V';
  }

  @override
  String cellsHighest(int index, String voltage) {
    return 'Highest: cell $index at $voltage V';
  }

  @override
  String get cellsSpreadTitle => 'Spread';

  @override
  String get cellsDeviationHint =>
      'The bars show deviation from the average, not absolute voltage: at 3.9 V nominal, twenty identical full bars would tell you nothing.';

  @override
  String get balancingTitle => 'Balancing';

  @override
  String get balancerState => 'Balancer';

  @override
  String get balancerBadge => 'Balancing';

  @override
  String get balancerWorking => 'working';

  @override
  String get balancerIdle => 'idle';

  @override
  String get balanceCurrent => 'Balance current';

  @override
  String get balanceDirection => 'Direction';

  @override
  String get balanceDirectionCharge => 'moving charge into the low cells';

  @override
  String get balanceDirectionDischarge => 'draining the high cells';

  @override
  String get balanceDirectionOff => 'nothing happening';

  @override
  String get balanceActiveNote =>
      'This BMS is an active balancer: it moves charge between cells rather than burning it off in resistors, so it can work at far higher currents than a passive one.';

  @override
  String get balanceWhichCells => 'Which cells';

  @override
  String get balanceWhichCellsValue => 'inferred, the BMS does not report it';

  @override
  String get balanceRanking => 'Weak-cell ranking';

  @override
  String get resistanceTitle => 'Resistance';

  @override
  String get resistanceSource => 'Source';

  @override
  String get resistanceSourceValue => 'the BMS\'s own wire measurement';

  @override
  String get resistanceEstimated => 'Estimated internal resistance';

  @override
  String get resistanceWireWarnings => 'Wire resistance warnings';

  @override
  String get none => 'none';

  @override
  String thermalProbe(int index) {
    return 'Probe $index';
  }

  @override
  String get thermalMosfet => 'MOSFET';

  @override
  String thermalLastMinutes(int minutes) {
    return 'Last $minutes minutes';
  }

  @override
  String thermalSamples(int count) {
    return '$count samples';
  }

  @override
  String get thermalCollecting => 'Collecting samples';

  @override
  String get thermalLegendHottest => 'Hottest probe';

  @override
  String get thermalLegendCurrent => 'Current (|A|)';

  @override
  String get thermalSensorsTitle => 'Sensors';

  @override
  String get thermalProbesReported => 'Probes reported';

  @override
  String get thermalMosfetSensor => 'MOSFET sensor';

  @override
  String get reported => 'reported';

  @override
  String get notReported => 'not reported';

  @override
  String get thermalSensorMask => 'Sensor bitmask';

  @override
  String get thermalHeater => 'Heater';

  @override
  String get thermalHeaterCurrent => 'Heater current';

  @override
  String get on => 'on';

  @override
  String get off => 'off';

  @override
  String get thermalMaskNote =>
      'The bitmask is shown raw and no reading is hidden because of it. The reference implementation calls it an \"absent\" sensor mask, but real captures set bits for probes that are plainly working. See docs/PROTOCOL.md.';

  @override
  String get historyEmptyTitle => 'Nothing recorded yet';

  @override
  String get historyEmptyBody =>
      'Trips you record are stored with their track, and the degradation curves draw themselves over the weeks.';

  @override
  String get historyWhatGoesHere => 'WHAT WILL LIVE HERE';

  @override
  String get historyItemCapacity =>
      'Measured capacity per cycle, and the degradation curve it draws over months';

  @override
  String get historyItemTrips => 'Trip list with distance, Wh and Wh/km';

  @override
  String get historyItemDelta =>
      'Delta plotted against pack voltage, which is where a short cell gives itself away';

  @override
  String get historyItemSag =>
      'Sag at a given current, and how it worsens over time';

  @override
  String get historyItemBalance => 'Which cells the balancer works hardest on';

  @override
  String get systemDeviceTitle => 'Device';

  @override
  String get systemModel => 'Model';

  @override
  String get systemHardware => 'Hardware';

  @override
  String get systemSoftware => 'Firmware';

  @override
  String get systemSerial => 'Serial number';

  @override
  String get systemManufactured => 'Manufactured';

  @override
  String get systemPowerOnCount => 'Power-on count';

  @override
  String get systemUptime => 'Uptime';

  @override
  String get systemDeviceInfoMissing => 'not received yet';

  @override
  String get systemVariantTitle => 'Protocol variant';

  @override
  String get systemVariantInUse => 'In use';

  @override
  String get systemVariantUndecided => 'not decided';

  @override
  String get systemVariantAuto => 'Automatic';

  @override
  String get systemVariantWarning =>
      'Override this if the decoded values look wrong. Picking the wrong variant does not fail loudly: it decodes at the wrong offsets and produces plausible nonsense.';

  @override
  String get systemConnectionTitle => 'Connection';

  @override
  String get systemMtu => 'MTU';

  @override
  String systemMtuValue(int bytes) {
    return '$bytes bytes';
  }

  @override
  String get unknown => 'unknown';

  @override
  String get systemFramesOk => 'Frames accepted';

  @override
  String get systemFramesBadChecksum => 'Bad checksum';

  @override
  String get systemFramesUnsupported => 'Unsupported type';

  @override
  String get systemAcceptRate => 'Accept rate';

  @override
  String get systemBytesReceived => 'Bytes received';

  @override
  String get systemSettingsTitle => 'BMS settings (read-only)';

  @override
  String get systemNotices => 'Notices';

  @override
  String get systemRawConsole => 'Raw frame console';

  @override
  String get systemReadOnlyNote =>
      'This app never writes settings to the BMS. Everything above is read-only.';

  @override
  String get systemLanguageTitle => 'Language';

  @override
  String get systemLanguageSpanish => 'Español';

  @override
  String get systemLanguageEnglish => 'English';

  @override
  String get systemLanguageSystem => 'System default';

  @override
  String get settingCellCount => 'Cell count';

  @override
  String get settingNominalCapacity => 'Nominal capacity';

  @override
  String get settingCellOvp => 'Cell overvoltage';

  @override
  String get settingCellOvpRecovery => 'Overvoltage recovery';

  @override
  String get settingCellUvp => 'Cell undervoltage';

  @override
  String get settingCellUvpRecovery => 'Undervoltage recovery';

  @override
  String get settingPowerOff => 'Power off voltage';

  @override
  String get settingMaxCharge => 'Max charge current';

  @override
  String get settingMaxDischarge => 'Max discharge current';

  @override
  String get settingMaxBalance => 'Max balance current';

  @override
  String get settingBalanceStart => 'Balance start voltage';

  @override
  String get settingBalanceTrigger => 'Balance trigger delta';

  @override
  String get settingChargeOtp => 'Charge overtemperature';

  @override
  String get settingDischargeOtp => 'Discharge overtemperature';

  @override
  String get settingChargeUtp => 'Charge undertemperature';

  @override
  String get settingMosfetOtp => 'MOSFET overtemperature';

  @override
  String get settingSwitches => 'Switches';

  @override
  String get consoleTitle => 'Raw frames';

  @override
  String get consoleFollow => 'Following';

  @override
  String get consolePaused => 'Paused';

  @override
  String get consoleCopy => 'Copy log';

  @override
  String get consoleCopied => 'Log copied';

  @override
  String get tabHealth => 'Health';

  @override
  String get healthTitle => 'What the manufacturer would rather not show you';

  @override
  String get healthIntro =>
      'These come from what the BMS already reports, cross-checked against itself. None of them is a figure the manufacturer publishes.';

  @override
  String get healthRealCapacity => 'Implied real capacity';

  @override
  String get healthRealCapacityHint =>
      'Remaining divided by reported charge. If it sits well under the configured nominal, the pack has lost capacity or the coulomb counter has drifted.';

  @override
  String get healthClaimedCapacity => 'Nominal configured in the BMS';

  @override
  String get healthSpecCapacity => 'Catalogue capacity';

  @override
  String get healthCapacityLoss => 'Loss against catalogue';

  @override
  String get healthEquivalentCycles => 'Full-equivalent cycles';

  @override
  String get healthEquivalentCyclesHint =>
      'Total Ah put through the pack divided by its nominal capacity. The BMS cycle counter adds up partial charges, so it almost always flatters the pack.';

  @override
  String get healthReportedCycles => 'Cycles the BMS reports';

  @override
  String get healthCycleInflation => 'Counter inflation';

  @override
  String get healthImbalanceLoss => 'Capacity lost to imbalance';

  @override
  String get healthImbalanceHint =>
      'The pack cuts off when the lowest cell hits its limit, not when the average does. Today\'s delta translates into the Ah left stranded in every other cell.';

  @override
  String get healthWeakestCell => 'The cell in charge';

  @override
  String healthWeakestCellValue(int index) {
    return 'cell $index';
  }

  @override
  String get healthWeakestCellHint =>
      'A pack is worth what its worst cell is worth. That cell reaches cutoff first and sets your real range.';

  @override
  String get healthResistanceSpread => 'Resistance spread';

  @override
  String healthResistanceSpreadValue(String percent) {
    return 'the worst sits $percent% above the median';
  }

  @override
  String get healthSohReported => 'Health the BMS reports';

  @override
  String get healthSohSuspect =>
      'Plenty of firmwares leave this number fixed and never recompute it. Treat it as decorative until you see it move.';

  @override
  String get healthNeedsHistoryTitle => 'Needs history';

  @override
  String get healthNeedsHistoryBody =>
      'Measured degradation, estimated remaining life and how sag evolves all need months of stored readings. They fill in on their own as you ride.';

  @override
  String get healthNotEnoughData => 'not enough data';

  @override
  String get healthCapacityUnavailable =>
      'At very low or very high charge this calculation turns into noise, so it is not shown.';

  @override
  String get rangeLearning => 'learning';

  @override
  String get rangeEstimatorTitle => 'Adaptive range';

  @override
  String get rangeEstimatorIntro =>
      'The app measures the Wh actually leaving the pack and divides them by the kilometres from the phone\'s GPS. Every ride corrects the estimate, so the number settles onto how you ride, on your terrain, with your load.';

  @override
  String get rangeConsumption => 'Learned consumption';

  @override
  String get rangeConsumptionDefault => 'starting default';

  @override
  String get rangeSamples => 'Kilometres learned from';

  @override
  String get rangeConfidence => 'Confidence';

  @override
  String get rangeConfidenceLow => 'low';

  @override
  String get rangeConfidenceMedium => 'medium';

  @override
  String get rangeConfidenceHigh => 'high';

  @override
  String rangeBand(String low, String high) {
    return 'between $low and $high km';
  }

  @override
  String get rangeUsableEnergy => 'Usable energy';

  @override
  String get rangeUsableHint =>
      'Discounts what the lowest cell strands: the pack cuts off when that cell hits its limit, not when the average does.';

  @override
  String get rangeNeedsGps =>
      'Distance comes from the phone\'s GPS while a trip is recording. The BMS does not report position: the protocol has GPS lock bits, but no coordinate fields at all.';

  @override
  String get rangeDemoNote =>
      'In demo mode the distance is simulated too, so you can watch how the estimator behaves.';

  @override
  String get systemPasscode => 'Passcode the BMS hands out';

  @override
  String get systemPasscodeHint =>
      'The BMS includes its own passcode, in clear text, inside the device info frame. Any Bluetooth client that connects can read it: there is no authentication anywhere in this protocol. This app only reads, but it is worth knowing.';

  @override
  String get systemPasscodeEmpty => 'not reported';

  @override
  String get linkIdle => 'idle';

  @override
  String get linkScanning => 'scanning';

  @override
  String get linkConnecting => 'connecting';

  @override
  String get linkNegotiating => 'negotiating';

  @override
  String get linkConnected => 'connected';

  @override
  String get linkReconnecting => 'reconnecting';

  @override
  String get linkFailed => 'failed';

  @override
  String variantReasonUnreadable(String version, String model) {
    return 'Could not read a major version out of \"$version\" on model $model.';
  }

  @override
  String variantReasonModern(String version, int major) {
    return 'Firmware $version (major $major >= 11).';
  }

  @override
  String variantReasonLegacy(String version, int major) {
    return 'Firmware $version (major $major < 11) implies JK02_24S, but the JK04 balancer family also reports versions below 11. Confirm the decoded values look sane before trusting them.';
  }

  @override
  String get healthGaugeLabel => 'Health';

  @override
  String get healthGaugeMeasured => 'measured';

  @override
  String get healthGaugeReported => 'as the BMS reports it';

  @override
  String get healthVerdictGood => 'The pack is where it should be';

  @override
  String get healthVerdictWatch => 'The pack has lost some capacity';

  @override
  String get healthVerdictBad => 'The pack is fairly worn';

  @override
  String get healthHowCalculated => 'How these are worked out';

  @override
  String get healthCardCapacity => 'Real capacity';

  @override
  String get healthCardLoss => 'Loss';

  @override
  String get healthCardCycles => 'Real cycles';

  @override
  String get healthCardInflation => 'Counter inflates';

  @override
  String get healthCardImbalance => 'Imbalance';

  @override
  String get healthCardWeakest => 'Cell in charge';

  @override
  String get healthCardSpread => 'Worst resistance';

  @override
  String get healthCardUsable => 'Usable energy';

  @override
  String get healthCardConsumption => 'Consumption';

  @override
  String get healthCardLearnedKm => 'Kilometres learned';

  @override
  String get tripTitle => 'Trip';

  @override
  String get tripOpen => 'Trip mode';

  @override
  String get tripStart => 'Start trip';

  @override
  String get tripPause => 'Pause';

  @override
  String get tripResume => 'Resume';

  @override
  String get tripStop => 'Finish';

  @override
  String get tripRecording => 'recording';

  @override
  String get tripPaused => 'paused';

  @override
  String get tripIdle => 'no trip';

  @override
  String get tripDistance => 'Distance';

  @override
  String get tripSpeed => 'Speed';

  @override
  String get tripMaxSpeed => 'Top';

  @override
  String get tripAvgSpeed => 'Average';

  @override
  String get tripMoving => 'Moving';

  @override
  String get tripElapsed => 'Elapsed';

  @override
  String get tripConsumption => 'Consumption';

  @override
  String get tripEnergyOut => 'Energy used';

  @override
  String get tripEnergyIn => 'Recovered';

  @override
  String get tripSocUsed => 'Charge used';

  @override
  String get tripSocPerKm => 'Charge per km';

  @override
  String get tripSag => 'Worst sag';

  @override
  String get tripMaxCurrent => 'Peak current';

  @override
  String get tripMaxTemp => 'Peak temperature';

  @override
  String get tripMaxDelta => 'Worst delta';

  @override
  String get tripClimb => 'Climb';

  @override
  String get tripDescent => 'Descent';

  @override
  String get tripSummaryTitle => 'Trip finished';

  @override
  String get tripNotSaved =>
      'The trip is stored along with its track. You can find it later in the Trips tab.';

  @override
  String get tripHowItLearns =>
      'On finishing, the measured Wh and the kilometres covered go into the range estimator. Every trip corrects it a little further.';

  @override
  String get tripPackDuring => 'How the pack behaved';

  @override
  String get tripClose => 'Close';

  @override
  String get locationDisabled =>
      'Phone location is off. Turn it on to record distance.';

  @override
  String get locationDenied =>
      'Without location permission there is no distance and no speed.';

  @override
  String get locationDeniedForever =>
      'Location permission is blocked. Enable it in Android settings.';

  @override
  String get historyTitle => 'History';

  @override
  String get historyEmpty => 'No trips recorded yet';

  @override
  String get historyEmptyHint =>
      'Start a trip from the Now tab and it lands here when you finish, track and all.';

  @override
  String get historyTrips => 'Trips';

  @override
  String get historyTotals => 'Totals';

  @override
  String get historyTotalDistance => 'Total distance';

  @override
  String get historyTotalEnergy => 'Total energy';

  @override
  String get historyTotalTrips => 'Trips';

  @override
  String get historyAverage => 'Average consumption';

  @override
  String get historyDelete => 'Delete trip';

  @override
  String get historyDeleted => 'Trip deleted';

  @override
  String get historyUndo => 'Undo';

  @override
  String get historyDetail => 'Trip detail';

  @override
  String historyPoints(int count) {
    return '$count track points';
  }

  @override
  String get historyNoPoints => 'No track stored';

  @override
  String get historyProfile => 'Trip profile';

  @override
  String get historyLegendSpeed => 'Speed';

  @override
  String get historyLegendAltitude => 'Altitude';

  @override
  String get historyStorage => 'Storage';

  @override
  String get historyStorageSnapshots => 'Readings stored';

  @override
  String get historyStorageFrames => 'Raw frames';

  @override
  String get historyStorageSize => 'On disk';

  @override
  String get historyStorageNote =>
      'Raw frames are kept for 30 days and then dropped. They exist so the history can be re-read if one of the protocol offsets turns out to have been wrong.';

  @override
  String get adviceTitle => 'What I would do about this';

  @override
  String get adviceNone => 'Nothing to flag. The pack is behaving.';

  @override
  String get adviceImbalanceAtRestTitle => 'The cells sit apart even at rest';

  @override
  String adviceImbalanceAtRestBody(String delta, int cell) {
    return 'With the bike still, the delta reaches $delta V. With no current involved that is not resistance: the cells simply hold different amounts of charge. Charge to full and leave it sitting for a few hours so the balancer can work; if several charges do not close it, cell $cell has less capacity than the rest.';
  }

  @override
  String get adviceImbalanceUnderLoadTitle =>
      'The delta only opens under current';

  @override
  String adviceImbalanceUnderLoadBody(String delta, int cell) {
    return 'At rest the cells are even, but under load they spread $delta V further apart. That is resistance, and nine times out of ten it is a loose or corroded connection rather than a bad cell. Check the bolt and busbar on cell $cell before replacing anything.';
  }

  @override
  String get adviceWeakCellTitle => 'It is always the same cell';

  @override
  String adviceWeakCellBody(int cell, String percent) {
    return 'Cell $cell has been the lowest in $percent% of readings. That is not noise: this is the cell that sets your real range and reaches cutoff first.';
  }

  @override
  String get adviceCycleInflatedTitle => 'The cycle counter flatters the pack';

  @override
  String adviceCycleInflatedBody(String factor) {
    return 'The BMS claims $factor times more cycles than the charge actually put through the pack justifies. It counts partial charges as whole ones. If you are buying or selling a pack, the honest number is the equivalent-cycle figure.';
  }

  @override
  String get adviceHealthDecorativeTitle => 'The BMS health figure never moves';

  @override
  String get adviceHealthDecorativeBody =>
      'It is still pinned at 100% with real cycles behind it. Plenty of firmwares never recompute it. Ignore it and go by measured capacity.';

  @override
  String get adviceCapacityBelowTitle =>
      'There is less capacity here than the label claims';

  @override
  String adviceCapacityBelowBody(String percent) {
    return 'The numbers the BMS reports imply $percent% less than the pack is rated for. That could be real degradation, or a coulomb counter that has drifted. A full capacity test settles it either way.';
  }

  @override
  String get adviceNoCapacityTestTitle =>
      'You have never actually measured the capacity';

  @override
  String get adviceNoCapacityTestBody =>
      'It is the only way to know whether you got what the box said. Charge to full, ride until it cuts off, and let the app integrate the amp-hours that came out. Everything else is an estimate.';

  @override
  String get adviceRunningHotTitle => 'The pack is running hot';

  @override
  String adviceRunningHotBody(String temp) {
    return 'It reached $temp °C. Ease off and check nothing is blocking airflow. Heat is what ages a lithium cell fastest.';
  }

  @override
  String get adviceBalancerNeverSeenTitle => 'The balancer has never started';

  @override
  String adviceBalancerNeverSeenBody(String voltage) {
    return 'The cells are uneven but the balancer has not worked all session. Either it is switched off, or its start voltage ($voltage V) sits above where your cells ever reach. Check it in the BMS settings with the official app: this app writes nothing.';
  }

  @override
  String get adviceOvervoltageHighTitle => 'The overvoltage limit is set high';

  @override
  String adviceOvervoltageHighBody(String voltage) {
    return 'It is at $voltage V per cell. For NMC, every tenth above 4.20 is paid for in cycles. Dropping it slightly costs a little range and returns a lot of life.';
  }

  @override
  String get adviceRangeLearningTitle => 'The range figure is still a guess';

  @override
  String adviceRangeLearningBody(String km) {
    return 'It has $km km behind it so far. Record a few full rides and the number settles onto how you actually ride.';
  }

  @override
  String get adviceImbalanceCostingTitle =>
      'The imbalance is costing you range';

  @override
  String adviceImbalanceCostingBody(String percent) {
    return '$percent% of the energy the pack still holds is stranded above cutoff, because the lowest cell gets there before the others. Closing the delta gives those kilometres back without replacing a single cell.';
  }

  @override
  String get statusAllClear => 'All good';

  @override
  String get statusExplain =>
      'This band watches three things: that the BMS has raised no alarms, that the cells are not far apart from each other, and that nothing is too hot. It does not watch how much charge is left: an empty battery is not a sick one.';

  @override
  String statusSpreadWatch(String delta) {
    return 'Cells $delta V apart';
  }

  @override
  String statusSpreadBad(String delta) {
    return 'Cells far apart: $delta V';
  }

  @override
  String statusTempWatch(String temp) {
    return 'Running warm: $temp °C';
  }

  @override
  String statusTempBad(String temp) {
    return 'Too hot: $temp °C';
  }

  @override
  String get tripStartFromHistory => 'Start a trip';

  @override
  String get tripDeleteConfirmTitle => 'Delete this trip?';

  @override
  String get tripDeleteConfirmBody =>
      'The trip and its track are removed. The consumption the range estimator learned is recalculated without it.';

  @override
  String get tripDeleteConfirm => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get tripSwipeHint => 'Swipe a trip left to delete it.';

  @override
  String rangeRelearned(int count) {
    return 'Range relearned from $count trips';
  }

  @override
  String get tripLearnedTitle => 'What this ride taught';

  @override
  String tripLearnedFirst(String after) {
    return 'First ride with usable data, so the learned consumption becomes this one: $after Wh/km.';
  }

  @override
  String tripLearnedChanged(String before, String after) {
    return 'Learned consumption moved from $before to $after Wh/km.';
  }

  @override
  String tripLearnedUnchanged(String after) {
    return 'This ride confirmed what it already knew: $after Wh/km.';
  }

  @override
  String get tripLearnedTooShort =>
      'Too short to learn anything. It needs at least 500 metres with real consumption.';

  @override
  String get tripLearnedRange => 'Range now';

  @override
  String get tripLearnedTotalKm => 'Learned from';

  @override
  String get tripLearnedConfidence => 'Confidence';

  @override
  String get tripDeepDischargeTip =>
      'This ride took the charge a long way down, which is exactly what helps most: the more of the battery a ride covers, the less room for error is left in the estimate.';

  @override
  String get tripShallowTip =>
      'Tip: a ride that uses little charge leaves more room for error. To sharpen the range figure, one long ride teaches far more than several short ones.';

  @override
  String tripHotTip(String temp) {
    return 'The pack reached $temp °C on this ride. Worth a look at the Thermal tab if it happens again.';
  }

  @override
  String tripDeltaTip(String delta) {
    return 'The delta reached $delta V under load. If the cells are even at rest, that points at a connection rather than a bad cell.';
  }

  @override
  String tripThirstyTip(String percent) {
    return 'This ride used $percent% more than your average. Wind, hills, load or right hand: if it repeats, the average will follow on its own.';
  }

  @override
  String get tripStopped => 'Stopped';

  @override
  String get tripNotificationTitle => 'Trip recording';

  @override
  String get tripNotificationChannel => 'Trip recording';

  @override
  String get tripNotificationChannelDesc =>
      'Keeps a trip recording with the screen off or another app open.';

  @override
  String get tripNotificationDenied =>
      'Without notification permission the trip stops when you leave the app. It can be enabled in Android settings.';

  @override
  String get proximityTitle => 'Connect when I get close';

  @override
  String get proximityBody =>
      'While this is on, the app looks for your BMS every half minute and connects on its own the moment it appears. Meant to be left on for a stretch while a new battery is being calibrated, not forever: while it is connected the official JK app cannot get in, and scanning costs some phone battery.';

  @override
  String get proximityLimit =>
      'Works with the app open or backgrounded. If Android kills the process it stops looking until you open it again.';

  @override
  String get proximityRemembered => 'Watching for';

  @override
  String get proximityNoDevice =>
      'Connect to your BMS once and it will be remembered here.';

  @override
  String get proximityFound => 'BMS found, connecting';

  @override
  String get proximityScanning => 'looking';

  @override
  String get capacityTitle => 'Capacity test';

  @override
  String get capacityIntro =>
      'The one real measurement in this app. Everything else is arithmetic on what the BMS says about itself; this counts the amp-hours that actually come out between full and cutoff, and compares them with what you were sold.';

  @override
  String get capacityStart => 'Start test';

  @override
  String get capacityAbort => 'Cancel test';

  @override
  String get capacityRunning => 'measuring';

  @override
  String get capacityNotFull =>
      'Charge the pack to the top first. Starting half full would only measure part of it, and the result would come out short.';

  @override
  String get capacityNoReadings => 'Connect the BMS first.';

  @override
  String get capacityDrawn => 'Drawn so far';

  @override
  String get capacityProgress => 'Progress';

  @override
  String get capacityStartedAt => 'Started';

  @override
  String get capacityResult => 'Measured capacity';

  @override
  String get capacityVsCatalogue => 'Against catalogue';

  @override
  String get capacityCharged =>
      'The pack was charged part way through, so the total is meaningless. Worth repeating from full with nothing plugged in.';

  @override
  String get capacityCost =>
      'Note: running the pack to cutoff costs cycles. Worth doing occasionally to measure, not as a habit.';

  @override
  String get capacityNone => 'You have not measured the capacity yet';

  @override
  String get capacityHistory => 'Measurements';

  @override
  String get capacityAutoNote =>
      'You do not have to remember anything: the app reads back the stored readings and takes any complete discharge that already happened as a measurement. The button is for doing one deliberately, with live progress.';

  @override
  String get capacityAutoTag => 'found';

  @override
  String capacityGapWarning(String minutes) {
    return '$minutes min of it went unwatched, so the figure reads low.';
  }

  @override
  String get chargeReportTitle => 'Last charge';

  @override
  String get chargeReportIntro =>
      'Above 4.0 V per cell the curve turns steep, so a small difference in charge between cells shows up as a large difference in voltage. It is the best window the pack offers, and the one nobody watches because charging happens overnight.';

  @override
  String get chargeAdded => 'Put in';

  @override
  String chargeFrom(String start, String end) {
    return 'From $start% to $end%';
  }

  @override
  String get chargeDeltaStart => 'Delta at the start';

  @override
  String get chargeDeltaTop => 'Delta at the top';

  @override
  String get chargeWorstDelta => 'Worst delta up top';

  @override
  String get chargeWeakCell => 'Cell falling behind';

  @override
  String get chargeBalancerTime => 'Balancer working';

  @override
  String get chargeNeverReachedTop =>
      'This charge never got above 4.0 V per cell, so it says nothing about imbalance. It has to reach the top to be useful.';

  @override
  String chargeOpensAtTop(int cell) {
    return 'The cells were even and came apart at the end. That pattern is capacity mismatch rather than a loose connection: cell $cell fills before the others.';
  }

  @override
  String get chargeNone => 'No charge has been recorded yet';

  @override
  String get trendsTitle => 'Over time';

  @override
  String get trendsConsumption => 'Consumption per ride';

  @override
  String get trendsCapacity => 'Measured capacity';

  @override
  String get trendsSag => 'Sag under load';

  @override
  String get trendsDeltaVsCharge => 'Delta against charge';

  @override
  String trendsSpan(int days) {
    return '$days days of history';
  }

  @override
  String get trendsNotEnough =>
      'This needs more history before it means anything. It fills in on its own.';

  @override
  String trendsPerMonth(String value) {
    return '$value per month';
  }

  @override
  String get trendsLegendLoaded => 'Under load';

  @override
  String get trendsLegendResting => 'At rest';

  @override
  String get trendsDeltaHint =>
      'A delta that is flat and jumps near the top means a cell with less capacity. One that grows with current is resistance: almost always a connection.';

  @override
  String get trendsSagHint =>
      'The same current producing a bigger drop as the months pass means internal resistance is climbing. It shows long before capacity loss does.';

  @override
  String get alertTitle => 'Alert';

  @override
  String get alertBmsFault => 'The BMS raised an alarm';

  @override
  String get alertCellSpread => 'The cells have drifted far apart';

  @override
  String get alertTemperature => 'The pack is too hot';

  @override
  String get alertLowCharge => 'Charge is getting low';

  @override
  String get alertCriticalCharge => 'Charge is nearly gone';

  @override
  String get alertCellNearCutoff => 'A cell is close to cutoff';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsCatalogue => 'Catalogue capacity';

  @override
  String get settingsCatalogueHint =>
      'What the label on the pack claims. Health is measured against this number, so it is worth getting right.';

  @override
  String get settingsBmsConfigured => 'Configured in the BMS';

  @override
  String settingsCapacityMismatch(String bms, String sold) {
    return 'The BMS is configured for $bms Ah and the pack was sold as $sold Ah. The BMS figure is not a measurement: it is what whoever assembled the pack typed in, and it is what the charge percentage is scaled against. The disagreement is itself a finding, so the app does not copy it over yours.';
  }

  @override
  String get settingsHaptics => 'Buzz on alerts';

  @override
  String get settingsHapticsHint =>
      'Nobody looks at the screen while riding. This makes the phone speak up from a pocket.';

  @override
  String get settingsRawFrames => 'Keep raw frames';

  @override
  String get settingsRawFramesHint =>
      'Leave this on. It is what allows the history to be re-read if a protocol offset turns out to have been wrong.';

  @override
  String get settingsSave => 'Save';

  @override
  String get exportTitle => 'Export';

  @override
  String get exportIntro => 'Data you cannot get out is not really yours.';

  @override
  String get exportTrips => 'Trips (CSV)';

  @override
  String get exportReadings => 'Last week of readings (CSV)';

  @override
  String get exportFrames => 'Last day of raw frames';

  @override
  String get exportTrack => 'Track (GPX)';

  @override
  String exportDone(String path) {
    return 'Saved to $path';
  }

  @override
  String get exportFailed => 'Could not export';

  @override
  String get warnWireResistance => 'High wire resistance';

  @override
  String get warnMosfetOvertemp => 'MOSFET overheating';

  @override
  String get warnCellCountMismatch => 'Cell count differs from settings';

  @override
  String get warnFullyCharged => 'Pack fully charged';

  @override
  String get warnPackOvervoltage => 'Pack overvoltage';

  @override
  String get warnChargeOvercurrent => 'Charge overcurrent';

  @override
  String get warnChargeShortCircuit => 'Short circuit while charging';

  @override
  String get warnChargeOvertemp => 'Too hot to charge';

  @override
  String get warnChargeUndertemp => 'Too cold to charge';

  @override
  String get warnCoprocessor => 'BMS internal communication fault';

  @override
  String get warnCellUndervoltage => 'Cell below minimum';

  @override
  String get warnPackUndervoltage => 'Pack below minimum';

  @override
  String get warnDischargeOvercurrent => 'Discharge overcurrent';

  @override
  String get warnDischargeShortCircuit => 'Short circuit while discharging';

  @override
  String get warnDischargeOvertemp => 'Too hot while discharging';

  @override
  String get warnChargeMosfet => 'Charge MOSFET fault';

  @override
  String get warnDischargeMosfet => 'Discharge MOSFET fault';

  @override
  String get warnGpsDisconnected => 'GPS disconnected';

  @override
  String get warnChangePassword => 'Change the BMS password';

  @override
  String get warnDischargeOnFailed => 'Could not switch discharge on';

  @override
  String get warnPackOvertemp => 'Pack overheating';

  @override
  String get warnTempSensor => 'Temperature sensor fault';

  @override
  String get warnPlModule => 'PL module fault';

  @override
  String get warnScpRelease => 'Short-circuit protection did not release';

  @override
  String get warnDischargeOcp2 => 'Discharge overcurrent (level 2)';

  @override
  String get warnDischargeOcp3 => 'Discharge overcurrent (level 3)';

  @override
  String get warnDischargeUndertemp => 'Too cold while discharging';

  @override
  String get warnGpsRemoteLock => 'Remote GPS lock';

  @override
  String get updateTitle => 'Updates';

  @override
  String get updateIntro =>
      'This app is not on a store, so it updates from GitHub releases. It never checks or downloads on its own: you ask.';

  @override
  String get updateInstalled => 'Installed version';

  @override
  String get updatePublished => 'Latest published';

  @override
  String updateReleasedOn(String date) {
    return 'Published on $date';
  }

  @override
  String get updateCheck => 'Check for update';

  @override
  String get updateChecking => 'Checking...';

  @override
  String get updateUpToDate => 'You are on the latest version.';

  @override
  String updateAvailable(String version, String size) {
    return 'Version $version is available ($size MB).';
  }

  @override
  String get updateDownload => 'Download';

  @override
  String updateDownloading(String percent) {
    return 'Downloading... $percent%';
  }

  @override
  String get updateInstall => 'Install';

  @override
  String get updateReady =>
      'Downloaded. Android will ask you to confirm the install.';

  @override
  String updateNoAsset(String version) {
    return 'Version $version exists, but has no build for this phone\'s processor.';
  }

  @override
  String updateFailed(String error) {
    return 'Could not check: $error';
  }

  @override
  String get updateNeedsToken =>
      'GitHub did not serve the release. Usually that means the repository is private, which needs a read-only token. If it is public, try again in a moment.';

  @override
  String get updateTokenLabel => 'GitHub token';

  @override
  String get updateTokenHint =>
      'Only needed while the repository is private. Kept on this phone and sent only to api.github.com; it is not inside the APK, precisely so it does not travel with it.';

  @override
  String get updateTokenSave => 'Save';

  @override
  String get updateTokenSaved => 'Token saved';

  @override
  String get updateNeedsPermission =>
      'Android does not let this app install packages yet. Grant it the permission and come back.';

  @override
  String get updateOpenPermission => 'Open settings';

  @override
  String get updateNotes => 'What\'s new';
}
