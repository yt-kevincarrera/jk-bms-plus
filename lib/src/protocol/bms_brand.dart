/// Which maker's protocol a pack speaks.
///
/// Both brands use the same GATT service and characteristic (FFE0/FFE1), so
/// nothing at the radio level tells them apart; the advertised name, the
/// rider's own answer and the bytes that arrive are what do.
enum BmsBrand {
  jk('jk'),
  ant('ant');

  const BmsBrand(this.stored);

  /// How it is written to the database and to backups.
  final String stored;

  /// Rows written before the app knew about a second brand have no value, and
  /// every one of them is a JK.
  static BmsBrand fromStored(String? s) =>
      s == ant.stored ? ant : jk;
}

final RegExp _antName = RegExp(r'^ANT[-@]', caseSensitive: false);

/// A hint from the advertised name, or null when it says nothing.
///
/// ANT modules advertise `ANT-BLE16ZMUB` or, on 2024+ boards, `ANT@BLE22AAUB`.
/// Anchored at the start so a pack a rider named "GIANT" is not taken for one.
BmsBrand? brandFromName(String name) {
  if (_antName.hasMatch(name)) return BmsBrand.ant;
  if (name.toUpperCase().contains('JK')) return BmsBrand.jk;
  return null;
}
