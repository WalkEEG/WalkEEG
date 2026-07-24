import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_walkeeg/protocol/packet_parser.dart';

Uint8List buildFrame({
  required int seq,
  required int nSamples,
  required List<int> firstSampleCh,
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
      final value = firstSampleCh[ch] + t;
      frame[off] = value & 0xFF;
      frame[off + 1] = (value >> 8) & 0xFF;
      off += 2;
    }
  }
  return frame;
}

void main() {
  test('parses valid frame into 8 channels', () {
    final parser = WalkEegPacketParser();
    parser.feed(buildFrame(seq: 1, nSamples: 2, firstSampleCh: [100, 101, 102, 103, 104, 105, 106, 107]));

    expect(parser.parsedFrames, 1);
    expect(parser.lastSeq, 1);
    expect(parser.channels[0].samples, [100, 101]);
    expect(parser.channels[7].samples, [107, 108]);
  });

  test('detects dropped frames via seq gap', () {
    final parser = WalkEegPacketParser();
    parser.feed(buildFrame(seq: 1, nSamples: 1, firstSampleCh: List.filled(8, 0)));
    parser.feed(buildFrame(seq: 3, nSamples: 1, firstSampleCh: List.filled(8, 0)));

    expect(parser.droppedFrames, 1);
  });

  test('resyncs after garbage prefix', () {
    final parser = WalkEegPacketParser();
    final garbage = Uint8List.fromList([0x00, 0x11, 0x22]);
    final frame = buildFrame(seq: 5, nSamples: 1, firstSampleCh: List.filled(8, 42));

    parser.feed(garbage);
    parser.feed(frame);

    expect(parser.parsedFrames, 1);
    expect(parser.lastSeq, 5);
    expect(parser.channels[0].samples.last, 42);
  });
}
