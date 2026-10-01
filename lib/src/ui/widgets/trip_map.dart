import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/database.dart';
import '../theme.dart';

/// What the route's colour says.
enum TripMapColoring {
  /// GPS speed at each point.
  speed,

  /// What the pack was giving at each point: its voltage times its current,
  /// as the BMS reported them beside the fix. Power, not consumption per
  /// kilometre: per kilometre divides by a speed that is near zero at every
  /// stop and would paint every traffic light as the worst stretch of the
  /// ride.
  power,
}

/// The app's id, which OpenStreetMap's tile policy asks every client to send
/// so a misbehaving one can be told apart. From android/app/build.gradle.kts.
const String tripMapUserAgentPackage = 'dev.selector.jk_bms';

/// OpenStreetMap's own tile server. Its usage policy asks for the attribution
/// shown on the map and a real user agent, and allows light, interactive use
/// like one rider looking at one ride.
const String tripMapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// The colours the route is drawn in, slowest (or least power) first.
const List<Color> tripMapPalette = [
  AppTheme.cool,
  AppTheme.good,
  AppTheme.watch,
  AppTheme.bad,
];

/// The points worth drawing: on the planet, and not the 0,0 a fix with no
/// position would leave behind.
List<TripPoint> drawablePoints(List<TripPoint> points) => [
  for (final p in points)
    if (p.latitude.abs() <= 90 &&
        p.longitude.abs() <= 180 &&
        !(p.latitude == 0 && p.longitude == 0) &&
        p.latitude.isFinite &&
        p.longitude.isFinite)
      p,
];

/// The value [coloring] reads from one point. Power is watts out of the
/// pack, so discharge reads positive whatever sign the brand reports in:
/// readings are stored with discharge negative.
double tripMapValue(TripPoint p, TripMapColoring coloring) =>
    switch (coloring) {
      TripMapColoring.speed => p.speedKmh,
      TripMapColoring.power => math.max(0, -p.current * p.packVoltage),
    };

/// Which palette entry a value falls in, between [lo] and [hi]. A flat ride
/// (every value the same) is drawn in the first colour rather than divided
/// by zero.
int tripMapBin(double value, double lo, double hi) {
  if (hi <= lo) return 0;
  final f = ((value - lo) / (hi - lo)).clamp(0.0, 1.0);
  return math.min(
    tripMapPalette.length - 1,
    (f * tripMapPalette.length).floor(),
  );
}

/// The route as runs of one colour: each run a polyline, touching the next
/// at their shared point so the line has no gaps. One polyline per segment
/// would be a thousand polylines for a long ride.
List<({List<LatLng> points, int bin})> tripMapRuns(
  List<TripPoint> points,
  TripMapColoring coloring,
) {
  if (points.length < 2) return const [];
  final values = [for (final p in points) tripMapValue(p, coloring)];
  final lo = values.reduce(math.min);
  final hi = values.reduce(math.max);
  final runs = <({List<LatLng> points, int bin})>[];
  var current = <LatLng>[LatLng(points[0].latitude, points[0].longitude)];
  var bin = tripMapBin(values[1], lo, hi);
  for (var i = 1; i < points.length; i++) {
    final b = tripMapBin(values[i], lo, hi);
    final here = LatLng(points[i].latitude, points[i].longitude);
    if (b != bin && current.length >= 2) {
      runs.add((points: current, bin: bin));
      current = [current.last];
      bin = b;
    }
    current.add(here);
  }
  runs.add((points: current, bin: bin));
  return runs;
}

/// A ride's track on a map, coloured by speed or by power, with where it
/// started and where it ended.
///
/// The tiles come from OpenStreetMap over the network. With no network the
/// route still draws, on a blank background: the track is the ride's own
/// data, and the map underneath is only there to place it.
class TripMap extends StatefulWidget {
  const TripMap({
    required this.points,
    this.showTiles = true,
    this.height = 260,
    super.key,
  });

  final List<TripPoint> points;

  /// Off in tests, which have no network to fetch tiles from.
  final bool showTiles;
  final double height;

  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> {
  TripMapColoring _coloring = TripMapColoring.speed;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final points = drawablePoints(widget.points);
    if (points.length < 2) return const SizedBox.shrink();

    final runs = tripMapRuns(points, _coloring);
    final values = [for (final p in points) tripMapValue(p, _coloring)];
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final start = LatLng(points.first.latitude, points.first.longitude);
    final end = LatLng(points.last.latitude, points.last.longitude);
    final unit = _coloring == TripMapColoring.speed ? 'km/h' : 'W';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: widget.height,
            child: FlutterMap(
              options: MapOptions(
                backgroundColor: AppTheme.surfaceHigh,
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints([
                    for (final p in points) LatLng(p.latitude, p.longitude),
                  ]),
                  padding: const EdgeInsets.all(28),
                  // A ride that went nowhere has bounds of no size, which
                  // would otherwise zoom in without limit.
                  maxZoom: 17,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                if (widget.showTiles)
                  TileLayer(
                    urlTemplate: tripMapTileUrl,
                    userAgentPackageName: tripMapUserAgentPackage,
                  ),
                PolylineLayer(
                  polylines: [
                    for (final r in runs)
                      Polyline(
                        points: r.points,
                        color: tripMapPalette[r.bin],
                        strokeWidth: 4,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: start,
                      width: 26,
                      height: 26,
                      child: _Pin(
                        icon: Icons.play_arrow_rounded,
                        color: AppTheme.good,
                        label: t.tripMapStart,
                      ),
                    ),
                    Marker(
                      point: end,
                      width: 26,
                      height: 26,
                      child: _Pin(
                        icon: Icons.flag_rounded,
                        color: AppTheme.textPrimary,
                        label: t.tripMapEnd,
                      ),
                    ),
                  ],
                ),
                // Always on screen, not behind a button: OpenStreetMap's
                // licence asks for the credit to be visible on the map.
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                  backgroundColor: Color(0xCC080A0F),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // A wrap, so the scale drops under the chips on a narrow phone
        // instead of overflowing.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in TripMapColoring.values)
              ChoiceChip(
                label: Text(
                  c == TripMapColoring.speed
                      ? t.tripMapBySpeed
                      : t.tripMapByPower,
                ),
                selected: _coloring == c,
                onSelected: (_) => setState(() => _coloring = c),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${lo.toStringAsFixed(0)} $unit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textFaint,
                  ),
                ),
                const SizedBox(width: 4),
                for (final c in tripMapPalette)
                  Container(width: 10, height: 6, color: c),
                const SizedBox(width: 4),
                Text(
                  '${hi.toStringAsFixed(0)} $unit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_coloring == TripMapColoring.power)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t.tripMapPowerHint,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.textFaint,
              ),
            ),
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.ink,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 15, color: color),
    ),
  );
}
