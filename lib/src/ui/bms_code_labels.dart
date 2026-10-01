import '../../l10n/app_localizations.dart';

/// The charge phase a JK02_32S reports at byte 248, in the rider's language.
///
/// The table is the reference implementation's (0 bulk, 1 absorption, 2
/// float). A code past it is shown as the code: a phase this app cannot name
/// is still something the BMS said, and guessing a name for it would not be.
String chargeStatusLabel(AppL10n t, int code) => switch (code) {
  0 => t.chargeStatusBulk,
  1 => t.chargeStatusAbsorption,
  2 => t.chargeStatusFloat,
  _ => t.bmsUnknownCode('$code'),
};

/// The battery type a JK02_32S is configured for, from byte 243 (0 LFP,
/// 1 Li-ion, 2 LTO). It is the BMS's setting, not a reading of the cells.
String batteryTypeLabel(AppL10n t, int code) => switch (code) {
  0 => t.batteryTypeLfp,
  1 => t.batteryTypeLiIon,
  2 => t.batteryTypeLto,
  _ => t.bmsUnknownCode('$code'),
};
