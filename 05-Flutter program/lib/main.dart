import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/cognito_auth.dart';
import 'ble/walkeeg_ble.dart';
import 'dsp/eeg_analyzer.dart';
import 'dsp/emg_analyzer.dart';
import 'protocol/packet_parser.dart';
import 'relay/relay_service.dart';
import 'storage/recording_service.dart';
import 'storage/sync_service.dart';
import 'ui/eeg_page.dart';
import 'ui/emg_page.dart';
import 'ui/login_page.dart';
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
      title: 'WALKEEG',
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
  int _sampleRateHz = 2000;

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
  /// Display window options, 250 ms .. 2 s.
  static const _windowOptionsMs = <int>[250, 500, 1000, 2000];

  final _ble = WalkEegBleController();
  final _recording = RecordingService();
  final _relay = RelayService();
  EegAnalyzer _eeg = EegAnalyzer(sampleRate: 2000);
  EmgAnalyzer _emg = EmgAnalyzer(sampleRate: 2000);
  final _sync = SyncService();
  final _auth = CognitoAuth();
  final Set<int> _selected = {0, 1};
  StreamSubscription<void>? _tickSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<BleLinkState>? _stateSub;
  String _status = 'Idle';
  BleLinkState _state = BleLinkState.idle;
  double _yMax = -1; // -1 = AC auto
  int _windowMs = 2000;
  FilterMode _mode = FilterMode.raw;
  /// Per-channel processing modes, mirrored into the parser.
  final Map<int, FilterMode> _chModes = {for (var i = 0; i < 8; i++) i: FilterMode.raw};
  CognitoSession? _session;
  String _syncStatus = '';
  bool _syncing = false;
  int _pendingCount = 0;

  /// Labels for the five processing schemes (kept short for the segmented
  /// control; full meaning in the status line).
  static const _modeLabels = <FilterMode, String>{
    FilterMode.raw: 'Raw',
    FilterMode.notchLp: '50Hz+LP',
    FilterMode.bandpass: 'Bandpass',
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
    _ble.parser.setSampleRate(_sampleRateHz);
    _ble.parser.onFrame = (seq, perCh, n) {
      _recording.onFrame(perCh, n);
      // relay: CH0 uses the displayed value of the current filter mode (matching the app screen); raw CH0 is kept on CH7
      final disp = _ble.parser.channels[0].samples;
      final filtered = disp.length >= n ? disp.sublist(disp.length - n) : disp;
      final relayCh = List<List<int>>.generate(8, (c) {
        if (c == 0) return filtered;
        if (c == 7) return perCh[0];
        return perCh[c];
      });
      _relay.onFrame(seq, relayCh, n);
      _eeg.addSamples(perCh[0], n);
      _emg.addSamples(perCh[0], n);
    };
    _relay.addListener(_onRelayChanged);
    _tickSub = _ble.tickStream.listen((_) {
      if (mounted) setState(() {});
    });
    _statusSub = _ble.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _stateSub = _ble.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _restoreSession();
    _refreshPending();
  }

  Future<void> _restoreSession() async {
    final session = await _auth.loadSession();
    if (mounted) setState(() => _session = session);
  }

  Future<void> _refreshPending() async {
    final pending = await _sync.loadPendingSessions();
    if (mounted) {
      setState(() => _pendingCount = pending.where((s) => !s.synced).length);
    }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onLoggedIn: (session) {
            setState(() => _session = session);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.logout();
    setState(() => _session = null);
  }

  void _onRelayChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openRelay() async {
    final hostCtl = TextEditingController(text: _relay.host);
    final portCtl = TextEditingController(text: '${_relay.port}');
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Relay to local server'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hostCtl,
                decoration: const InputDecoration(labelText: 'Host / IP'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: portCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port'),
              ),
              const SizedBox(height: 12),
              Text('Status: ${_relay.status}',
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                setD(() => _relay.status = 'discovering…');
                final found = await RelayService.discover();
                if (found != null) {
                  hostCtl.text = found.host;
                  portCtl.text = '${found.port}';
                  setD(() => _relay.status = 'found ${found.host}:${found.port}');
                } else {
                  setD(() => _relay.status = 'not found (check same Wi-Fi / server is running)');
                }
              },
              child: const Text('Discover'),
            ),
            TextButton(
              onPressed: () async {
                await _relay.disconnect();
                setD(() {});
              },
              child: const Text('Disconnect'),
            ),
            FilledButton(
              onPressed: () async {
                await _relay.connect(
                  host: hostCtl.text.trim(),
                  port: int.tryParse(portCtl.text.trim()) ?? 8787,
                );
                setD(() {});
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
    hostCtl.dispose();
    portCtl.dispose();
  }

  Future<void> _setRate(int hz) async {
    setState(() {
      _sampleRateHz = hz;
      _eeg = EegAnalyzer(sampleRate: hz);
      _emg = EmgAnalyzer(sampleRate: hz);
      _ble.parser.setSampleRate(hz);
    });
    await _ble.sendCommand('SET_RATE $hz\n');
    _relay.setSampleRate(hz);
  }

  Future<void> _toggleRecording() async {
    if (_recording.isRecording) {
      final session = await _recording.stopAndReturnSession();
      if (session != null) {
        await _sync.savePendingSession(session);
      }
      await _refreshPending();
      if (mounted && session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${session.segments.length} segment(s)')),
        );
      }
      if (mounted) setState(() {});
    } else {
      final name = 'session_${DateTime.now().millisecondsSinceEpoch}';
      await _recording.start(name);
      if (mounted) setState(() {});
    }
  }

  Future<void> _syncPending() async {
    if (_session == null) {
      await _openLogin();
      if (_session == null) return;
    }
    setState(() {
      _syncing = true;
      _syncStatus = 'Starting...';
    });
    try {
      final fresh = await _auth.ensureFreshSession(_session!);
      if (mounted) setState(() => _session = fresh);
      final results = await _sync.syncAllPending(
        fresh,
        onStatus: (s) {
          if (mounted) setState(() => _syncStatus = s);
        },
      );
      await _refreshPending();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(results.isEmpty ? 'Nothing to sync' : results.join('\n')),
          ),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        final expired = msg.contains('Token expired') ||
            msg.contains('Invalid login token') ||
            msg.contains('NotAuthorizedException') ||
            msg.contains('Session expired');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              expired
                  ? 'Login expired. Please sign in again, then Sync.'
                  : 'Sync failed: $e',
            ),
          ),
        );
        if (expired) {
          await _logout();
          await _openLogin();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _syncStatus = '';
        });
      }
    }
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _statusSub?.cancel();
    _stateSub?.cancel();
    _relay.removeListener(_onRelayChanged);
    _relay.dispose();
    _eeg.dispose();
    _emg.dispose();
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

  /// Sets the processing mode for one channel, or for every channel when
  /// [channel] is null.
  /// Compact summary of active per-channel filters, e.g. "CH0:QRS CH1:50Hz+LP".
  String _modeSummary() {
    final parts = <String>[];
    for (final ch in _selected.toList()..sort()) {
      final m = _chModes[ch] ?? FilterMode.raw;
      parts.add('CH$ch:${_modeLabels[m]}');
    }
    return parts.join('  ');
  }

  void _setMode(FilterMode m, {int? channel}) {
    setState(() {
      if (channel == null) {
        _mode = m;
        for (var ch = 0; ch < 8; ch++) {
          _chModes[ch] = m;
        }
        _ble.parser.setModeForAll(m);
      } else {
        _chModes[channel] = m;
        if (channel == 0) _mode = m;
        _ble.parser.setModeFor(channel, m);
      }
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
        title: const Text('WALKEEG'),
        actions: [
          IconButton(
            tooltip: _relay.connected
                ? 'Relay connected'
                : 'Relay to local server',
            onPressed: _openRelay,
            icon: Icon(_relay.connected
                ? Icons.wifi_tethering
                : Icons.wifi_tethering_off),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'account') {
                if (_session == null) {
                  _openLogin();
                } else {
                  _logout();
                }
                return;
              }
              if (v.startsWith('y:')) {
                final max = double.tryParse(v.substring(2));
                if (max != null) setState(() => _yMax = max);
                return;
              }
              if (v.startsWith('rate:')) {
                final hz = int.tryParse(v.substring(5));
                if (hz != null) _setRate(hz);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'account',
                child: Text(_session == null ? 'Sign in' : 'Sign out'),
              ),
              const PopupMenuDivider(),
              for (final (label, max) in _yRanges)
                PopupMenuItem(
                  value: 'y:$max',
                  child: Row(
                    children: [
                      if (_yMax == max)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              for (final hz in const [500, 1000, 2000, 4000])
                PopupMenuItem(
                  value: 'rate:$hz',
                  child: Row(
                    children: [
                      if (_sampleRateHz == hz)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text('$hz Hz'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: (_state == BleLinkState.connected ||
                    _state == BleLinkState.streaming)
                ? 'Disconnect'
                : 'Connect',
            onPressed: _state == BleLinkState.scanning ||
                    _state == BleLinkState.connecting
                ? null
                : () {
                    if (_state == BleLinkState.connected ||
                        _state == BleLinkState.streaming) {
                      _ble.disconnect();
                    } else {
                      _ble.startScanAndConnect();
                    }
                  },
            icon: Icon((_state == BleLinkState.connected ||
                    _state == BleLinkState.streaming)
                ? Icons.link_off
                : Icons.bluetooth_searching),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$_status  ·  ${_sampleRateHz}Hz  ·  relay=${_relay.status}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'frames=$frames  seq=${parser.lastSeq ?? "-"}  '
              'drops=$drops  loss=${lossPct.toStringAsFixed(2)}%  '
              'N=${parser.lastNSamples ?? "-"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EegPage(analyzer: _eeg),
                        ),
                      );
                    },
                    icon: const Icon(Icons.insights),
                    label: const Text('EEG alpha/beta'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmgPage(
                            analyzer: _emg,
                            sampleRate: _sampleRateHz,
                            onRateChanged: _setRate,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.show_chart),
                    label: const Text('EMG envelope'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(_recording.isRecording
                        ? Icons.stop
                        : Icons.fiber_manual_record),
                    label: Text(_recording.isRecording
                        ? 'Stop recording'
                        : 'Start recording'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _recording.isRecording ? Colors.red.shade700 : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed:
                        _syncing || _pendingCount == 0 ? null : _syncPending,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text('Sync ($_pendingCount)'),
                  ),
                ),
              ],
            ),
            if (_syncStatus.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_syncStatus, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            // Per-channel filter rows. PopupMenuButton is used instead of
            // DropdownButton: a DropdownButton whose entry is removed mid-route
            // triggers an inherited-widget assertion (_dependents.isEmpty).
            Column(
              key: const ValueKey('ch-filter-rows'),
              children: [
                for (final ch in _selected.toList()..sort())
                  Padding(
                    key: ValueKey('ch-row-$ch'),
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text('CH$ch'),
                          selected: true,
                          selectedColor: _colors[ch].withValues(alpha: 0.35),
                          onSelected: (_) => _toggleChannel(ch),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: PopupMenuButton<FilterMode>(
                              initialValue: _chModes[ch] ?? FilterMode.raw,
                              onSelected: (m) => _setMode(m, channel: ch),
                              itemBuilder: (ctx) => [
                                for (final m in FilterMode.values)
                                  PopupMenuItem<FilterMode>(
                                    value: m,
                                    child: Text(_modeLabels[m]!),
                                  ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: _colors[ch]
                                      .withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _modeLabels[_chModes[ch] ??
                                          FilterMode.raw]!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  children: List.generate(8, (ch) {
                    final on = _selected.contains(ch);
                    if (on) return const SizedBox.shrink();
                    return ActionChip(
                      label: Text('CH$ch', style: const TextStyle(fontSize: 12)),
                      onPressed: () => _toggleChannel(ch),
                    );
                  }),
                ),
              ],
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
            // Global shortcut: apply one mode to every channel at once.
            Row(
              children: [
                Text('All channels:',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                PopupMenuButton<FilterMode>(
                  initialValue: _mode,
                  onSelected: _setMode,
                  itemBuilder: (ctx) => [
                    for (final m in FilterMode.values)
                      PopupMenuItem<FilterMode>(
                        value: m,
                        child: Text(_modeLabels[m]!),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_modeLabels[_mode]!,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final ms in _windowOptionsMs)
                  ButtonSegment(
                    value: ms,
                    label: Text(ms >= 1000 ? '${ms ~/ 1000}s' : '${ms}ms'),
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
              '8ch × 16-bit @ ${_sampleRateHz}Hz  ·  '
              '${_modeSummary()}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
