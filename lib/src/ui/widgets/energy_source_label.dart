import '../../../l10n/app_localizations.dart';
import '../../metrics/trip_recorder.dart';

/// How a stored ride's energy was arrived at, in words, or null for a ride
/// from before that was written down.
///
/// The row has always known, and nothing showed it: a figure the BMS counted
/// across the whole ride and one put together from the few readings that
/// arrived looked identical on screen, though one is a measurement and the
/// other a floor.
String? energySourceLabel(AppL10n t, String? source) =>
    switch (EnergySource.values.asNameMap()[source]) {
      EnergySource.coulombCount => t.tripEnergySourceBms,
      EnergySource.integrated => t.tripEnergySourceIntegrated,
      EnergySource.bracketedCoulombCount => t.tripEnergySourceBracketed,
      EnergySource.partialCoulombCount => t.tripEnergySourcePartial,
      EnergySource.unmeasurable ||
      EnergySource.unmeasurableBracketed => t.tripEnergySourceUnmeasurable,
      null => null,
    };
