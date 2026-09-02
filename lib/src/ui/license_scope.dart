import 'package:flutter/widgets.dart';

import '../license/entitlements.dart';
import '../license/license_controller.dart';

/// Hands the one [LicenseController] down to every screen.
///
/// An inherited notifier rather than a constructor parameter threaded through
/// six tabs and four screens: a gate can appear on any screen, and every one
/// of them asking the same question should get the same answer from the same
/// place. Rebuilds its dependants when a key is activated or a trial ends.
class LicenseScope extends InheritedNotifier<LicenseController> {
  const LicenseScope({
    required LicenseController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LicenseController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LicenseScope>();
    assert(scope != null, 'No LicenseScope above this widget');
    return scope!.notifier!;
  }

  /// What this phone may do, right now. Registers a dependency, so the
  /// caller rebuilds when that changes.
  static Entitlements entitlements(BuildContext context) =>
      of(context).entitlements;

  /// One question, asked the way a screen asks it.
  static bool allows(BuildContext context, Feature feature) =>
      entitlements(context).allows(feature);
}
