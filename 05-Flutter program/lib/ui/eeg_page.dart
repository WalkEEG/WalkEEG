import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dsp/eeg_analyzer.dart';

class EegPage extends StatefulWidget {
  const EegPage({super.key, required this.analyzer});

  final EegAnalyzer analyzer;

  @override
  State<EegPage> createState() => _EegPageState();
}

class _EegPageState extends State<EegPage> {
  Timer? _timer;
  int _secondsLeft = 0;
  String _phase = '';
  double? _closedAlpha;
  double? _openAlpha;
  final List<double> _values = <double>[];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startBaseline(String phase, int seconds) {
    if (_timer != null) return;
    setState(() {
      _phase = phase;
      _secondsLeft = seconds;
      _values.clear();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final s = widget.analyzer.latest;
      if (s != null && !s.artifact) _values.add(s.alpha);
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _timer = null;
        final avg = _values.isEmpty
            ? 0.0
            : _values.reduce((a, b) => a + b) / _values.length;
        setState(() {
          if (phase == 'closed') {
            _closedAlpha = avg;
          } else {
            _openAlpha = avg;
          }
          _phase = '';
          _secondsLeft = 0;
        });
      }
    });
  }

  double? get _reactivity {
    final c = _closedAlpha;
    final o = _openAlpha;
    if (c == null || o == null || o <= 0) return null;
    return c / o;
  }

  void _resetBaseline() {
    setState(() {
      _closedAlpha = null;
      _openAlpha = null;
      _values.clear();
      _phase = '';
      _secondsLeft = 0;
    });
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _copyCsv() async {
    final rows = <String>['time,theta,alpha,beta,ratio,artifact'];
    for (final s in widget.analyzer.history) {
      rows.add([
        s.at.toIso8601String(),
        s.theta.toStringAsFixed(3),
        s.alpha.toStringAsFixed(3),
        s.beta.toStringAsFixed(3),
        s.ratio.toStringAsFixed(3),
        s.artifact ? '1' : '0',
      ].join(','));
    }
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${widget.analyzer.history.length} rows')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EEG alpha/beta'),
        actions: [
          IconButton(
            tooltip: 'Copy CSV',
            onPressed: _copyCsv,
            icon: const Icon(Icons.copy_all),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: widget.analyzer.clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.analyzer,
        builder: (context, _) {
          final s = widget.analyzer.latest;
          final alpha = s?.alpha ?? 0;
          final beta = s?.beta ?? 0;
          final theta = s?.theta ?? 0;
          var maxVal = alpha;
          if (beta > maxVal) maxVal = beta;
          if (theta > maxVal) maxVal = theta;
          if (maxVal <= 0) maxVal = 1;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                s == null
                    ? 'Waiting for CH0 samples…'
                    : (s.artifact
                        ? 'Artifact — hold still / check electrodes'
                        : 'Signal OK · 500 Hz · 2 s window'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _BandBar(
                label: 'Alpha 8–13 Hz',
                value: alpha,
                max: maxVal,
                color: const Color(0xFF22C55E),
              ),
              const SizedBox(height: 10),
              _BandBar(
                label: 'Beta 13–30 Hz',
                value: beta,
                max: maxVal,
                color: const Color(0xFF06B6D4),
              ),
              const SizedBox(height: 10),
              _BandBar(
                label: 'Theta 4–8 Hz',
                value: theta,
                max: maxVal,
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 14),
              Text(
                'Beta/Alpha: ${s == null ? "--" : s.ratio.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Alpha baseline',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'O1/O2 + mastoid reference. Eyes closed should raise alpha.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      if (_timer != null)
                        Text(
                          '$_phase: ${_secondsLeft}s left',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _timer != null
                                  ? null
                                  : () => _startBaseline('Eyes closed', 60),
                              child: const Text('Eyes closed 60 s'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _timer != null
                                  ? null
                                  : () => _startBaseline('Eyes open', 60),
                              child: const Text('Eyes open 60 s'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Text('Closed α: ${_fmt(_closedAlpha)}'),
                          Text('Open α: ${_fmt(_openAlpha)}'),
                          Text('Reactivity: ${_fmt(_reactivity)}×'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetBaseline,
                          child: const Text('Reset baseline'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(double? v) => v == null ? '--' : v.toStringAsFixed(2);
}

class _BandBar extends StatelessWidget {
  const _BandBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value.toStringAsFixed(2),
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          minHeight: 8,
          backgroundColor: Colors.white12,
          color: color,
        ),
      ],
    );
  }
}
