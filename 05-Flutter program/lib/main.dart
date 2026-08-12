import 'dart:async';

import 'package:flutter/material.dart';

import 'ble/walkeeg_ble.dart';
import 'protocol/packet_parser.dart';
import 'ui/waveform_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WalkEegApp());
}

class WalkEegApp extends StatelessWidget {
  const WalkEegApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WalkEEG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B7F6E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _sampleRateHz = 2000;

  /// Y-axis display: AC auto (monitor-style autoscale) or fixed unsigned
  /// ranges for 8/10/12/14/16-bit ADC modes.
  static const _yRanges = <(String, double)>[
    ('AC Auto', -1),
    ('8-bit · 0-255', 255),
    ('10-bit · 0-1023', 1023),
    ('12-bit · 0-4095', 4095),
    ('14-bit · 0-16383', 16383),
    ('16-bit · 0-65535', 65535),
  ];

  /// Oscilloscope-style time base: visible window.
  /// First row: seconds; second row: milliseconds (at 2 kHz).
  static const _windowsSec = <int>[1, 2, 5, 10];
  static const _windowsMs = <int>[500, 250, 100, 50];

  final _ble = WalkEegBleController();
  final Set<int> _selected = {0, 1};
  StreamSubscription<void>? _tickSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<BleLinkState>? _stateSub;
  String _status = 'Idle';
  BleLinkState _state = BleLinkState.idle;
  double _yMax = -1; // -1 = AC auto
  int _windowMs = 2000;
  FilterMode _mode = FilterMode.notchLp;

  /// Labels for the five processing schemes (kept short for the segmented
  /// control; full meaning in the status line).
  static const _modeLabels = <FilterMode, String>{
    FilterMode.raw: '原始',
    FilterMode.notchLp: '50Hz+LP',
    FilterMode.bandpass: '带通',
    FilterMode.qrs: 'QRS',
    FilterMode.hrv: 'HRV',
  };

  static const _colors = <Color>[
    Color(0xFF4ECDC4),
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6C63FF),
    Color(0xFF95E1A3),
    Color(0xFFFF8C42),
    Color(0xFF45B7D1),
    Color(0xFFE056FD),
  ];

  @override
  void initState() {
    super.initState();
    _tickSub = _ble.tickStream.listen((_) {
      if (mounted) setState(() {});
    });
    _statusSub = _ble.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _stateSub = _ble.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _statusSub?.cancel();
    _stateSub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  void _toggleChannel(int ch) {
    setState(() {
      if (_selected.contains(ch)) {
        if (_selected.length > 1) _selected.remove(ch);
      } else {
        if (_selected.length >= 4) {
          _selected.remove(_selected.first);
        }
        _selected.add(ch);
      }
    });
  }

  void _setMode(FilterMode m) {
    setState(() {
      _mode = m;
      _ble.parser.mode = m; // parser resets filter/QRS state on change
    });
  }

  @override
  Widget build(BuildContext context) {
    final parser = _ble.parser;
    final series = _selected.toList()..sort();
    final windowSamples = _windowMs * _sampleRateHz ~/ 1000;
    final plotData = series.map((ch) {
      final all = parser.channels[ch].samples;
      final start = all.length > windowSamples ? all.length - windowSamples : 0;
      return downsample(all.sublist(start), 800);
    }).toList();
    final plotColors = series.map((ch) => _colors[ch]).toList();
    final frames = parser.parsedFrames;
    final drops = parser.droppedFrames;
    final total = frames + drops;
    final lossPct = total == 0 ? 0.0 : drops * 100.0 / total;

    // QRS beat markers mapped into the visible window (fractions 0..1).
    final ch0All = parser.channels[0].samples;
    final ch0Start =
        ch0All.length > windowSamples ? ch0All.length - windowSamples : 0;
    final beatFracs = (_mode == FilterMode.qrs || _mode == FilterMode.hrv)
        ? parser.beatIndices
            .where((b) => b >= ch0Start && b < ch0All.length)
            .map((b) => (b - ch0Start) / windowSamples)
            .toList()
        : <double>[];

    // Heart rate / HRV readouts for the qrs/hrv modes.
    final bpm = parser.bpm;
    final sdnn = parser.sdnnMs;
    final rmssd = parser.rmssdMs;
    final metrics = StringBuffer();
    if (_mode == FilterMode.qrs || _mode == FilterMode.hrv) {
      metrics.write('HR ${bpm ?? "--"} bpm');
      if (_mode == FilterMode.hrv) {
        metrics.write(
            '   ·   SDNN ${sdnn?.toStringAsFixed(0) ?? "--"} ms   '
            'RMSSD ${rmssd?.toStringAsFixed(0) ?? "--"} ms');
      }
      metrics.write('   ·   beats ${parser.qrsBeatCount}');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('WalkEEG'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: _yMax,
              dropdownColor: const Color(0xFF16262C),
              iconEnabledColor: Colors.white70,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: [
                for (final (label, max) in _yRanges)
                  DropdownMenuItem(value: max, child: Text(label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _yMax = v);
              },
            ),
          ),
          IconButton(
            tooltip: 'Connect',
            onPressed: _state == BleLinkState.scanning ||
                    _state == BleLinkState.connecting
                ? null
                : () => _ble.startScanAndConnect(),
            icon: const Icon(Icons.bluetooth_searching),
          ),
          IconButton(
            tooltip: 'Disconnect',
            onPressed: () => _ble.disconnect(),
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'frames=$frames  seq=${parser.lastSeq ?? "-"}  '
              'drops=$drops  loss=${lossPct.toStringAsFixed(2)}%  '
              'N=${parser.lastNSamples ?? "-"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(8, (ch) {
                final on = _selected.contains(ch);
                return FilterChip(
                  label: Text('CH$ch'),
                  selected: on,
                  selectedColor: _colors[ch].withOpacity(0.35),
                  onSelected: (_) => _toggleChannel(ch),
                );
              }),
            ),
            const SizedBox(height: 8),
            if (metrics.isNotEmpty)
              Text(
                metrics.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF4ECDC4),
                      fontWeight: FontWeight.bold,
                    ),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: WaveformPainter(
                    series: plotData,
                    colors: plotColors,
                    yMin: 0,
                    yMax: _yMax < 0 ? 65535 : _yMax,
                    acMode: _yMax < 0,
                    beatFracs: beatFracs,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<FilterMode>(
              segments: [
                for (final m in FilterMode.values)
                  ButtonSegment(value: m, label: Text(_modeLabels[m]!)),
              ],
              selected: {_mode},
              onSelectionChanged: (sel) => _setMode(sel.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final s in _windowsSec)
                  ButtonSegment(
                    value: s * 1000,
                    label: Text('${s}s'),
                  ),
              ],
              selected: {_windowMs},
              onSelectionChanged: (sel) {
                setState(() => _windowMs = sel.first);
              },
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: [
                for (final ms in _windowsMs)
                  ButtonSegment(
                    value: ms,
                    label: Text('${ms}ms'),
                  ),
              ],
              selected: {_windowMs},
              onSelectionChanged: (sel) {
                setState(() => _windowMs = sel.first);
              },
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Y: ${_yMax < 0 ? "AC auto" : "0 … ${_yMax.round()}"}  ·  window '
              '${_windowMs >= 1000 ? "${_windowMs ~/ 1000}s" : "${_windowMs}ms"}  ·  '
              '8ch × 16-bit @ ${_sampleRateHz ~/ 1000}kHz  ·  '
              'mode:${_modeLabels[_mode]}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
