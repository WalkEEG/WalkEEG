import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dsp/emg_analyzer.dart';

class EmgPage extends StatelessWidget {
  const EmgPage({
    super.key,
    required this.analyzer,
    required this.sampleRate,
    required this.onRateChanged,
  });

  final EmgAnalyzer analyzer;
  final int sampleRate;
  final ValueChanged<int> onRateChanged;

  Future<void> _copyCsv(BuildContext context) async {
    final rows = <String>['time,envelope,activation,rms,artifact'];
    for (final s in analyzer.history) {
      rows.add([
        s.at.toIso8601String(),
        s.envelope.toStringAsFixed(2),
        s.activation.toStringAsFixed(3),
        s.rms.toStringAsFixed(2),
        s.artifact ? '1' : '0',
      ].join(','));
    }
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${analyzer.history.length} rows')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMG envelope'),
        actions: [
          IconButton(
            tooltip: 'Copy CSV',
            onPressed: () => _copyCsv(context),
            icon: const Icon(Icons.copy_all),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: analyzer.clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: analyzer,
        builder: (context, _) {
          final s = analyzer.latest;
          final env = s?.envelope ?? 0;
          final act = s?.activation ?? 0;
          final rms = s?.rms ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Text('Sample rate'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: sampleRate,
                    items: const [
                      DropdownMenuItem(value: 500, child: Text('500 Hz')),
                      DropdownMenuItem(value: 1000, child: Text('1000 Hz')),
                      DropdownMenuItem(value: 2000, child: Text('2000 Hz')),
                      DropdownMenuItem(value: 4000, child: Text('4000 Hz')),
                    ],
                    onChanged: (v) {
                      if (v != null) onRateChanged(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s == null
                    ? 'Waiting for CH0 samples…'
                    : (s.artifact
                        ? 'Artifact — hold still / check electrodes'
                        : 'Signal OK · 20–450 Hz · 5 Hz envelope'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text('Activation ${(act * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: act,
                minHeight: 14,
                backgroundColor: Colors.white12,
                color: const Color(0xFF22C55E),
              ),
              const SizedBox(height: 20),
              _MetricRow(label: 'Envelope', value: env.toStringAsFixed(1)),
              _MetricRow(label: 'RMS', value: rms.toStringAsFixed(1)),
              _MetricRow(label: 'Sample rate', value: '$sampleRate Hz'),
              const SizedBox(height: 20),
              const Text(
                'Electrodes: biceps, reference and RLD. Start with 2 kSPS; '
                'use 4 kSPS only if the front-end filter supports it.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}
