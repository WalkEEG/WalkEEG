import 'dart:typed_data';

import '../dsp/butterworth_lowpass.dart';
import '../dsp/butterworth_second_order.dart';
import '../dsp/mains_notch_filter.dart';
import '../dsp/qrs_detector.dart';

/// Signal processing scheme for channel 0 (real ECG).
///
///  - [raw]:      passthrough, no processing
///  - [notchLp]:  50 Hz mains notch + 100 Hz low-pass (band-limit)
///  - [bandpass]: standard ECG band-pass 0.5-100 Hz (AAMI EC57):
///                0.5 Hz baseline-drift high-pass + notch + low-pass
///  - [qrs]:      bandpass chain + Pan-Tompkins QRS detection + heart rate
///  - [hrv]:      qrs + HRV time-domain metrics (SDNN / RMSSD)
enum FilterMode { raw, notchLp, bandpass, qrs, hrv }

/// Per-channel rolling sample buffer for plotting.
class ChannelBuffer {
  ChannelBuffer({this.capacity = 20000});

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
  /// Buffer capacity = max display window (10 s at 2 kHz).
  WalkEegPacketParser({
    this.channelCapacity = 20000,
    FilterMode filterMode = FilterMode.notchLp,
    int sampleRate = 500,
  }) {
    channels = List.generate(
      8,
      (_) => ChannelBuffer(capacity: channelCapacity),
    );
    // One independent filter chain per channel so each channel can run its
    // own mode without sharing state.
    _chains = List.generate(
      numChannels,
      (_) => _ChannelChain(sampleRate: sampleRate),
    );
    _modes = List<FilterMode>.filled(numChannels, filterMode);
    _qrs = QrsDetector(sampleRate: sampleRate);
  }

  /// Per-channel processing scheme (see [FilterMode]).
  late final List<FilterMode> _modes;
  late final List<_ChannelChain> _chains;
  late QrsDetector _qrs;

  /// Processing mode for a single channel.
  FilterMode modeFor(int channel) =>
      (channel >= 0 && channel < numChannels) ? _modes[channel] : FilterMode.raw;

  /// Sets the processing mode for one channel, clearing that channel's filter
  /// state so the trace neither jumps nor false-triggers.
  void setModeFor(int channel, FilterMode v) {
    if (channel < 0 || channel >= numChannels) return;
    if (_modes[channel] == v) return;
    _modes[channel] = v;
    _chains[channel].reset();
    if (channel == 0) {
      _qrs.reset();
      _beatIndices.clear();
    }
  }

  /// Applies one mode to every channel.
  void setModeForAll(FilterMode v) {
    for (var ch = 0; ch < numChannels; ch++) {
      setModeFor(ch, v);
    }
  }

  /// Backwards-compatible single value: reads CH0, writes all channels.
  FilterMode get mode => _modes[0];
  set mode(FilterMode v) => setModeForAll(v);

  /// Sample indices (into [channels] buffer) of detected QRS beats, most
  /// recent first. Populated in [FilterMode.qrs] and [FilterMode.hrv].
  final List<int> _beatIndices = [];
  List<int> get beatIndices => List.unmodifiable(_beatIndices);

  /// Heart rate / HRV metrics from the QRS detector (qrs/hrv modes).
  int? get bpm => _qrs.bpm;
  double? get sdnnMs => _qrs.sdnnMs;
  double? get rmssdMs => _qrs.rmssdMs;
  int get qrsBeatCount => _qrs.beatCount;

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

  /// Optional hook for recording: called with raw per-channel samples each frame.
  void Function(int seq, List<List<int>> perChannel, int n)? onFrame;

  void reset() {
    _buf.clear();
    parsedFrames = 0;
    droppedFrames = 0;
    lastSeq = null;
    lastNSamples = null;
    for (final chain in _chains) {
      chain.reset();
    }
    _qrs.reset();
    _beatIndices.clear();
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
        // Raw unsigned 16-bit ADC value (8/10/12/14/16-bit modes).
        // Y-axis ranges are selected in the UI (0..2^N-1).
        final v = lo | (hi << 8);
        perCh[ch].add(v);
        off += 2;
      }
    }

    for (var ch = 0; ch < numChannels; ch++) {
      final m = _modes[ch];
      if (m == FilterMode.raw) {
        channels[ch].addAll(perCh[ch]);
      } else {
        // Filters are linear with unity DC gain, but output is stored
        // unsigned, so clamp defensively.
        final chain = _chains[ch].functionFor(m);
        channels[ch].addAll(perCh[ch].map((v) {
          final y = chain(v.toDouble());
          return y.round().clamp(0, 65535);
        }));
      }
    }

    // Raw samples for CSV recording / cloud Sync (before display filters).
    onFrame?.call(seq, perCh, n);

    // QRS detection runs on the RAW channel 0 (Pan-Tompkins band-passes
    // internally), parallel to the display chain.
    if (_modes[0] == FilterMode.qrs || _modes[0] == FilterMode.hrv) {
      final ch0 = perCh[0];
      for (final v in ch0) {
        if (_qrs.process(v.toDouble())) {
          // Beat position relative to the channel buffer: the sample just
          // appended is at index len-1 (used by the UI to draw markers).
          _beatIndices.insert(0, channels[0].samples.length - 1);
          if (_beatIndices.length > 64) _beatIndices.removeLast();
        }
      }
    }
  }

}

/// Independent filter state for one channel.
///
/// Chains containing the 0.5 Hz high-pass remove the DC baseline, so the
/// result is centred on 0 and would be clamped away by the unsigned
/// 0..65535 storage. Those chains re-centre on half full-scale (+32768) so
/// the AC waveform survives without clipping its negative half.
class _ChannelChain {
  _ChannelChain({required int sampleRate})
      : _notch = MainsNotchFilter(sampleRate: sampleRate),
        _lowpass = ButterworthLowPass(),
        _hp05 = ButterworthSecondOrder.highPass(
            sampleRate: sampleRate, cutoffHz: 0.5);

  final MainsNotchFilter _notch;
  final ButterworthLowPass _lowpass;
  final ButterworthSecondOrder _hp05;

  void reset() {
    _notch.reset();
    _lowpass.reset();
    _hp05.reset();
  }

  /// Builds the display chain for a mode: 0.5 Hz HP -> 50 Hz notch -> 100 Hz LP.
  double Function(double) functionFor(FilterMode m) {
    switch (m) {
      case FilterMode.raw:
        return (x) => x;
      case FilterMode.notchLp:
        return (x) => _lowpass.process(_notch.process(x));
      case FilterMode.bandpass:
      case FilterMode.qrs:
      case FilterMode.hrv:
        return (x) =>
            (_lowpass.process(_notch.process(_hp05.process(x)))) + 32768;
    }
  }
}
