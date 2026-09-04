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
  String get connectScanFinished => 'Scan finished';

  @override
  String get connectLocationDenied =>
      'Android does not hand over Bluetooth scan results unless the app holds location permission. That is a system rule, not something the app needs to track you: location is only used while recording a ride. Without it the scan finishes empty and says nothing about why.';

  @override
  String get connectGrantLocation => 'Grant permission';

  @override
  String connectSeenCount(String count) {
    return '$count Bluetooth devices seen';
  }

  @override
  String get connectNothingFoundHelp =>
      'Nothing turned up. It is almost always one of these:\n\n• The official JK app is connected to the BMS. While it is, the BMS stops advertising and no other phone can see it. Close it fully.\n• The pack is asleep. Switch the bike on or move it to wake it.\n• You are too far away. Get closer to the pack.';

  @override
  String get connectCancelScan => 'Cancel scan';

  @override
  String get connectNoDevices => 'No BMS found yet';

  @override
  String get connectLocationOff =>
      'The phone\'s location is switched off. Android returns no Bluetooth scan results without it, even with the permission granted: it reports zero devices and says nothing. Turn it on and scan again.';

  @override
  String get connectOtherDevices => 'Other devices nearby';

  @override
  String get connectOtherDevicesHint =>
      'Nothing is hidden. If your BMS has a different name — renamed in the official app, or a model that does not advertise one — it is in this list. Look for the strongest signal and try it.';

  @override
  String get connectLikelyBms => 'likely BMS';

  @override
  String get connectByService => 'advertises the JK service';

  @override
  String get tapBusy =>
      'An attempt is already running. Let it finish: tapping again does not speed it up and can leave another connection stuck on the phone.';

  @override
  String tapCooling(String seconds) {
    return 'Wait $seconds s before retrying this pack. The pause is not arbitrary: the BMS takes a few seconds to let go of the previous link, and every attempt inside that window leaves a connection the phone does not close.';
  }

  @override
  String tapStackSaturated(String count) {
    return 'That is $count failed attempts in a row. By now the problem is the phone\'s Bluetooth, not the pack, and another attempt only makes it worse. Switch Bluetooth off and on; if it persists, restart the phone. Then tap Disconnect or search again to retry.';
  }

  @override
  String get tapHeldByPhone =>
      'The phone already has a connection to this pack open that this app does not own. Either another app holds it, or it was stranded by an earlier attempt. No attempt from here will win it: close the other app, or restart the phone\'s Bluetooth.';

  @override
  String get tileConnected => 'Connected. Tap to go back to its screens.';

  @override
  String tileCooling(String seconds) {
    return 'Paused for $seconds s after a failed attempt';
  }

  @override
  String get tileStackSaturated =>
      'On hold: the phone\'s Bluetooth needs restarting';

  @override
  String get tilePillOpen => 'open';

  @override
  String get connectedCardNote =>
      'The link is still open. Leaving the pack screens no longer cuts it, so you can come and go without reconnecting.';

  @override
  String get connectedCardOpen => 'View the pack';

  @override
  String get connectedCardRelease => 'Disconnect';

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
  String get waitingWhyLinkDown =>
      'The Bluetooth link is not up right now. The app keeps retrying on its own; if it does not come back, the reason appears above.';

  @override
  String get waitingWhyNoFrames =>
      'Connected, but not one frame has arrived from the BMS. Either the pack is silent towards the app, or something else holds its data session.';

  @override
  String get waitingWhyOnlyDeviceInfo =>
      'Device information arrived, but no cell readings. The app asks the pack for them again every 3 seconds.';

  @override
  String get waitingWhyVariantUnknown =>
      'Cell readings arrive, but the app could not work out which protocol variant this pack speaks, so it does not decode them. Pick the variant by hand in System.';

  @override
  String get waitingWhyDecodeFailing =>
      'Cell readings arrive but fail to decode. The exact reason is in the notices below and in System.';

  @override
  String get waitingWhyUnexplained =>
      'Readings arrive, decode and are emitted, yet none reached this screen. That is a fault in the app: screenshot this screen and send it.';

  @override
  String get waitingCellVoltages => 'cell voltages';

  @override
  String get waitingTemperatures => 'temperatures';

  @override
  String get soc => 'Charge';

  @override
  String get range => 'Range left';

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
  String get systemVariantProved =>
      'Checked against a real reading: the numbers this framing produces describe a battery that could exist.';

  @override
  String get systemVariantCorrected =>
      'The app switched framing on its own. The firmware version pointed at another one, and with that one the numbers were impossible; this is the one the reading agrees with.';

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
  String get adviceCapacityBelowTitle => 'It holds less than the label claimed';

  @override
  String adviceCapacityBelowBody(String percent) {
    return 'The BMS figures imply $percent% less than was advertised. That does not mean the battery is failing: the commonest explanation is that it never was that capacity. A full capacity test separates the two, and from then on degradation is measured against what this battery really delivered.';
  }

  @override
  String get adviceNoCapacityTestTitle => 'No real capacity measurement yet';

  @override
  String get adviceNoCapacityTestBody =>
      'You do not have to do anything special: the app reads back the stored readings and takes any complete discharge that happens as a measurement. It has to be a complete one because everything else is circular: the percentage the BMS reports is worked out by counting amp-hours and dividing by the capacity it is configured for, so measuring a partial discharge against that percentage returns the configured capacity again, not the real one. Only a charge to the top and a discharge to the cutoff have both ends anchored to voltage.';

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
      'The odd one out: sideways is the charge level, not time. Each dot is one reading, placed by how full the pack was and how far apart its highest and lowest cell were at that moment. What matters is the shape. Flat across the middle with a spike near full is one cell with less capacity than the rest. A curve that follows the current instead, higher under load, is resistance somewhere, and almost always a connection rather than a cell.';

  @override
  String get trendsSagHint =>
      'How many milliohms of internal resistance each ride implies, worked out from how far the voltage fell for the current drawn. Oldest on the left. Rising resistance is the first thing to go on an ageing pack and shows up long before capacity does, so a climb here is an early warning rather than a verdict. A sudden jump is usually a connection, not the cells.';

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
  String get catalogueUnset => 'Not set';

  @override
  String get catalogueUnsetHint =>
      'Nobody has said how many amp-hours this battery was sold as, and the app does not invent one. Until you set it, health and degradation cannot be worked out: there is nothing to measure them against.';

  @override
  String get catalogueSetIt => 'Set capacity';

  @override
  String catalogueUseBms(String ah) {
    return 'Use the BMS figure, $ah Ah';
  }

  @override
  String get catalogueNotComparable => 'not compared';

  @override
  String settingsCatalogueForPack(String pack) {
    return 'What $pack was sold as. Each battery has its own, so changing it here does not touch the others.';
  }

  @override
  String get exportNoPack => 'Connect a pack to export its history.';

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

  @override
  String get packsTitle => 'Batteries';

  @override
  String get packsIntro =>
      'Everything the app measures — capacity, degradation, which cell lags, what a kilometre costs — is about one specific battery. Each pack keeps its own history, so the same phone can be used with several without mixing them.';

  @override
  String get packsCurrent => 'Connected now';

  @override
  String get packsNone => 'None connected';

  @override
  String get packsKnown => 'Known batteries';

  @override
  String packsLastSeen(String date) {
    return 'Seen on $date';
  }

  @override
  String get packsRename => 'Rename';

  @override
  String get packsRenameHint => 'Battery name';

  @override
  String get packsSave => 'Save';

  @override
  String get packsCancel => 'Cancel';

  @override
  String get packsDelete => 'Delete battery';

  @override
  String packsDeleteConfirm(String pack) {
    return 'This deletes $pack and everything recorded on it: rides, tracks, readings, raw frames and capacity measurements. It cannot be undone.';
  }

  @override
  String packsRides(String count) {
    return '$count rides';
  }

  @override
  String get orphansTitle => 'History with no battery attached';

  @override
  String orphansBody(String count) {
    return 'There are $count rows stored before the app separated by battery, so there is no record of which one they came from. You can attach them to the connected battery or discard them. The app does not guess: invented provenance sitting next to real measurements is worse than a gap.';
  }

  @override
  String get orphansAdopt => 'Attach to this battery';

  @override
  String get orphansDiscard => 'Discard';

  @override
  String get orphansDone => 'Done';

  @override
  String get storedTitle => 'Stored batteries';

  @override
  String get storedOpen => 'View history';

  @override
  String get storedNone => 'You have not connected a battery yet.';

  @override
  String storedLastSeen(String when) {
    return 'Last reading $when';
  }

  @override
  String get storedNever => 'no stored readings';

  @override
  String get offlineTitle => 'Stored summary';

  @override
  String get offlineBanner =>
      'Offline — all of this comes from what was already stored, not from the BMS right now.';

  @override
  String get offlineLastReading => 'Last reading';

  @override
  String get offlineStateOfCharge => 'Charge then';

  @override
  String get offlineTrips => 'Rides';

  @override
  String offlineTripsCount(String count) {
    return '$count stored';
  }

  @override
  String get offlineTotalKm => 'Total distance';

  @override
  String get offlineRange => 'Learned range';

  @override
  String get offlineRangeUnknown => 'not learned yet';

  @override
  String get offlineNoData =>
      'No stored readings for this battery yet. Connect once and it will be here.';

  @override
  String get appSettingsTitle => 'Settings';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionPack => 'This battery';

  @override
  String get agoPrefix => '';

  @override
  String get agoSuffix => 'ago';

  @override
  String get catalogueFromBmsTag => 'from the BMS';

  @override
  String get catalogueConfirm => 'Confirm it was sold as this';

  @override
  String get catalogueFromBmsHint =>
      'Taken from the BMS configuration. That is a number about this pack, but whoever assembled it typed it in. If you were sold a different capacity, set it: the gap between the two is exactly what health measures.';

  @override
  String get connectRetry => 'Search again';

  @override
  String get storedManageHint => 'Long-press a battery to rename or delete it.';

  @override
  String get offlineHealthTitle => 'Stored health';

  @override
  String get offlineMeasuredHealth => 'Wear measured';

  @override
  String get offlineImplied => 'Capacity the BMS is set to';

  @override
  String get offlineImpliedHint =>
      'A setting inside the BMS, not a measurement of the cells. It is what every percentage the pack reports is scaled against, so it is worth seeing, and it stays the same however tired the battery gets.';

  @override
  String get offlineImpliedUnusable =>
      'Only readable between about 25 % and 90 % charge.';

  @override
  String get offlineSoh => 'Health the BMS claims';

  @override
  String get offlineCycles => 'Cycles the BMS counts';

  @override
  String get offlineWeakest => 'Weakest cell';

  @override
  String offlineWeakestValue(String index, String volts) {
    return 'cell $index, $volts V';
  }

  @override
  String get offlineMaxTemp => 'Temperature';

  @override
  String get offlineHistorySince => 'History since';

  @override
  String offlineReadings(String count) {
    return '$count stored readings';
  }

  @override
  String get offlineBestMeasured => 'Best real measurement';

  @override
  String get connectWaitingFirst =>
      'Connecting and waiting for the first reading...';

  @override
  String get connectNotABms =>
      'It connected, but no BMS reading arrived. That device is almost certainly not a JK BMS. If you believe it is, check the raw frame console in Settings.';

  @override
  String get connectLinkNeverCameUp =>
      'The Bluetooth link to the pack did not come up in 25 seconds, and the app tried more than once. Check that the pack is on and nearby, and that the official JK app is fully closed, not just in the background.';

  @override
  String get connectSilentJk =>
      'It connected, but the pack said nothing for 12 seconds. It announces itself as JK, so it is a JK BMS: its one data session belongs to someone else, or is stuck. Look first at the official JK app, which reconnects on its own from the background: force-stop it in Android settings, do not just close it. If nobody else is there, the BMS\'s Bluetooth module lets a stuck session go by itself after a while, and switching the phone\'s Bluetooth off and on does not hurry it; with the proximity watcher on, the app retries on its own. The raw frame console in Settings shows whether anything arrives.';

  @override
  String get connectTalkingUndecoded =>
      'It connected and bytes are arriving, but none of them decode as a JK frame. Check the raw frame console in Settings: what shows up there is what is needed to add support.';

  @override
  String storedCount(String count) {
    return '$count stored';
  }

  @override
  String updateBannerTitle(String version) {
    return 'Version $version is out';
  }

  @override
  String get updateBannerAction => 'View';

  @override
  String get updateBannerDismiss => 'Not now';

  @override
  String get thermalProbeAbsent => 'not connected';

  @override
  String get thermalAbsentNote =>
      'Unconnected probes report impossible values, around -200 C. That is not cold, it is nothing wired to that input. They are shown separately so they cannot skew the maximum or trip an alert.';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupIntro =>
      'The whole database in one file, and back again. The CSV and GPX exports are for reading the data elsewhere; this is for not losing it. If you change phones or lose one, this is the only thing that brings back months of readings, the rides with their tracks, and the raw frames.';

  @override
  String get backupExport => 'Save a copy of everything';

  @override
  String get backupExportLight => 'Save a smaller copy, without raw frames';

  @override
  String get backupImport => 'Restore from a file';

  @override
  String get backupImportMerge => 'Add to what is here';

  @override
  String get backupImportReplace => 'Replace everything';

  @override
  String get backupImportChoose =>
      'What should happen to what is already stored?';

  @override
  String get backupReplaceWarning =>
      'Replacing deletes everything on the phone before restoring. It cannot be undone.';

  @override
  String backupDone(String trips, String readings, String packs) {
    return 'Restored: $trips rides, $readings readings, $packs batteries.';
  }

  @override
  String backupFailed(String reason) {
    return 'Could not restore: $reason';
  }

  @override
  String get backupWorking => 'Working...';

  @override
  String get chargeAlertsTitle => 'Charge alerts';

  @override
  String get chargeAlertsIntro =>
      'Charging happens overnight and nobody watches it. That is what these are for. Stopping short of full is not superstition: the top of the range is where a lithium cell ages fastest, so if you do not need the whole pack tomorrow you are better off stopping early.';

  @override
  String get chargeTarget => 'Tell me at';

  @override
  String get chargeTargetOff => 'Off';

  @override
  String chargeAlertTargetReached(String soc) {
    return 'The battery reached $soc %';
  }

  @override
  String get chargeAlertComplete => 'Charging finished';

  @override
  String get chargeAlertHot => 'Getting hot while charging';

  @override
  String get chargeAlertSpread => 'Cells spreading apart at the top';

  @override
  String get compareTitle => 'Compare batteries';

  @override
  String get compareIntro =>
      'The same figures as everywhere else, side by side. The best in each row is green, and only when there is a real difference.';

  @override
  String get compareNeedsTwo =>
      'You need to have connected to at least two batteries before they can be compared.';

  @override
  String get compareHealth => 'Measured health';

  @override
  String get compareHonestCycles => 'Real cycles';

  @override
  String get compareConsumption => 'Consumption';

  @override
  String get compareWorstDelta => 'Worst delta seen';

  @override
  String get compareOpen => 'Compare batteries';

  @override
  String get driftTitle => 'Cell drifting away';

  @override
  String get driftNone => 'No cell is drifting away from the rest.';

  @override
  String get driftNotEnough =>
      'Not enough history yet. It takes a few weeks of resting readings to tell a cell that is getting worse from one that was always a little low.';

  @override
  String driftFound(String cell, String now, String rate) {
    return 'Cell $cell is drifting: $now V below the average, falling about $rate V a month.';
  }

  @override
  String get driftWhy =>
      'A cell that was always low is a pack that was built that way. One that was level six weeks ago and is under now is on its way out, and that is the difference between replacing a cell and replacing a pack.';

  @override
  String updateDialogBody(String current, String size) {
    return 'You are on $current. The new one is $size MB. Nothing downloads until you ask.';
  }

  @override
  String get widgetJustNow => 'just now';

  @override
  String widgetMinutes(String n) {
    return '$n min ago';
  }

  @override
  String widgetHours(String n) {
    return '$n h ago';
  }

  @override
  String widgetDays(String n) {
    return '$n d ago';
  }

  @override
  String get maintTitle => 'Maintenance';

  @override
  String get maintIntro =>
      'What you have done to the pack, with dates. The history records what the battery did and forgets what was done to it, which is the other half. A capacity that jumps or a delta that collapses looks like noise until you can see a cell was replaced that week.';

  @override
  String get maintNone => 'Nothing noted yet.';

  @override
  String get maintAdd => 'Note something';

  @override
  String get maintDate => 'Date';

  @override
  String get maintKind => 'What you did';

  @override
  String get maintNote => 'Detail (optional)';

  @override
  String get maintSave => 'Save';

  @override
  String get maintDelete => 'Delete';

  @override
  String get maintKindCellReplaced => 'Replaced a cell';

  @override
  String get maintKindManualBalance => 'Balanced by hand';

  @override
  String get maintKindConnections => 'Cleaned or tightened connections';

  @override
  String get maintKindCharger => 'Changed charger';

  @override
  String get maintKindBmsSettings => 'Changed BMS settings';

  @override
  String get maintKindOther => 'Something else';

  @override
  String maintSince(String date) {
    return 'History since the cell was replaced: $date';
  }

  @override
  String get trendsMaintMarks =>
      'The dotted lines are things you noted in the maintenance log.';

  @override
  String get chargeWatchTitle => 'Watch the charge';

  @override
  String get chargeWatchHint =>
      'While the app is in the background Android cuts the Bluetooth link within minutes. With this on, it raises a foreground service as soon as charging starts and holds the link, which is what the alerts need to reach you overnight. It costs phone battery while it runs.';

  @override
  String get chargeWatchNotifTitle => 'Charging';

  @override
  String chargeWatchNotifText(String soc, String volts, String amps) {
    return '$soc % · $volts V · $amps A';
  }

  @override
  String get alertSilence => 'Silence this alert';

  @override
  String get alertSilenced =>
      'Silenced. You can switch it back on in Settings.';

  @override
  String get alertsSectionTitle => 'Which alerts you want';

  @override
  String get alertsSectionHint =>
      'One by one. Switching off the one that annoys you should not cost you the ones you want.';

  @override
  String get autoTripTitle => 'Start rides on their own';

  @override
  String get autoTripHint =>
      'Opens and closes the ride when it detects you are riding: it needs pack current and GPS movement together, sustained. Without it the learning depends on remembering to press start, and the rides people forget are not a random sample: they are the short ones and the ones you were late for. Uses GPS while riding.';

  @override
  String get autoTripStarted => 'Ride started automatically';

  @override
  String get autoTripStopped => 'Ride saved';

  @override
  String get degNowTitle => 'Capacity now';

  @override
  String get degBaseline => 'Best it has ever held';

  @override
  String degBaselineOn(String date) {
    return 'measured on $date';
  }

  @override
  String get degLost => 'Degradation';

  @override
  String get degLostUnknown => 'not measurable yet';

  @override
  String get degLostWhy =>
      'Degradation is measured against the best this battery has ever held, not against what the advert said. It needs more than one measurement: with a single one you have a capacity, not a loss.';

  @override
  String get degImpliedNote =>
      'Estimated from the BMS counter, not measured. A capacity test gives the real figure.';

  @override
  String get degSoldTitle => 'Against the advert';

  @override
  String degSoldShort(String sold, String real, String pct) {
    return 'Sold as $sold Ah, and the best it has held is $real Ah: about $pct % less range than advertised. That is not wear, it was never $sold.';
  }

  @override
  String get degSoldOk => 'It has delivered what was advertised.';

  @override
  String get demoSetCharge => 'Set the charge to';

  @override
  String get demoFull => 'Fill to 100 %';

  @override
  String get demoEmpty => 'Drain to 10 %';

  @override
  String get demoSpeed => 'Simulator speed';

  @override
  String get demoSpeedHint =>
      'Speeds up the simulated pack. A capacity test is a whole discharge: at normal speed that is hours, and a feature that takes an afternoon to reach cannot be judged. Distance and GPS are not sped up, so the learned consumption stays realistic.';

  @override
  String get demoSpeedNormal => 'normal';

  @override
  String get etaFull => 'Full in';

  @override
  String get etaTapering => 'approx., the current is already tailing off';

  @override
  String get etaDone => 'It is full';

  @override
  String adviceDeepestSoFar(String from, String to) {
    return 'Deepest so far: $from % down to $to %.';
  }

  @override
  String get adviceDeepestNone => 'No discharge recorded yet.';

  @override
  String get linkLostTitle => 'Connection lost';

  @override
  String get linkLostBody =>
      'Out of range of the pack, or something else is holding the Bluetooth channel. Keeps trying on its own; what is on screen is the last reading.';

  @override
  String get linkReconnectingTitle => 'Reconnecting';

  @override
  String get linkConnectingTitle => 'Connecting';

  @override
  String linkReadingAge(String age) {
    return 'Last reading $age ago';
  }

  @override
  String get linkBack => 'Reading again';

  @override
  String get linkDetails => 'Details';

  @override
  String get troubleBusy =>
      'Something else is already connected to the pack. The JK BMS accepts only one Bluetooth connection at a time, so close the official JK app or any other logger.';

  @override
  String get troubleOutOfRange =>
      'The pack did not answer. Either it is out of range or switched off, or something else is holding its one Bluetooth connection: the official JK app, or another logger.';

  @override
  String get troubleBluetoothOff => 'Bluetooth is off on the phone.';

  @override
  String get troublePermission =>
      'The app is not allowed to use Bluetooth. Grant Nearby devices in Android settings.';

  @override
  String get troubleLocationOff =>
      'Location is off on the phone. Android needs it on to scan for Bluetooth devices.';

  @override
  String get troubleGeneric => 'Bluetooth trouble. Keeps trying on its own.';

  @override
  String get troubleSlowFrames =>
      'The phone granted a smaller Bluetooth packet size than asked for. Readings arrive in more pieces, which is slower but still correct.';

  @override
  String get troubleNotJkBms =>
      'That device has no JK Bluetooth service on it. It is not a JK BMS, or not one this app can talk to.';

  @override
  String get troublePackMute =>
      'The pack was connected but mute: not one byte in 20 seconds, despite being asked several times. The app let the connection go on purpose and is going back in within seconds; that is the only way to make the BMS\'s Bluetooth module drop the session it got stuck on.';

  @override
  String get screenAwakeTitle => 'Keep the screen on';

  @override
  String get screenAwakeHint =>
      'It used to be held on for as long as this screen was open, which is right in a phone mount and wrong on the sofa.';

  @override
  String get screenAwakeNever => 'Never';

  @override
  String get screenAwakeRiding => 'While riding';

  @override
  String get screenAwakeAlways => 'Always';

  @override
  String get linkWatchNotifTitle => 'Reading the pack';

  @override
  String get linkWatchNotifWaiting => 'Waiting for the first reading';

  @override
  String linkWatchNotifText(String soc, String volts, String amps) {
    return '$soc %  ·  $volts V  ·  $amps A';
  }

  @override
  String get linkWatchTitle => 'Keep reading with the screen off';

  @override
  String get linkWatchHint =>
      'Android stops handing an app Bluetooth readings shortly after the screen goes dark, unless the app holds a foreground service. This holds one while the pack is connected, so the app behaves the same with the screen on or off. That is what the notification is for; it is not the app announcing itself.';

  @override
  String get screenAwakeReason =>
      'With the setting above on, the screen can sleep without the readings stopping.';

  @override
  String backupScope(String packs, String trips, String readings) {
    return 'Every pack, not just the connected one: $packs batteries, $trips rides, $readings readings.';
  }

  @override
  String get backupScopeEmpty =>
      'Nothing stored yet, so there is nothing to copy.';

  @override
  String get downloadNotifTitle => 'Downloading update';

  @override
  String downloadNotifText(String percent) {
    return '$percent %';
  }

  @override
  String get learnWhyTitle => 'Why nothing has been learned';

  @override
  String learnWhyCount(String used, String considered) {
    return '$used of $considered recorded rides were usable.';
  }

  @override
  String learnWhyShort(String n) {
    return '$n were under 200 m, which is too short to divide by: a wobble in the GPS over that distance produces a consumption figure in the hundreds.';
  }

  @override
  String learnWhyNoEnergy(String n) {
    return '$n recorded distance but no energy leaving the pack. Either they were spent on a trailer, or the pack reports its current with the opposite sign to the one this app assumes.';
  }

  @override
  String get learnWhySignWarning =>
      'If it is the sign, it would also be disabling trip energy, consumption and the capacity scan, while every live reading still looks correct. Worth checking: while riding, the current on the live screen should be negative.';

  @override
  String get learnWhyNeedMore =>
      'It learns from the first ride over 200 m that draws energy. Nothing else to do.';

  @override
  String get trendsIntro =>
      'Four charts, and the useful thing about each one is its slope, not its height. A number that sits still is a healthy pack; a number that drifts in one direction over months is the pack telling you something.';

  @override
  String get trendsConsumptionHint =>
      'One dot per recorded ride, oldest on the left. Height is what that ride cost per kilometre. Riding style and weather move it around a lot, so ignore single dots and look at whether the cloud is drifting upwards over months: the same route costing more means the pack is having to work harder for it.';

  @override
  String get trendsCapacityHint =>
      'One dot per full discharge measured, oldest on the left. Height is the amp-hours the pack actually held that time. This is the only real measure of wear here, and it is the slowest to fill in: expect it to go down a little each year and be suspicious of a sudden drop.';

  @override
  String get trendsAxisTime => 'left to right: oldest to newest';

  @override
  String get trendsAxisCharge => 'left to right: empty to full';

  @override
  String learnWhyImplausible(String n) {
    return '$n came out at a consumption no motorcycle could produce, so they were refused. That is a fault in this app rather than anything about the riding, and it was fixed in this version: rides recorded from here should read correctly. The old ones cannot be repaired, because the readings they needed were never stored.';
  }

  @override
  String get connectCouldNotSearch =>
      'The radio never confirmed the search started, so nothing was actually looked for. Usually Bluetooth still waking up just after launch. Try again.';

  @override
  String get backupShare => 'Send it somewhere instead';

  @override
  String get backupSaveDialog => 'Where to put the copy';

  @override
  String backupSaved(String name) {
    return 'Saved as $name.';
  }

  @override
  String get rangeFull => 'On a full pack';

  @override
  String rangeFullBand(String low, String high) {
    return 'about $low to $high km';
  }

  @override
  String get rangeFullUnknown =>
      'Needs a measured capacity before this can be said.';

  @override
  String get rangeFullFromAdvert =>
      'From the capacity you entered, not a measured one.';

  @override
  String get rangeFullFromMeasured =>
      'From a capacity this pack actually measured.';

  @override
  String get rangeNoneLearned =>
      'Nothing learned yet, so no distance is worth quoting at any charge.';

  @override
  String get offlineRangeAtLastSeen => 'At the charge in the last reading';

  @override
  String get offlineHealthNeedsTests =>
      'Needs two full discharges before wear can be measured at all. One gives a capacity; it takes two to show a decline.';

  @override
  String offlineHealthOneTest(String ah) {
    return 'One measurement so far: $ah Ah. A second one, months from now, is what turns it into wear.';
  }

  @override
  String get healthCardShortOfAdvert => 'Vs. advertised';

  @override
  String get systemDrops => 'Link drops';

  @override
  String get systemTimeDisconnected => 'Time disconnected';

  @override
  String get systemNudges => 'Times the pack was prodded';

  @override
  String get systemNudgesHint =>
      'The app only writes to the pack once it has stopped talking for six seconds. It used to write every five seconds regardless, which appears to be what interrupted the stream. If this stays near zero on a ride whose readings are continuous, that was the cause.';

  @override
  String get settingsSectionRides => 'Rides';

  @override
  String get settingsSectionLink => 'Connection and screen';

  @override
  String get settingsSectionLinkHint =>
      'What keeps the app reading. These two go together: hold the connection open and the screen is free to sleep.';

  @override
  String offlineRangeStale(String age) {
    return 'That reading is $age old, so this is a memory rather than a figure: the pack may have been ridden or left to sit since.';
  }

  @override
  String get licenseTitle => 'Licence';

  @override
  String get licenseStatusFree => 'Free';

  @override
  String get licenseStatusTrial => 'Pro trial';

  @override
  String get licenseStatusPro => 'Pro';

  @override
  String get licenseStatusWorkshop => 'Pro Workshop';

  @override
  String get licenseStatusWorkshopExpired => 'Workshop expired';

  @override
  String licenseTrialLeft(String days) {
    return '$days days of trial left with everything Pro. After that the app keeps working: the complete live viewer, free, for good.';
  }

  @override
  String get licenseFreeBody =>
      'The complete live viewer and the last 24 hours of history, free. The rest (unlimited history, degradation, verdicts, alerts with the app closed, backup) is Pro: one payment, for life, for this phone.';

  @override
  String get licenseProBody =>
      'Pro is active on this phone. One payment, no expiry.';

  @override
  String licenseWorkshopBody(String date) {
    return 'Pro Workshop active until $date.';
  }

  @override
  String get licenseWorkshopNoEnd => 'Pro Workshop active.';

  @override
  String get licenseWorkshopExpiredBody =>
      'The Workshop licence has run out. The app is back on the free tier; renew to get Pro back.';

  @override
  String licenseCreditsLeft(String count) {
    return 'Inspection checks left: $count';
  }

  @override
  String licenseCertificatesLeft(String count) {
    return 'Certificates left: $count';
  }

  @override
  String licenseLabel(String label) {
    return 'Issued to $label';
  }

  @override
  String get licenseDeviceCode => 'This phone\'s code';

  @override
  String get licenseDeviceCodeHint =>
      'The key is bound to this code. Send it with the proof of payment and you will get a key to paste here. It is checked on the phone, with no internet.';

  @override
  String get licenseCopyCode => 'Copy code';

  @override
  String get licenseCopied => 'Copied';

  @override
  String get licenseCopyRequest => 'Copy request message';

  @override
  String licenseRequestMessage(String code, String version) {
    return 'Hi, I want to activate JK BMS + Pro.\nPhone code: $code\nApp version: $version';
  }

  @override
  String get licensePasteTitle => 'Paste key';

  @override
  String get licensePasteHint =>
      'Paste the whole key, from JKB1 to the end. Line breaks from the chat do not matter.';

  @override
  String get licenseActivate => 'Activate';

  @override
  String get licenseActivated => 'Key activated.';

  @override
  String get licenseAlreadyActive =>
      'That key was already active on this phone.';

  @override
  String get licenseRejectedMalformed =>
      'That is not a key. Check you copied all of it, from JKB1 to the end.';

  @override
  String get licenseRejectedSignature =>
      'The key is not valid: either a character is missing, or it was not issued by the author.';

  @override
  String get licenseRejectedDevice =>
      'This key is for another phone. Each key is bound to the code of the phone that asked for it.';

  @override
  String get licenseRejectedExpired => 'This key has expired.';

  @override
  String get licenseNotConfigured =>
      'This build carries no licence public key and cannot activate one. It is a development build; see docs/LICENSING.md.';

  @override
  String get licenseActiveKeys => 'Keys on this phone';

  @override
  String licenseKeyActivated(String date) {
    return 'Activated on $date';
  }

  @override
  String licenseKeyExpires(String date) {
    return 'Expires on $date';
  }

  @override
  String licenseKeyExpired(String date) {
    return 'Expired on $date';
  }

  @override
  String licenseKeyCredits(String inspections, String certificates) {
    return '$inspections checks, $certificates certificates';
  }

  @override
  String get licenseRemoveKey => 'Remove';

  @override
  String get licenseRemoveConfirmTitle => 'Remove this key?';

  @override
  String get licenseRemoveConfirmBody =>
      'The app loses what this key unlocks. The key itself stays valid: if you kept it, you can paste it again.';

  @override
  String get licenseWhyTitle => 'Why it costs money';

  @override
  String get licenseWhyBody =>
      'The free tier matches the official JK app and is never cut down. Pro is what that app cannot do by design: remember, compare and conclude. One payment; no subscriptions. No account, no server, no internet: the key is checked on the phone against the author\'s signature.';

  @override
  String get licenseOpen => 'See licence';

  @override
  String get proBadge => 'PRO';

  @override
  String get proGateTitle => 'Pro feature';

  @override
  String proGateBody(String feature) {
    return '$feature is part of Pro. One payment, for life, for this phone.';
  }

  @override
  String get proGateTrialEnded => 'The 7-day trial is over.';

  @override
  String get proFeatureHistory => 'History older than 24 hours';

  @override
  String get proFeatureDegradation => 'Degradation and the long-term curves';

  @override
  String get proFeatureVerdicts => 'The verdicts on the pack\'s condition';

  @override
  String get proFeatureBackgroundAlerts => 'Alerts with the app closed';

  @override
  String get proFeatureBackup => 'Backup and restore';

  @override
  String get proFeatureConfigAudit => 'The BMS configuration audit';

  @override
  String get proFeatureBatteryReport => 'The battery PDF report';

  @override
  String get proFeatureInspection => 'The quick inspection of another battery';

  @override
  String get proFeatureCertificate => 'The seller certificate';

  @override
  String get proFeatureWorkshop => 'The workshop features';

  @override
  String historyOlderLocked(String count) {
    return '$count rides older than 24 hours are not shown. Seeing them is Pro.';
  }

  @override
  String get chargeWatchProHint =>
      'Pro: needs a licence to hold the link with the app closed.';

  @override
  String get licenseStatusAdmin => 'Admin';

  @override
  String get licenseAdminBody =>
      'Full access on this phone: everything unlocked, no limits, no expiry.';

  @override
  String get adviceWhy => 'WHY';

  @override
  String get adviceWhyHide => 'HIDE';

  @override
  String get adviceHonestyNote =>
      'Every sentence rests on a measured figure: tap it to see which. The BMS\'s cycle count and configured capacity can be edited from the official app, so they are always checked here against what the physics says.';

  @override
  String get verdictHealthMeasuredTitle =>
      'Capacity against the best it has held';

  @override
  String verdictHealthMeasuredBody(String pct, String now, String best) {
    return 'Your battery is at $pct % of the capacity it arrived with: $now Ah measured now against $best Ah, the best it has given. Measured over full discharges, not estimated.';
  }

  @override
  String get verdictHealthNotMeasurableTitle => 'Wear cannot be measured yet';

  @override
  String verdictHealthNotMeasurableBody(String count) {
    return '$count full discharge(s) measured so far. Two are needed to speak of loss: one gives a capacity, not a decline. The app takes the next one by itself when it happens.';
  }

  @override
  String verdictCellDriftingTitle(String cell) {
    return 'Cell $cell is pulling away from the rest';
  }

  @override
  String verdictCellDriftingBody(String weeks, String dev, String rate) {
    return 'For $weeks weeks it has been drifting: $dev V under the pack average and falling about $rate V a month. Consistent with a cell on its way out. Look at it before the pack shuts down in the street.';
  }

  @override
  String get verdictNoCellDriftingTitle => 'No cell is going';

  @override
  String verdictNoCellDriftingBody(String weeks, String dev) {
    return 'Over $weeks weeks of resting readings no cell is pulling away from the rest. The worst sits $dev V under the average and is not getting worse. Nothing to do.';
  }

  @override
  String verdictRangeNowTitle(String km) {
    return 'About $km km left, the way you ride';
  }

  @override
  String verdictRangeNowBody(String wh, String learned) {
    return 'From $wh Wh/km learned over $learned km of your own riding, applied to what the pack can deliver right now. An estimate: it moves with terrain, load and throttle.';
  }

  @override
  String get verdictDeltaNormalTitle => 'Delta under load is normal';

  @override
  String verdictDeltaNormalBody(String loaded, String rest) {
    return 'Under current the delta reaches $loaded V, against $rest V at rest. Nothing resistive to chase. Nothing to do.';
  }

  @override
  String get evidenceRestingDelta => 'Delta at rest (session maximum)';

  @override
  String get evidenceLoadedDelta => 'Delta under load (session maximum)';

  @override
  String evidenceWeakCellShare(String cell) {
    return 'Readings in which cell $cell was lowest';
  }

  @override
  String get evidenceReadingsInSession => 'Readings this session';

  @override
  String get evidenceReportedCycles => 'Cycles per the BMS (editable figure)';

  @override
  String get evidenceEquivalentCycles =>
      'Equivalent cycles from amp-hours that flowed';

  @override
  String get evidenceReportedSoh => 'SOH per the BMS';

  @override
  String get evidenceImpliedCapacity =>
      'Capacity configured in the BMS (editable)';

  @override
  String get evidenceCatalogueCapacity => 'Advertised capacity';

  @override
  String get evidenceCapacityTests => 'Full discharges measured';

  @override
  String get evidenceHottestProbe => 'Hottest probe';

  @override
  String get evidenceBalanceStart => 'Balancer start voltage';

  @override
  String get evidenceCellOvp => 'Per-cell overvoltage limit';

  @override
  String get evidenceLearnedKm => 'Kilometres learned';

  @override
  String get evidenceWhPerKm => 'Learned consumption';

  @override
  String get evidenceUsableWh => 'Usable energy now';

  @override
  String get evidenceStrandedFraction => 'Energy stranded above cutoff';

  @override
  String get evidenceRangeBand => 'Estimate band';

  @override
  String evidenceBaselineCapacity(String date) {
    return 'Best it has held ($date)';
  }

  @override
  String evidenceCurrentCapacity(String date) {
    return 'Latest measurement ($date)';
  }

  @override
  String evidenceDriftDeviation(String cell) {
    return 'Cell $cell under the pack average';
  }

  @override
  String get evidenceDriftRate => 'Rate of separation';

  @override
  String get evidencePerMonth => 'month';

  @override
  String get evidenceDriftSamples => 'Resting readings analysed';

  @override
  String get evidenceDriftSpanWeeks => 'Weeks observed';

  @override
  String get verdictTitle => 'Verdict';

  @override
  String get demoScenarioInspection => 'Inspection rehearsal';

  @override
  String get demoScenarioInspectionDesc =>
      'Quiet 35 s, lights 20 s, hard pull 8 s, then released. Cell 7 is the weak one.';

  @override
  String get inspectionEntry => 'Inspect somebody else\'s battery';

  @override
  String get inspectionModeTitle => 'Inspection mode';

  @override
  String get inspectionModeBanner =>
      'The battery you connect now is not saved to your history and teaches your range nothing. Ask the seller to close their JK app and pick their BMS from the list.';

  @override
  String get inspectionModeExit => 'Leave inspection mode';

  @override
  String get inspectionRehearse => 'Rehearse with the demo pack';

  @override
  String get inspectionTitle => 'Quick inspection';

  @override
  String get inspectionWaitingReadings => 'Waiting for readings from the BMS…';

  @override
  String get inspectionStepRestTitle => 'Don\'t touch anything';

  @override
  String get inspectionStepRestBody =>
      'The app takes the resting picture. Nobody revs, nobody switches anything on.';

  @override
  String get inspectionStepLightTitle => 'Turn the lights on';

  @override
  String get inspectionStepLightBody =>
      'A small, steady draw. The app moves on by itself when it sees it.';

  @override
  String get inspectionStepHeavyTitle => 'Now a hard pull';

  @override
  String get inspectionStepHeavyBody =>
      'Rear wheel in the air and throttle, or 50 metres down the road with the phone in your pocket, or the charger plugged in. Any of them works: the app measures the current.';

  @override
  String get inspectionStepRecoveryTitle => 'Let go and wait';

  @override
  String get inspectionStepRecoveryBody =>
      'No current. The app watches how long each cell takes to climb back to where it rested.';

  @override
  String get inspectionStepDoneTitle => 'Done';

  @override
  String get inspectionCurrentNow => 'Current now';

  @override
  String inspectionLoadEnough(String amps) {
    return 'Load detected: $amps A, enough.';
  }

  @override
  String inspectionLoadTooLow(String amps) {
    return 'Too little current ($amps A). Give it more.';
  }

  @override
  String inspectionNotQuiet(String amps) {
    return 'There is current ($amps A). It needs to rest.';
  }

  @override
  String get inspectionQuietOk => 'At rest.';

  @override
  String inspectionSecondsLeft(String seconds) {
    return '$seconds s';
  }

  @override
  String inspectionStepSkipHint(String seconds) {
    return 'If this load cannot be produced, the app moves on by itself in $seconds s and says so in the verdict.';
  }

  @override
  String get inspectionSkipStep => 'Skip this step';

  @override
  String get inspectionAbort => 'Finish now';

  @override
  String get inspectionQuickTestLabel => 'QUICK TEST · ESTIMATE';

  @override
  String get inspectionLightGood => 'Nothing serious in sight';

  @override
  String get inspectionLightWatch => 'Something to look at';

  @override
  String get inspectionLightProblem => 'Don\'t buy blind: there is a problem';

  @override
  String get inspectionFidelityNote =>
      'A quick test catches the obvious scam and the bad cell; it does not measure real capacity. Real capacity takes a full discharge.';

  @override
  String get inspectionCaveatsTitle => 'What this test could not see';

  @override
  String get inspectionCaveatNoHeavyLoad =>
      'No hard pull: per-cell sag could not be measured.';

  @override
  String get inspectionCaveatNoLightLoad =>
      'No light load: the lights step never happened.';

  @override
  String get inspectionCaveatRestNoisy =>
      'The pack was never fully quiet: the resting picture is approximate.';

  @override
  String get inspectionCaveatNoRecovery =>
      'The load was never released: recovery was not measured.';

  @override
  String get inspectionCaveatStepTooSmall =>
      'The current step was small: the estimated resistance is noise.';

  @override
  String get inspectionCaveatFewReadings =>
      'Few readings: the BMS said little.';

  @override
  String get inspectionCellsTitle => 'Cell by cell';

  @override
  String get inspectionCellHeaderRest => 'Rest';

  @override
  String get inspectionCellHeaderSag => 'Sag';

  @override
  String get inspectionCellHeaderIr => 'Est. R';

  @override
  String get inspectionCellHeaderRec => 'Recov.';

  @override
  String get inspectionReportedTitle => 'What the BMS says (editable)';

  @override
  String get inspectionReportedHint =>
      'Cycles, configured capacity and SOH can be changed from the official app in a minute. Shown; not believed.';

  @override
  String get inspectionReportedCycles => 'Cycles';

  @override
  String get inspectionReportedCapacity => 'Configured capacity';

  @override
  String get inspectionReportedSoc => 'Charge';

  @override
  String get inspectionReportedSoh => 'SOH';

  @override
  String get inspectionReportedModel => 'Model';

  @override
  String inspectionSummaryLine(
    String cells,
    String amps,
    String seconds,
    String readings,
  ) {
    return '$cells cells · peak $amps A · $seconds s · $readings readings';
  }

  @override
  String get inspectionSave => 'Save inspection';

  @override
  String get inspectionSaved => 'Inspection saved.';

  @override
  String get inspectionDiscard => 'Discard';

  @override
  String get inspectionNoteHint => 'Note: seller, asking price, what was said…';

  @override
  String get inspectionsTitle => 'Inspections';

  @override
  String get inspectionsIntro =>
      'Other people\'s batteries you have looked at with the quick test. Not part of your history.';

  @override
  String get inspectionsEmpty => 'You have not inspected any battery yet.';

  @override
  String get inspectionsOpen => 'See inspections';

  @override
  String get inspectionDeleted => 'Inspection deleted.';

  @override
  String get inspectionDeleteConfirmTitle => 'Delete this inspection?';

  @override
  String get inspectionDeleteConfirmBody =>
      'The verdict and the captured readings are lost.';

  @override
  String inspectionCreditsLeft(String count) {
    return 'This inspection uses one check. You have $count left.';
  }

  @override
  String get inspectionCreditsGone => 'No checks left. Get more under Licence.';

  @override
  String verdictInspCellSaggingTitle(String cell) {
    return 'Cell $cell sags far more than the rest';
  }

  @override
  String verdictInspCellSaggingBody(String excess) {
    return 'Under the hard pull it dropped $excess V more than the pack median. Consistent with a worn cell or a bad connection at that cell. This is the main reason not to pay the asking price without more tests.';
  }

  @override
  String get verdictInspSagUniformTitle => 'Every cell sags evenly';

  @override
  String verdictInspSagUniformBody(String excess) {
    return 'Under the hard pull the worst cell dropped only $excess V more than the median. None gives up before the others.';
  }

  @override
  String get verdictInspRestDeltaWideTitle => 'Cells sit apart at rest';

  @override
  String verdictInspRestDeltaWideBody(String delta, String cell) {
    return 'With the bike still the delta is $delta V and the lowest is cell $cell. With no current that is not resistance: the cells hold different amounts of charge, or the balancer is not working.';
  }

  @override
  String get verdictInspRestDeltaOkTitle => 'Cells sit together at rest';

  @override
  String verdictInspRestDeltaOkBody(String delta) {
    return 'Delta of $delta V with the bike still. Fine.';
  }

  @override
  String verdictInspWeakLightTitle(String cell) {
    return 'Cell $cell drops with almost nothing asked';
  }

  @override
  String verdictInspWeakLightBody(String amps, String extra) {
    return 'With only the lights on ($amps A) it dropped $extra V more than the rest. A cell that gives up at one or two amps is a very tired cell.';
  }

  @override
  String verdictInspSlowRecoveryTitle(String cell) {
    return 'Cell $cell climbs back slowly';
  }

  @override
  String verdictInspSlowRecoveryBody(String extra) {
    return 'It took $extra s longer than the median to return to its resting voltage after the load, or never did. Tired cells rebound slowly; it is a rarely watched and very good sign.';
  }

  @override
  String get verdictInspRecoveryOkTitle => 'Even recovery';

  @override
  String verdictInspRecoveryOkBody(String seconds) {
    return 'After the load the cells were back at rest in about $seconds s, all at the same pace.';
  }

  @override
  String get verdictInspHotTitle => 'The pack was hot';

  @override
  String verdictInspHotBody(String temp) {
    return 'It reached $temp °C during the test. A pack that is hot at rest or under light load is not normal.';
  }

  @override
  String get verdictInspAlarmsTitle => 'The BMS raised alarms during the test';

  @override
  String verdictInspAlarmsBody(String count) {
    return '$count alarm(s) active at some point. Ask why: a BMS that complains in two minutes complains in the street.';
  }

  @override
  String get verdictInspCountersTitle =>
      'Cycles and capacity per the BMS: do not trust';

  @override
  String verdictInspCountersBody(String cycles) {
    return 'The BMS reports $cycles cycles. That figure and the configured capacity can be edited from the official app in a minute. The verdict rests on the physics above, not on these counters.';
  }

  @override
  String get verdictInspNoHeavyLoadTitle => 'No hard pull: reduced fidelity';

  @override
  String verdictInspNoHeavyLoadBody(String amps) {
    return 'The highest current seen was $amps A. Without a hard pull there is no way to measure how far each cell drops, which is where the truth comes out. Repeat with the wheel in the air or 50 metres on the bike.';
  }

  @override
  String evidenceCellSag(String cell) {
    return 'Sag of cell $cell under load';
  }

  @override
  String get evidenceMedianSag => 'Median sag of the pack';

  @override
  String get evidenceCurrentStep => 'Current step (load minus rest)';

  @override
  String evidenceCellResistance(String cell) {
    return 'Estimated resistance of cell $cell';
  }

  @override
  String get evidenceMedianResistance => 'Median estimated resistance';

  @override
  String evidenceLowestRestCell(String cell) {
    return 'Lowest cell at rest (cell $cell)';
  }

  @override
  String get evidenceLightLoadAmps => 'Current with the lights on';

  @override
  String evidenceRecoverySeconds(String cell) {
    return 'Recovery of cell $cell';
  }

  @override
  String get evidenceMedianRecoverySeconds => 'Median recovery';

  @override
  String get evidenceAlarmCount => 'Alarms seen';

  @override
  String get evidencePeakCurrent => 'Highest current seen';

  @override
  String get reportPackTitle => 'Battery report';

  @override
  String get reportInspectionTitle => 'Inspection report';

  @override
  String get reportCertificateTitle => 'Inspection certificate';

  @override
  String reportGeneratedAt(String date) {
    return 'Generated $date';
  }

  @override
  String reportAppVersion(String version) {
    return 'Version $version';
  }

  @override
  String reportPageOf(String page, String total) {
    return 'Page $page of $total';
  }

  @override
  String get reportUnknownPack => 'Unnamed battery';

  @override
  String get reportSectionNow => 'How it stands now';

  @override
  String get reportLastReading => 'Last reading';

  @override
  String get reportPackVoltage => 'Pack voltage';

  @override
  String get reportCellCount => 'Cells';

  @override
  String get reportDelta => 'Spread between cells';

  @override
  String get reportCellRange => 'Lowest and highest cell';

  @override
  String get reportMaxTemperature => 'Highest temperature';

  @override
  String get reportSectionCapacity => 'Capacity';

  @override
  String get reportConfiguredCapacity => 'Configured in the BMS';

  @override
  String get reportAdvertisedCapacity => 'Advertised when bought';

  @override
  String get reportCapacityTests => 'Completed capacity tests';

  @override
  String get reportCapacityNote =>
      'Only the best real measurement comes from a full discharge counted by the app. The configured capacity is a BMS setting, not a measurement, and can be changed in a minute.';

  @override
  String get reportSectionRange => 'Range';

  @override
  String get reportConsumption => 'Learned consumption';

  @override
  String get reportRangeBasis => 'Worked out from';

  @override
  String get reportRangeFromMeasured => 'measured capacity';

  @override
  String get reportRangeFromCatalogue => 'advertised capacity';

  @override
  String get reportSectionCells => 'Cells';

  @override
  String get reportCell => 'Cell';

  @override
  String get reportDeviation => 'Below average';

  @override
  String get reportTrend => 'Trend';

  @override
  String get reportSpan => 'Measured over';

  @override
  String reportDays(String count) {
    return '$count days';
  }

  @override
  String get reportCellsNote =>
      'A cell that was always low is a pack built that way. One that drifts apart month by month is a cell on its way out.';

  @override
  String get reportSectionHistory => 'History';

  @override
  String get reportReadings => 'Stored readings';

  @override
  String get reportSectionMaintenance => 'Recorded maintenance';

  @override
  String get reportDate => 'Date';

  @override
  String get reportEvent => 'Event';

  @override
  String get reportNote => 'Note';

  @override
  String get reportHonestyPack =>
      'The figures come from what the BMS reports and from what this app counted during use. Range is an estimate learned from real rides, not a promise. Measured capacity needs a full discharge recorded by the app; without one there is no measurement, only what the BMS claims.';

  @override
  String get reportSectionTest => 'The test';

  @override
  String get reportTestedAt => 'Run on';

  @override
  String get reportPeakCurrent => 'Peak current reached';

  @override
  String get reportRestDelta => 'Spread at rest';

  @override
  String get reportMedianSag => 'Median sag under load';

  @override
  String get reportMedianResistance => 'Median resistance';

  @override
  String get reportMedianRecovery => 'Median recovery';

  @override
  String get reportDuration => 'Duration';

  @override
  String reportReadingsInline(String count) {
    return '($count readings)';
  }

  @override
  String get reportRestVolts => 'Rest (V)';

  @override
  String get reportSag => 'Sag (V)';

  @override
  String get reportResistance => 'Resistance (mOhm)';

  @override
  String get reportRecovery => 'Recovery (s)';

  @override
  String get reportNotRecovered => 'did not return';

  @override
  String get reportCellTableNote =>
      'Sag is how far each cell dropped under the heavy load. Resistance is estimated from the current step, not measured with an instrument.';

  @override
  String get reportSectionReported => 'What the BMS says about itself';

  @override
  String get reportModel => 'Model';

  @override
  String get reportSerial => 'Serial number';

  @override
  String get reportSoftware => 'Firmware version';

  @override
  String get reportCycles => 'Counted cycles';

  @override
  String get reportReportedSoh => 'Reported health';

  @override
  String get reportReportedNote =>
      'These values can be edited from the official BMS app in under a minute. They are printed separately on purpose: they are a claim, not a measurement.';

  @override
  String get reportSectionCaveats => 'What this test could not see';

  @override
  String get reportSectionNote => 'Inspector\'s note';

  @override
  String get reportSectionCertificate => 'Certificate';

  @override
  String get reportCertificateCode => 'Certificate code';

  @override
  String get reportCertificateIssuer => 'Issuer (installation)';

  @override
  String get reportCertificateIssuedAt => 'Signed on';

  @override
  String get reportCertificateExplain =>
      'The signature proves these figures came out of the app that day and have not been changed since. It does not prove the battery is good or the seller honest. Scan the QR or paste the code into the app to check it.';

  @override
  String reportHonestyInspection(String date) {
    return 'Checked with a quick test on $date. Capacity is estimated, not measured: measuring it needs a full discharge. This test catches the bad cell and the obvious scam, and does not replace a workshop inspection.';
  }

  @override
  String get reportPackButton => 'PDF report';

  @override
  String get reportInspectionPdfButton => 'PDF report';

  @override
  String get reportCertificateButton => 'Signed certificate';

  @override
  String get reportBuilding => 'Building the PDF...';

  @override
  String get reportFailed => 'The PDF could not be created.';

  @override
  String get reportShareText => 'Report generated with JK BMS +';

  @override
  String get certificateVerifyTitle => 'Verify a certificate';

  @override
  String get certificateVerifyIntro =>
      'Paste the code that came with a certificate, or the text from its QR. The app checks the signature and shows exactly the figures that were signed.';

  @override
  String get certificateVerifyHint => 'JKC1....';

  @override
  String get certificateVerifyButton => 'Check';

  @override
  String get certificateVerifyOpen => 'Verify a certificate';

  @override
  String get certificateValid =>
      'Signature is good. These are the signed figures.';

  @override
  String get certificateBadSignature =>
      'The signature does not match: the contents were changed after signing.';

  @override
  String get certificateMalformed => 'That is not a valid certificate.';

  @override
  String certificateCreditsLeft(String count) {
    return 'Signing a certificate uses one credit. You have $count left.';
  }

  @override
  String get certificateCreditsGone =>
      'No certificate credits left. Get more under Licence.';

  @override
  String verdictInspRepeatSameCellTitle(
    String cell,
    String times,
    String runs,
  ) {
    return 'Cell $cell fails again: $times of $runs runs';
  }

  @override
  String get verdictInspRepeatSameCellBody =>
      'Not bad luck and not a loose lead: run the test again and the same cell drops before the others. This is no longer a suspicion, it is the cell.';

  @override
  String verdictInspRepeatCellMovedTitle(String cell) {
    return 'A different cell dropped this time';
  }

  @override
  String verdictInspRepeatCellMovedBody(String before, String cell) {
    return 'The previous run pointed at cell $before and this one points at cell $cell. When the finger moves between runs it almost always means the pack was not pulled the same way, not that two cells are bad. Run it again asking for the same throttle as last time.';
  }

  @override
  String get verdictInspRepeatWorseTitle => 'Worse than the previous run';

  @override
  String get verdictInspRepeatWorseBody =>
      'Compared at the same kind of pull, the pack measures worse than last time. With two runs separated in time that is a trend, not a snapshot.';

  @override
  String get verdictInspRepeatSteadyTitle => 'Same as last time';

  @override
  String get verdictInspRepeatSteadyBody =>
      'This run\'s figures land inside the noise of the previous one. The first test was not a fluke and this one found nothing new.';

  @override
  String get verdictInspRepeatCountersResetTitle =>
      'Somebody touched the counters between visits';

  @override
  String get verdictInspRepeatCountersResetBody =>
      'Cycles only go up and health only goes down. If between the two runs the cycles fell, the health rose or the configured capacity changed, the BMS was reset. The physical findings above cannot be reset with a button, which is why they are the ones to read.';

  @override
  String get verdictInspRepeatLoadDiffersTitle =>
      'The two runs did not pull alike';

  @override
  String get verdictInspRepeatLoadDiffersBody =>
      'Voltage sag depends on how much current is asked for. With very different pulls, comparing the sag says nothing. To compare properly, run it again with a similar pull.';

  @override
  String get evidenceRunCount => 'Runs on this pack';

  @override
  String evidenceTimesSameCell(String cell) {
    return 'Times cell $cell came out worst';
  }

  @override
  String evidencePreviousSag(String date) {
    return 'Sag on $date';
  }

  @override
  String evidencePreviousRestDelta(String date) {
    return 'Resting delta on $date';
  }

  @override
  String evidencePreviousResistance(String date) {
    return 'Median resistance on $date';
  }

  @override
  String evidencePreviousCycles(String date) {
    return 'Cycles per the BMS on $date';
  }

  @override
  String evidencePreviousSoh(String date) {
    return 'Health per the BMS on $date';
  }

  @override
  String evidencePreviousConfiguredCapacity(String date) {
    return 'Configured capacity on $date';
  }

  @override
  String evidencePreviousPeakCurrent(String date) {
    return 'Current step on $date';
  }

  @override
  String get inspectionSeriesTitle => 'Against the earlier runs';

  @override
  String get inspectionSeriesIntro =>
      'This pack has been inspected before. Repeating the test is what separates an odd reading from a real fault.';

  @override
  String inspectionSeriesRun(String number, String total) {
    return 'Run $number of $total on this pack';
  }

  @override
  String inspectionSeriesPrevious(String date) {
    return 'Run of $date';
  }

  @override
  String get inspectionSeriesFirstRun =>
      'First inspection of this pack. Run it again another day to confirm what you saw.';

  @override
  String get inspectionRepeatButton => 'Run the test again';

  @override
  String get inspectionRepeatHint =>
      'Repeat it as often as you like: every run is saved and the next one is compared against all of them.';

  @override
  String inspectionAlreadySeen(String count) {
    return 'Inspected $count time(s) already';
  }

  @override
  String get reportSectionSeries => 'Earlier runs on this pack';

  @override
  String get reportSeriesNote =>
      'Each row is an earlier inspection stored on the phone that signed this sheet. Repeating the test is what tells a bad cell from a bad reading.';

  @override
  String get reportSeriesWorstCell => 'Worst cell';

  @override
  String get profileTitle => 'Battery profile';

  @override
  String get profileIntro =>
      'Four things the BMS cannot know that change what the app can tell you. All of them can be left blank.';

  @override
  String get profileName => 'Name';

  @override
  String get profileSoldAs => 'Sold as';

  @override
  String get profileSoldAsHint => 'The capacity you were told';

  @override
  String get profileChemistry => 'Cell chemistry';

  @override
  String get profileChemistryWhy =>
      'Every safe range hangs off this. LFP at 4.2 V a cell is a fire; NMC at 3.6 V is a half-charged battery. If you do not know, leave it at \"Not sure\" and the app will not audit voltages.';

  @override
  String profileChemistryFromOvp(String chemistry, String value) {
    return 'The BMS is set to $value V a cell, which suggests $chemistry.';
  }

  @override
  String profileChemistryFromCell(String chemistry, String value) {
    return 'A cell has been seen at $value V, so it is not LFP: suggests $chemistry.';
  }

  @override
  String get profileAcquired => 'I have had it since';

  @override
  String get profileAcquiredUnknown => 'No date';

  @override
  String get profileAcquiredClear => 'Clear the date';

  @override
  String profileAgeYears(String years) {
    return '$years years with you';
  }

  @override
  String get profileCaptureBaseline => 'Keep today\'s state as day one';

  @override
  String get profileCaptureBaselineHint =>
      'Cells, resistances and the BMS configuration exactly as they are now. Everything the app later says about drift is measured against this. Best done with the pack at rest.';

  @override
  String get profileSave => 'Save';

  @override
  String get profileLater => 'Not now';

  @override
  String get profileEdit => 'Edit the profile';

  @override
  String get profileComplete => 'Complete the profile';

  @override
  String get profileBaseline => 'Day one';

  @override
  String get profileBaselineMissing => 'Not kept';

  @override
  String get profileNoBaselineIntro =>
      'Without a day one, \"the delta has opened up\" only means \"since the app started looking\". Keeping today\'s state gives everything else a starting point.';

  @override
  String profileSinceDayOne(String date) {
    return 'Since day one ($date)';
  }

  @override
  String get profileNotComparable =>
      'One of the two readings was taken with the pack pulling current, so the cells are not comparable. Look at this with the bike standing still.';

  @override
  String get profileDeltaThenNow => 'Spread between cells';

  @override
  String get profileWorstDrift => 'The one that moved most';

  @override
  String profileWorstDriftValue(String cell, String mv) {
    return 'Cell $cell, $mv mV';
  }

  @override
  String get profileCyclesSince => 'Cycles since then';

  @override
  String get profileConfigChanged => 'BMS configuration';

  @override
  String get profileConfigUnchanged => 'Same as day one';

  @override
  String profileConfigChangedCount(String count) {
    return '$count setting(s) changed';
  }

  @override
  String get chemistryLfp => 'LFP';

  @override
  String get chemistryNmc => 'NMC / Li-ion';

  @override
  String get chemistryUnknown => 'Not sure';

  @override
  String get configCellOvp => 'High-cell cutoff';

  @override
  String get configCellUvp => 'Low-cell cutoff';

  @override
  String get configBalanceStart => 'Balancing starts at';

  @override
  String get configSoc100 => 'Voltage called 100 %';

  @override
  String get configSoc0 => 'Voltage called 0 %';

  @override
  String get configMaxCharge => 'Maximum charge current';

  @override
  String get configMaxDischarge => 'Maximum discharge current';

  @override
  String get configMaxBalance => 'Balance current';

  @override
  String get configChargeOtp => 'Heat cutoff while charging';

  @override
  String get configDischargeOtp => 'Heat cutoff while discharging';

  @override
  String get configChargeUtp => 'Cold cutoff while charging';

  @override
  String get configMosfetOtp => 'MOSFET heat cutoff';

  @override
  String get configNominalCapacity => 'Configured capacity';

  @override
  String get configCellCount => 'Number of cells';

  @override
  String get configChargeSwitch => 'Charging enabled';

  @override
  String get configDischargeSwitch => 'Discharging enabled';

  @override
  String get configBalancerSwitch => 'Balancer';

  @override
  String get configOn => 'Yes';

  @override
  String get configOff => 'No';

  @override
  String get reportSectionDayOne => 'This battery\'s day one';

  @override
  String get reportDayOneNote =>
      'Compared against the state kept on the day the battery was taken on. Not a capacity measurement: a snapshot of the voltages cannot measure what a pack holds, and nothing here is presented as if it could.';

  @override
  String get verdictConfigOvpDangerousTitle =>
      'The charge cutoff is above what the cells can take';

  @override
  String verdictConfigOvpDangerousBody(String value, String limit) {
    return 'The BMS stops charging at $value V a cell and the safe maximum for this chemistry is $limit V. Every full charge is doing damage. Change it in the official BMS app, on your own responsibility; this app never writes anything to a battery.';
  }

  @override
  String get verdictConfigOvpHighTitle => 'The charge cutoff is high';

  @override
  String verdictConfigOvpHighBody(String value, String limit) {
    return 'You are cutting at $value V a cell when the pack is practically full at $limit V. What you gain in range is almost nothing and what you lose in cycle life is not.';
  }

  @override
  String get verdictConfigUvpDangerousTitle =>
      'The discharge cutoff goes below where cells recover';

  @override
  String verdictConfigUvpDangerousBody(String value, String limit) {
    return 'The BMS lets cells fall to $value V and the safe minimum is $limit V. A cell taken below that may not come back, and the ones that do come back smaller.';
  }

  @override
  String get verdictConfigUvpLowTitle => 'The discharge cutoff is low';

  @override
  String verdictConfigUvpLowBody(String value, String limit) {
    return 'You are cutting at $value V a cell. Below $limit V the cells are being squeezed for a few kilometres that cost more in life than they are worth.';
  }

  @override
  String get verdictConfigChargesWhenFrozenTitle =>
      'The BMS will charge the pack below freezing';

  @override
  String verdictConfigChargesWhenFrozenBody(String value) {
    return 'The cold cutoff is at $value °C. Charging lithium below zero plates metal inside the cell: it is permanent, it shows up on no figure the BMS reports, and it is the most common way a winter rider ruins a pack. Raise it to 2 °C or more in the official app.';
  }

  @override
  String get verdictConfigColdCutoffOkTitle =>
      'It will not charge a frozen pack';

  @override
  String verdictConfigColdCutoffOkBody(String value) {
    return 'The cold cutoff is at $value °C, so the BMS refuses to charge before the damage starts. It is one of the settings that saves the most life, and this one is set right.';
  }

  @override
  String get verdictConfigChargeHotLimitTitle =>
      'The heat cutoff while charging is high';

  @override
  String verdictConfigChargeHotLimitBody(String value, String limit) {
    return 'It allows charging up to $value °C, and above $limit °C charging ages cells faster than it should.';
  }

  @override
  String get verdictConfigDischargeHotLimitTitle =>
      'The heat cutoff while discharging is high';

  @override
  String verdictConfigDischargeHotLimitBody(String value, String limit) {
    return 'It allows pulling up to $value °C. Above $limit °C even discharging is not free.';
  }

  @override
  String get verdictConfigCapacityDisagreesTitle =>
      'The configured capacity is not what it was sold as';

  @override
  String verdictConfigCapacityDisagreesBody(String value, String sold) {
    return 'The BMS is configured for $value Ah and you recorded that it was sold as $sold Ah. The BMS figure was typed in by whoever assembled the pack: it measures nothing, but the charge percentage and the remaining amp-hours on every screen are derived from it.';
  }

  @override
  String get verdictConfigCellCountDisagreesTitle =>
      'The BMS is configured for a different number of cells';

  @override
  String verdictConfigCellCountDisagreesBody(String value, String seen) {
    return 'Configured for $value cells and $seen are being read. With this wrong, the pack voltage, the percentage and the protection cutoffs are all computed for a battery this is not.';
  }

  @override
  String get verdictConfigChargeCurrentHighTitle =>
      'The charge current is high for the size of the pack';

  @override
  String verdictConfigChargeCurrentHighBody(String value, String capacity) {
    return 'Up to $value A into a pack configured as $capacity Ah. It is allowed, but charging above 1C heats and ages; if you are not in a hurry, lowering it buys life.';
  }

  @override
  String get verdictConfigBalancerOffTitle => 'The balancer is switched off';

  @override
  String get verdictConfigBalancerOffBody =>
      'Without balancing the cells drift apart on their own, and the weakest one decides the end of every charge and every discharge. It is the first cause of packs that lose range with no cell actually being bad.';

  @override
  String get verdictConfigChargeOffTitle => 'Charging is disabled at the BMS';

  @override
  String get verdictConfigChargeOffBody =>
      'If the pack takes no charge, this explains it. It may be deliberate, or it may have been left this way after a protection tripped.';

  @override
  String get verdictConfigDischargeOffTitle =>
      'Discharging is disabled at the BMS';

  @override
  String get verdictConfigDischargeOffBody =>
      'If the bike will not move, this explains it. It may be deliberate, or it may have been left this way after a protection tripped.';

  @override
  String get verdictConfigBalanceStartLowTitle =>
      'Balancing starts where voltage says nothing';

  @override
  String verdictConfigBalanceStartLowBody(String value, String limit) {
    return 'It starts at $value V a cell, and for this chemistry it usually sits near $limit V. On the flat part of the curve a millivolt is not a measure of charge, so the balancer can move energy the wrong way.';
  }

  @override
  String get verdictConfigChangedSinceDayOneTitle =>
      'The configuration is not the one from day one';

  @override
  String verdictConfigChangedSinceDayOneBody(String count) {
    return '$count setting(s) have changed since the initial state was kept. If it was not you, somebody has been in the BMS.';
  }

  @override
  String get verdictConfigChemistryUnknownTitle =>
      'No declared chemistry, so no voltage audit';

  @override
  String get verdictConfigChemistryUnknownBody =>
      'LFP and NMC are almost a volt a cell apart: with the wrong one this screen would bless a dangerous setting or condemn a normal one. Say which it is in the battery profile and come back.';

  @override
  String get verdictConfigLooksSaneTitle => 'The configuration is reasonable';

  @override
  String get verdictConfigLooksSaneBody =>
      'The voltage cutoffs, the temperature cutoffs and the switches are where they should be for this chemistry. This says nothing about the state of the cells: it is a review of the settings, not of the battery.';

  @override
  String get evidenceConfiguredSetting => 'Configured';

  @override
  String get evidenceSafeLimit => 'Safe limit';

  @override
  String get evidenceCellsSeen => 'Cells being read';

  @override
  String get configAuditTitle => 'Configuration audit';

  @override
  String get configAuditIntro =>
      'What the BMS is set up to do, against what the cells you said it holds can take.';

  @override
  String get configAuditOpen => 'Audit the configuration';

  @override
  String get configAuditReadOnly =>
      'Read only. This app never writes to a BMS: a wrong value written to a battery is a fire, and the protocol\'s write path is reverse-engineered. Anything that needs changing is changed in the official BMS app, and that decision is yours.';

  @override
  String get configAuditSettings => 'Everything that was looked at';

  @override
  String get configAuditNoSettings =>
      'The BMS has not sent its configuration yet. Wait a few seconds with the battery connected.';

  @override
  String get configAuditChemistryRow => 'Declared chemistry';

  @override
  String get configAuditNeedsProfile => 'Complete the profile';

  @override
  String get alertNearCurrentLimit => 'Current close to the BMS limit';

  @override
  String get alertLinkLost => 'Lost the connection to the battery';

  @override
  String get alertsNotifyTitle => 'Alerts that arrive with the app closed';

  @override
  String get alertsNotifyIntro =>
      'Alerts land in the notification shade even when the app is in the background or closed. Without this, an alert at three in the morning with the phone in another room reaches nobody.';

  @override
  String get alertsNotifyEnable => 'Post alerts to the notification shade';

  @override
  String get alertsNotifyDenied =>
      'Android has not granted permission to notify. Alerts will still appear on screen and buzz, but they will not arrive with the app closed.';

  @override
  String get alertsNotifyOneConnection =>
      'Remember: the BMS accepts a single Bluetooth connection. While the phone is connected in the background the official JK app cannot connect, and the other way round.';

  @override
  String get alertsThresholdsTitle => 'When to speak up';

  @override
  String get alertsThresholdsIntro =>
      'The defaults are conservative. Raise them if your pack lives outside the usual range and it is warning you too often.';

  @override
  String get alertsDeltaWarn => 'Spread between cells';

  @override
  String get alertsTempWarn => 'Temperature';

  @override
  String get alertsLowChargeWarn => 'Low charge';

  @override
  String get alertsResetDefaults => 'Back to the defaults';

  @override
  String alertNotificationBodyDelta(String value) {
    return 'The cells have drifted $value V apart. The lowest one decides when the battery is finished.';
  }

  @override
  String alertNotificationBodyTemp(String value) {
    return '$value °C. Stop and let it cool before carrying on.';
  }

  @override
  String alertNotificationBodyLow(String value) {
    return '$value % charge left.';
  }

  @override
  String alertNotificationBodyCritical(String value) {
    return '$value % charge left. Find somewhere to stop.';
  }

  @override
  String alertNotificationBodyCell(String value) {
    return 'A cell is at $value V, close to the BMS cutoff. It can run out even while the percentage still looks reasonable.';
  }

  @override
  String get alertNotificationBodyFault =>
      'The BMS has raised a protection. Look at the screen before carrying on.';

  @override
  String alertNotificationBodyNearLimit(String value) {
    return '$value A, close to what the BMS allows. If it reaches the limit it cuts without warning.';
  }

  @override
  String get alertNotificationBodyLinkLost =>
      'The app stopped receiving readings from the battery. If you were watching a charge, nothing is watching it now.';

  @override
  String alertNotificationBodyChargeTarget(String value) {
    return 'The pack has reached the $value % you asked for.';
  }

  @override
  String get alertNotificationBodyChargeComplete => 'Charging has finished.';

  @override
  String alertNotificationBodyChargeHot(String value) {
    return '$value °C while charging. Unplug it and let it cool.';
  }

  @override
  String alertNotificationBodyChargeSpread(String value) {
    return 'The cells have drifted $value V apart at the top of the charge. That is where an imbalance shows up best.';
  }
}
