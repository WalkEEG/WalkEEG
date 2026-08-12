import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_walkeeg/protocol/packet_parser.dart';

Uint8List buildFrame({
  required int seq,
  required int nSamples,
  required List<int> firstSampleCh,
  bool constant = false,
}) {
  final payloadLen = nSamples * 8 * 2;
  final frame = Uint8List(6 + payloadLen);
  frame[0] = 0xA5;
  frame[1] = 0x01;
  frame[2] = seq & 0xFF;
  frame[3] = (seq >> 8) & 0xFF;
  frame[4] = nSamples;
  frame[5] = 0;

  var off = 6;
  for (var t = 0; t < nSamples; t++) {
    for (var ch = 0; ch < 8; ch++) {
      final value = constant ? firstSampleCh[ch] : firstSampleCh[ch] + t;
      frame[off] = value & 0xFF;
      frame[off + 1] = (value >> 8) & 0xFF;
      off += 2;
    }
  }
  return frame;
}

void main() {
  test('parses valid frame into 8 channels (raw, filter off)', () {
    final parser = WalkEegPacketParser(filterMode: FilterMode.raw);
    parser.feed(buildFrame(seq: 1, nSamples: 2, firstSampleCh: [100, 101, 102, 103, 104, 105, 106, 107]));

    expect(parser.parsedFrames, 1);
    expect(parser.lastSeq, 1);
    expect(parser.channels[0].samples, [100, 101]);
    expect(parser.channels[7].samples, [107, 108]);
  });

  test('filtered CH0 reaches steady state (transients settle)', () {
    final parser = WalkEegPacketParser(filterMode: FilterMode.notchLp);
    // Feed ~1 s of constant samples (67 frames x 30 samples, matching the
    // firmware's max frame size): the Q=20 notch has a long time constant
    // (r=0.996) so it takes ~1 s to fully settle. Check the tail matches the
    // input (both filters have unity DC gain).
    for (var i = 0; i < 67; i++) {
      parser.feed(buildFrame(
          seq: i + 1,
          nSamples: 30,
          firstSampleCh: List.filled(8, 1000),
          constant: true));
    }

    final ch0 = parser.channels[0].samples;
    expect(ch0.length, 2010);
    for (final v in ch0.skip(1900)) {
      expect((v - 1000).abs(), lessThanOrEqualTo(1),
          reason: 'CH0 steady state should track DC input 1000, got $v');
    }
  });

  test('detects dropped frames via seq gap', () {
    final parser = WalkEegPacketParser();
    parser.feed(buildFrame(seq: 1, nSamples: 1, firstSampleCh: List.filled(8, 0)));
    parser.feed(buildFrame(seq: 3, nSamples: 1, firstSampleCh: List.filled(8, 0)));

    expect(parser.droppedFrames, 1);
  });

  test('bandpass chain re-centers on half scale (DC removed, no 0-clip)', () {
    final parser = WalkEegPacketParser(filterMode: FilterMode.bandpass);
    // 8 s: the 0.5 Hz high-pass has a ~3 s settle time (slow poles), so feed
    // enough constant data for the steady state to be reached.
    for (var i = 0; i < 534; i++) {
      parser.feed(buildFrame(
          seq: i + 1,
          nSamples: 30,
          firstSampleCh: List.filled(8, 1000),
          constant: true));
    }
    final ch0 = parser.channels[0].samples;
    expect(ch0.length, 16020);
    // DC input -> high-pass kills it -> +32768 re-centering. Steady tail
    // should sit at ~32768, NOT clipped at 0.
    for (final v in ch0.skip(15000)) {
      expect((v - 32768).abs(), lessThanOrEqualTo(2),
          reason: 'steady value should center on 32768, got $v');
    }
  });

  test('resyncs after garbage prefix', () {
    final parser = WalkEegPacketParser(filterMode: FilterMode.raw);
    final garbage = Uint8List.fromList([0x00, 0x11, 0x22]);
    final frame = buildFrame(seq: 5, nSamples: 1, firstSampleCh: List.filled(8, 42));

    parser.feed(garbage);
    parser.feed(frame);

    expect(parser.parsedFrames, 1);
    expect(parser.lastSeq, 5);
    expect(parser.channels[0].samples.last, 42);
  });
}
