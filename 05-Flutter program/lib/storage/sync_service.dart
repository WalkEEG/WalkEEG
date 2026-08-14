import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/walkeeg_api.dart';
import '../auth/cognito_auth.dart';
import 'recording_service.dart';
import 's3_uploader.dart';

/// Uploads unsynced recording segments to S3 and registers metadata via API.
class SyncService {
  SyncService({
    CognitoAuth? auth,
    S3Uploader? uploader,
  })  : _auth = auth ?? CognitoAuth(),
        _uploader = uploader ?? S3Uploader();

  static const _kSessions = 'walkeeg_pending_sessions';

  final CognitoAuth _auth;
  final S3Uploader _uploader;

  Future<void> savePendingSession(RecordingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadPendingSessions();
    list.removeWhere((s) => s.id == session.id);
    list.add(session);
    await prefs.setString(
      _kSessions,
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );
  }

  Future<List<RecordingSession>> loadPendingSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessions);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => RecordingSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markSegmentUploaded(
    String sessionId,
    int partIndex,
  ) async {
    final list = await loadPendingSessions();
    final session = list.firstWhere((s) => s.id == sessionId);
    for (final seg in session.segments) {
      if (seg.partIndex == partIndex) seg.uploaded = true;
    }
    // Do not set session.synced here — wait until POST /signals succeeds.
    await savePendingSession(session);
  }

  /// Rebuild segment metadata from local paths when S3 upload succeeded but API failed.
  Future<List<Map<String, dynamic>>> _buildSegmentMetadata(
    RecordingSession session,
    CognitoSession cognitoSession,
    RecordingService recording,
  ) async {
    final segments = <Map<String, dynamic>>[];
    for (final seg in session.segments.where((s) => s.uploaded)) {
      final fileName = recording.segmentFileName(seg);
      final s3Key = '${cognitoSession.identityId}/signals/$fileName';
      var fileSize = 0;
      try {
        fileSize = (await recording.readSegmentBytes(seg.path)).length;
      } catch (_) {
        // Local file missing — still register with reconstructed S3 key.
      }
      segments.add({
        'partIndex': seg.partIndex,
        's3Key': s3Key,
        'fileName': fileName,
        'fileSize': fileSize,
        'sampleCount': seg.sampleCount,
      });
    }
  return segments;
  }

  Future<void> _registerMetadata(
    WalkeegApi api,
    RecordingSession session,
    CognitoSession cognitoSession,
    List<Map<String, dynamic>> segmentsForApi,
    RecordingService recording,
  ) async {
    final primaryKey = segmentsForApi.first['s3Key'] as String;
    var totalBytes = 0;
    for (final seg in segmentsForApi) {
      totalBytes += seg['fileSize'] as int? ?? 0;
    }
    if (totalBytes == 0) {
      for (final seg in session.segments) {
        try {
          totalBytes += (await recording.readSegmentBytes(seg.path)).length;
        } catch (_) {}
      }
    }
    final durationSec =
        session.segments.fold<int>(0, (a, s) => a + s.sampleCount) /
            recording.sampleRateHz;

    await api.createSignal({
      'name': session.name,
      'description': 'Mobile recording ${session.segments.length} segment(s)',
      's3Key': primaryKey,
      'identityId': cognitoSession.identityId,
      'fileName': segmentsForApi.first['fileName'],
      'fileSize': totalBytes,
      'channels': '8',
      'sampleRate': '2000 Hz',
      'duration': '${durationSec.toStringAsFixed(1)}s',
      'status': 'uploaded',
      'segments': segmentsForApi,
    });
  }

  /// Sync one session: upload pending segments, then POST /signals metadata.
  Future<String> syncSession(
    RecordingSession session,
    CognitoSession cognitoSession, {
    void Function(String status)? onStatus,
  }) async {
    cognitoSession = await _auth.ensureFreshSession(cognitoSession);
    final api = WalkeegApi(cognitoSession);
    final creds = await _auth.getCredentials(cognitoSession);
    final recording = RecordingService();

    final uploadedThisRound = <Map<String, dynamic>>[];

    for (final seg in session.segments) {
      if (seg.uploaded) continue;
      onStatus?.call('Uploading part ${seg.partIndex}…');

      final bytes = await recording.readSegmentBytes(seg.path);
      final fileName = recording.segmentFileName(seg);
      final s3Key = '${cognitoSession.identityId}/signals/$fileName';

      await _uploader.uploadBytes(
        credentials: creds,
        key: s3Key,
        bytes: bytes,
      );

      seg.uploaded = true;
      uploadedThisRound.add({
        'partIndex': seg.partIndex,
        's3Key': s3Key,
        'fileName': fileName,
        'fileSize': bytes.length,
        'sampleCount': seg.sampleCount,
      });
      await markSegmentUploaded(session.id, seg.partIndex);
    }

    List<Map<String, dynamic>> segmentsForApi;
    if (uploadedThisRound.isNotEmpty) {
      segmentsForApi = uploadedThisRound;
      onStatus?.call('Registering metadata…');
    } else if (!session.synced &&
        session.segments.isNotEmpty &&
        session.segments.every((s) => s.uploaded)) {
      segmentsForApi = await _buildSegmentMetadata(
        session,
        cognitoSession,
        recording,
      );
      if (segmentsForApi.isEmpty) return 'Nothing to sync';
      onStatus?.call('Re-registering metadata…');
    } else if (session.synced) {
      return 'Already synced';
    } else {
      return 'Nothing to sync';
    }

    await _registerMetadata(
      api,
      session,
      cognitoSession,
      segmentsForApi,
      recording,
    );

    session.synced = true;
    await savePendingSession(session);
    final count = segmentsForApi.length;
  return uploadedThisRound.isNotEmpty
        ? 'Synced $count segment(s)'
        : 'Metadata registered ($count segment(s))';
  }

  Future<List<String>> syncAllPending(
    CognitoSession session, {
    void Function(String status)? onStatus,
  }) async {
    final pending = await loadPendingSessions();
    final results = <String>[];
    for (final rec in pending.where((s) => !s.synced)) {
      final msg = await syncSession(rec, session, onStatus: onStatus);
      results.add('${rec.name}: $msg');
    }
    return results;
  }
}
