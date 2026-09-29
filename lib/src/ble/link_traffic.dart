import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

/// Which way a chunk of bytes went.
enum TrafficDirection {
  /// A notification payload the pack sent.
  rx,

  /// A frame the app wrote to the pack.
  tx,
}

/// One chunk of bytes, exactly as it crossed the link.
class TrafficEntry {
  TrafficEntry(this.at, this.direction, this.bytes);

  final DateTime at;
  final TrafficDirection direction;
  final Uint8List bytes;

  /// The bytes as hex pairs separated by spaces, the way a protocol document
  /// or a sniffer prints them, so a line can be compared against one by eye.
  String get hex => hexPairs(bytes);

  static String hexPairs(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

/// The last few hundred chunks the link carried, both ways, across connects.
///
/// Exists because the console was meant to show what went wrong when a pack
/// does not connect, and it could only show what the app had already made of
/// the bytes: decoded frames and the notices the connect screen shows anyway.
/// A pack that sends bytes nothing decodes, or that is asked the wrong
/// question, left nothing to look at. This keeps the bytes themselves, and
/// what the app wrote, so they can be read after the attempt has failed.
///
/// In memory only, and never cleared on disconnect: the point is to read it
/// after a failed attempt, which ends with a disconnect. Bounded by entries
/// and by bytes, so a pack streaming large notifications cannot grow it past
/// a known size. At two or three 300-byte frames a second in two 244-byte
/// notifications each, 400 entries is roughly a minute of a healthy stream.
class LinkTrafficLog {
  LinkTrafficLog({
    this.maxEntries = 400,
    this.maxBytes = 96 * 1024,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxEntries;
  final int maxBytes;
  final DateTime Function() _clock;

  final ListQueue<TrafficEntry> _entries = ListQueue();
  int _bytes = 0;

  final _controller = StreamController<TrafficEntry>.broadcast();

  /// Oldest first.
  List<TrafficEntry> get entries => List.unmodifiable(_entries);

  /// Bytes currently held, for a test to confirm the bound.
  int get heldBytes => _bytes;

  /// Every entry as it is added.
  Stream<TrafficEntry> get stream => _controller.stream;

  void add(TrafficDirection direction, List<int> bytes) {
    if (bytes.isEmpty) return;
    final entry = TrafficEntry(
      _clock(),
      direction,
      Uint8List.fromList(bytes),
    );
    _entries.addLast(entry);
    _bytes += entry.bytes.length;
    while (_entries.length > maxEntries ||
        (_bytes > maxBytes && _entries.length > 1)) {
      _bytes -= _entries.removeFirst().bytes.length;
    }
    if (!_controller.isClosed) _controller.add(entry);
  }

  Future<void> dispose() => _controller.close();
}
