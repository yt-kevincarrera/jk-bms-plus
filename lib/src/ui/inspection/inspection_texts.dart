import '../../../l10n/app_localizations.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_verdicts.dart';

/// The words the inspection screens, the printed sheet and the certificate
/// checker share.
///
/// One copy, because three copies of a sentence about what a test measured
/// is how one of them ends up claiming more than the other two.

/// The headline for a light.
///
/// "No verdict" comes in two forms, and they are different statements: a
/// test that never got a load, and one that got a load too small to rule out
/// the fault it looks for.
String inspectionHeadline(
  AppL10n t,
  InspectionLight light,
  InspectionResult r, {
  InspectionVerdicts verdicts = const InspectionVerdicts(),
}) => switch (light) {
  InspectionLight.good => t.inspectionLightGood,
  InspectionLight.watch => t.inspectionLightWatch,
  InspectionLight.problem => t.inspectionLightProblem,
  InspectionLight.unmeasured =>
    verdicts.loadTooSmall(r)
        ? t.inspectionLightUnresolved
        : t.inspectionLightUnmeasured,
};

/// The paragraph under a "no verdict" headline.
String inspectionUnmeasuredText(
  AppL10n t,
  InspectionResult r, {
  InspectionVerdicts verdicts = const InspectionVerdicts(),
}) => verdicts.loadTooSmall(r)
    ? t.inspectionUnresolvedBody
    : t.inspectionUnmeasuredBody;

/// What a quick test can and cannot see, said about this test.
///
/// It used to say "catches the bad cell" under every result, including a
/// test that never loaded the pack. Now it says what this run could have
/// caught, at the current it actually pulled, or that it could not look.
String inspectionFidelityText(
  AppL10n t,
  InspectionLight light,
  InspectionResult r, {
  InspectionVerdicts verdicts = const InspectionVerdicts(),
}) {
  final floor = r.detectionFloorOhms(verdicts.thresholds.sagResolutionVolts);
  if (light == InspectionLight.unmeasured || floor == null) {
    return t.inspectionFidelityNoteUnmeasured;
  }
  final shown = floor > verdicts.thresholds.sagWatchOhms
      ? floor
      : verdicts.thresholds.sagWatchOhms;
  return t.inspectionFidelityNote((shown * 1000).toStringAsFixed(1));
}

String inspectionCaveatText(AppL10n t, InspectionCaveat c) => switch (c) {
  InspectionCaveat.noHeavyLoad => t.inspectionCaveatNoHeavyLoad,
  InspectionCaveat.noLightLoad => t.inspectionCaveatNoLightLoad,
  InspectionCaveat.restNoisy => t.inspectionCaveatRestNoisy,
  InspectionCaveat.noRecovery => t.inspectionCaveatNoRecovery,
  InspectionCaveat.recoveryNoLoad => t.inspectionCaveatRecoveryNoLoad,
  InspectionCaveat.endedBeforeLoad => t.inspectionCaveatEndedBeforeLoad,
  InspectionCaveat.endedBeforeRecovery => t.inspectionCaveatEndedBeforeRecovery,
  InspectionCaveat.recoveryLinkGap => t.inspectionCaveatRecoveryLinkGap,
  InspectionCaveat.linkGaps => t.inspectionCaveatLinkGaps,
  InspectionCaveat.currentStepTooSmall => t.inspectionCaveatStepTooSmall,
  InspectionCaveat.fewReadings => t.inspectionCaveatFewReadings,
  InspectionCaveat.heavyWasCharge => t.inspectionCaveatHeavyWasCharge,
};
