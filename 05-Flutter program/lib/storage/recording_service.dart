import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../protocol/packet_parser.dart';

/// One recording session split into CSV segments for incremental upload.
class RecordingSegment {
  RecordingSegment({
    required this.path,
    required this.partIndex,
    required this.sampleCount,
    required this.uploaded,
  });

  final String path;
  final int partIndex;
  int sampleCount;
  bool uploaded;

  Map<String, dynamic> toJson() => {
        'path': path,
        'partIndex': partIndex,
        'sampleCount': sampleCount,
        'uploaded': uploaded,
      };

  factory RecordingSegment.fromJson(Map<String, dynamic> json) => RecordingSegment(
        path: json['path'] as String,
        partIndex: _asInt(json['partIndex']),
        sampleCount: _asInt(json['sampleCount']),
        uploaded: json['uploaded'] as bool? ?? false,
      );
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.parse(value);
  throw FormatException('Expected int, got $value (${value.runtimeType})');
}

class RecordingSession {
  RecordingSession({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.segments,
    this.synced = false,
  });

  final String id;
  final String name;
  final DateTime startedAt;
  final List<RecordingSegment> segments;
  bool synced;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'synced': synced,
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  factory RecordingSession.fromJson(Map<String, dynamic> json) =>
      RecordingSession(
        id: json['id'] as String,
        name: json['name'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        synced: json['synced'] as bool? ?? false,
        segments: (json['segments'] as List)
            .map((e) => RecordingSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Writes BLE frames to segmented CSV files.
class RecordingService {
  RecordingService({
    this.sampleRateHz = 2000,
    this.samplesPerSegment = 60000, // ~30 s at 2 kHz
  });

  static const csvHeader =
      'Time(s),Ch1(uV),Ch2(uV),Ch3(uV),Ch4(uV),Ch5(uV),Ch6(uV),Ch7(uV),Ch8(uV)\n';

  final int sampleRateHz;
  final int samplesPerSegment;

  RecordingSession? _session;
  IOSink? _sink;
  int _globalSampleIndex = 0;
  int _segmentSampleCount = 0;
  int _partIndex = 0;
  String? _sessionDir;

  bool get isRecording => _session != null;

  RecordingSession? get session => _session;

  Future<RecordingSession> start(String name) async {
    if (_session != null) await stopAndReturnSession();

    final base = await getApplicationDocumentsDirectory();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionDir = '${base.path}/recordings/$id';
    await Directory(_sessionDir!).create(recursive: true);

    _session = RecordingSession(
      id: id,
      name: name,
      startedAt: DateTime.now(),
      segments: [],
    );
    _globalSampleIndex = 0;
    _segmentSampleCount = 0;
    _partIndex = 1;
    await _openSegment();
    return _session!;
  }

  Future<RecordingSession?> stopAndReturnSession() async {
    if (_session == null) return null;
    final finished = _session!;
    await _closeSegment();
    _session = null;
    _sessionDir = null;
    return finished;
  }

  void onFrame(List<List<int>> perChannel, int n) {
    if (_session == null || _sink == null) return;

    for (var t = 0; t < n; t++) {
      final time = (_globalSampleIndex / sampleRateHz).toStringAsFixed(6);
      final row = StringBuffer(time);
      for (var ch = 0; ch < WalkEegPacketParser.numChannels; ch++) {
        row.write(',${perChannel[ch][t]}');
      }
      _sink!.writeln(row.toString());
      _globalSampleIndex++;
      _segmentSampleCount++;

      if (_segmentSampleCount >= samplesPerSegment) {
        unawaited(_rotateSegment());
      }
    }
  }

  Future<void> _rotateSegment() async {
    await _closeSegment();
    _partIndex++;
    _segmentSampleCount = 0;
    await _openSegment();
  }

  Future<void> _openSegment() async {
    final fileName =
        '${_session!.startedAt.toIso8601String().substring(0, 10)}_${_sanitize(_session!.name)}_part${_partIndex.toString().padLeft(4, '0')}.csv';
    final path = '$_sessionDir/$fileName';
    final file = File(path);
    _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    _sink!.write(csvHeader);
    _session!.segments.add(RecordingSegment(
      path: path,
      partIndex: _partIndex,
      sampleCount: 0,
      uploaded: false,
    ));
  }

  Future<void> _closeSegment() async {
    if (_sink != null) {
      await _sink!.flush();
      await _sink!.close();
      _sink = null;
    }
    if (_session != null && _session!.segments.isNotEmpty) {
      _session!.segments.last.sampleCount = _segmentSampleCount;
    }
  }

  String _sanitize(String name) {
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (clean.isEmpty) return 'recording';
    return clean.length > 40 ? clean.substring(0, 40) : clean;
  }

  Future<Uint8List> readSegmentBytes(String path) async {
    return File(path).readAsBytes();
  }

  String segmentFileName(RecordingSegment seg) =>
      seg.path.split(Platform.pathSeparator).last;
}
