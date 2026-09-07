import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bms_service.dart';
import '../data/database.dart';
import 'license_scope.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/representative_question.dart';
import 'widgets/trip_card.dart';

/// Which stored rides the free tier may list, and how many are behind the cut.
///
/// Its own thing, and tested, because reading a pack offline must not become a
/// way around what the free tier shows: every row is still stored and the
/// estimate still learns from all of them, only the list is cut. Get the count
/// wrong and the locked row lies about how much history is there, which is the
/// one number a rider would use to decide whether the licence is worth buying.
class RideWindow {
  const RideWindow({
    required this.shown,
    required this.hidden,
    required this.cutoff,
  });

  /// How many rides fall inside the window.
  final int shown;

  /// How many are older than it.
  final int hidden;

  /// The moment a ride has to be after to be listed, or null for no cut.
  ///
  /// Handed back rather than kept private so the list is filtered by the same
  /// instant the counts were made from. Taking the first [shown] of the rows
  /// would give the same answer only while they arrive newest first, which is
  /// a fact about a query somewhere else.
  final DateTime? cutoff;

  /// True for a ride that may be listed.
  bool allows(DateTime startedAt) =>
      cutoff == null || startedAt.isAfter(cutoff!);

  /// [startedAt] is every ride's start, in UTC. [window] null means no cut.
  ///
  /// A ride exactly on the boundary falls outside, so the window is never
  /// quoted as being longer than it is.
  static RideWindow apply({
    required List<DateTime> startedAt,
    required Duration? window,
    required DateTime now,
  }) {
    if (window == null) {
      return RideWindow(
        shown: startedAt.length,
        hidden: 0,
        cutoff: null,
      );
    }
    final cutoff = now.subtract(window);
    final shown = startedAt.where((t) => t.isAfter(cutoff)).length;
    return RideWindow(
      shown: shown,
      hidden: startedAt.length - shown,
      cutoff: cutoff,
    );
  }
}

/// Every stored ride of one pack, with no radio involved.
///
/// A screen of its own rather than a tail on the offline pack screen. It used
/// to hang off the bottom of that one, outside the sections, growing without
/// limit: a pack with two hundred rides made the summary above it something
/// you scrolled past rather than read. The summary is now a fixed length and
/// the rides have somewhere with room to grow.
///
/// Reading them back has never needed a Bluetooth link. Until the offline
/// screen existed the only way to look at one was to connect, which meant a
/// pack that was sold, lent out or simply not to hand had a history nobody
/// could open.
class PackTripsScreen extends StatefulWidget {
  const PackTripsScreen({
    required this.service,
    required this.device,
    required this.learned,
    required this.onChanged,
    super.key,
  });

  final BmsService service;
  final Device device;

  /// This pack's figures, not the connected pack's. With nothing connected the
  /// service's estimator belongs to no pack at all, and quoting it would put a
  /// number in front of the rider that describes nothing they are looking at.
  final LearnedRange Function() learned;

  /// Tells the screen underneath that a ride was deleted or called an
  /// exception, so its totals and its estimate are rebuilt too.
  final Future<void> Function() onChanged;

  @override
  State<PackTripsScreen> createState() => _PackTripsScreenState();
}

class _PackTripsScreenState extends State<PackTripsScreen> {
  bool _loading = true;
  List<Trip> _rides = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final repo = widget.service.repository;
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final trips = await repo.db.recentTrips(widget.device.id, limit: 500);
    if (!mounted) return;
    setState(() {
      // A ride row exists from the moment recording starts, so one in progress
      // has no distance yet. The same cut the totals on the pack screen use.
      _rides = trips.where((tr) => tr.distanceKm > 0).toList();
      _loading = false;
    });
  }

  /// A ride was deleted or reclassified. Both lists have to follow it.
  Future<void> _rideChanged() async {
    await widget.onChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final repo = widget.service.repository;
    final window = LicenseScope.entitlements(context).historyWindow;
    final cut = RideWindow.apply(
      startedAt: [for (final r in _rides) r.startedAt],
      window: window,
      now: DateTime.now().toUtc(),
    );
    final shown = _rides.where((r) => cut.allows(r.startedAt)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.device.name)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : repo == null || _rides.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    t.offlineNoTrips,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(top: 6, bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                    child: Caption(t.historyTrips),
                  ),
                  for (final trip in shown)
                    TripCard(
                      trip: trip,
                      service: widget.service,
                      repository: repo,
                      learned: widget.learned,
                      // Nothing relearns on its own here, because relearning
                      // is scoped to the connected pack. Reloading is what
                      // rebuilds the estimate after a ride is deleted or
                      // called an exception.
                      onChanged: _rideChanged,
                      t: t,
                    ),
                  if (cut.hidden > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: OlderRidesLocked(count: cut.hidden),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      t.tripSwipeHint,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
