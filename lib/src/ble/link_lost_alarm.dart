/// Whether a link that has gone down is worth waking somebody for.
///
/// Its own unit so the rule can be tested without a radio, because what it
/// replaced was not a rule. "The link went down" was posted on every
/// connected-to-not-connected transition, immediately, gated only on
/// `chargeWatchEnabled || linkWatchEnabled` — and `linkWatchEnabled` is on by
/// default and means something else entirely: it is the foreground service
/// that keeps readings arriving with the screen off, not a request to be
/// interrupted.
///
/// So in practice it fired for everybody, every time, at once.
///
/// What that costs, measured on a real ride: 26 gaps in 21 minutes, the
/// largest 169 seconds, every one of them closed by the app on its own. Each
/// one re-posted a high-importance notification in the alarm category to a
/// phone in a jacket pocket. The rider's word for it was "extremadamente
/// molesta".
///
/// The notification is still worth having — a charge left overnight in the
/// garage, and the app stopped looking four hours ago, is the case it was
/// written for. That case is quiet, stationary and long. So this asks for all
/// three: the link has been down continuously for [graceBefore], nothing is
/// being ridden, and this outage has not already been reported.
class LinkLostAlarm {
  const LinkLostAlarm({this.graceBefore = const Duration(minutes: 2)});

  /// How long the link has to stay down before it counts as lost rather than
  /// as the ordinary flapping of a pack under a seat.
  ///
  /// Comfortably past the worst gap that ride recovered from on its own, so a
  /// link that is merely struggling never reaches this.
  final Duration graceBefore;

  /// [downSince] is when the link went down, or null while it is up.
  ///
  /// [riding] is whether a trip is being recorded. Riding is exactly when the
  /// link flaps and exactly when nobody can act on being told so.
  ///
  /// [alreadyWarned] keeps one outage to one notification.
  bool shouldWarn({
    required DateTime? downSince,
    required DateTime now,
    required bool riding,
    required bool alreadyWarned,
  }) {
    if (downSince == null || riding || alreadyWarned) return false;
    return now.difference(downSince) >= graceBefore;
  }
}
