import 'dart:typed_data';

/// Per-channel rolling sample buffer for plotting.
class ChannelBuffer {
  ChannelBuffer({this.capacity = 4000});

  final int capacity;
  final List<int> samples = <int>[];

  void addAll(Iterable<int> values) {
    samples.addAll(values);
    if (samples.length > capacity) {
      samples.removeRange(0, samples.length - capacity);
    }
  }

  void clear() => samples.clear();
}

/// Parses WalkEEG NUS binary frames (see docs/WALKEEG_PACKET.md).
class WalkEegPacketParser {
  WalkEegPacketParser({this.channelCapacity = 4000}) {
    channels = List.generate(
      8,
      (_) => ChannelBuffer(capacity: channelCapacity),
    );
  }

  static const int magic = 0xA5;
  static const int version = 0x01;
  static const int headerLen = 6;
  static const int numChannels = 8;

  final int channelCapacity;
  late final List<ChannelBuffer> channels;

  final BytesBuilder _buf = BytesBuilder(copy: false);

  int parsedFrames = 0;
  int droppedFrames = 0;
  int? lastSeq;
  int? lastNSamples;

  void reset() {
    _buf.clear();
    parsedFrames = 0;
    droppedFrames = 0;
    lastSeq = null;
    lastNSamples = null;
    for (final ch in channels) {
      ch.clear();
    }
  }

  void feed(Uint8List chunk) {
    if (chunk.isEmpty) return;
    _buf.add(chunk);
    _drain();
  }

  void _drain() {
    var data = _buf.takeBytes();
    var offset = 0;

    while (true) {
      // Find magic
      while (offset < data.length && data[offset] != magic) {
        offset++;
      }
      if (offset >= data.length) {
        _buf.clear();
        return;
      }

      final remaining = data.length - offset;
      if (remaining < headerLen) {
        _buf.add(Uint8List.sublistView(data, offset));
        return;
      }

      final ver = data[offset + 1];
      final n = data[offset + 4];
      final frameLen = headerLen + n * numChannels * 2;

      if (n == 0 || frameLen > 6 + 30 * 16) {
        // Invalid; skip this magic byte and resync
        offset++;
        continue;
      }

      if (remaining < frameLen) {
        _buf.add(Uint8List.sublistView(data, offset));
        return;
      }

      if (ver != version) {
        offset++;
        continue;
      }

      final frame = Uint8List.sublistView(data, offset, offset + frameLen);
      _parseFrame(frame);
      offset += frameLen;
    }
  }

  void _parseFrame(Uint8List frame) {
    final seq = frame[2] | (frame[3] << 8);
    final n = frame[4];
    lastNSamples = n;

    if (lastSeq != null) {
      final expected = (lastSeq! + 1) & 0xFFFF;
      if (seq != expected) {
        final gap = (seq - expected) & 0xFFFF;
        droppedFrames += gap;
      }
    }
    lastSeq = seq;
    parsedFrames++;

    var off = headerLen;
    final perCh = List.generate(numChannels, (_) => <int>[]);

    for (var t = 0; t < n; t++) {
      for (var ch = 0; ch < numChannels; ch++) {
        final lo = frame[off];
        final hi = frame[off + 1];
        // WalkEEG test signal is non-negative ramp; treat as unsigned-ish int16
        var v = lo | (hi << 8);
        if (v > 32767) {
          v -= 65536; // signed
        }
        perCh[ch].add(v);
        off += 2;
      }
    }

    for (var ch = 0; ch < numChannels; ch++) {
      channels[ch].addAll(perCh[ch]);
    }
  }
}
