import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Create a new attendance session, valid for [durationMinutes]
  Future<AttendanceSession> createSession({
    required String teacherId,
    required String subject,
    int durationMinutes = 10,
  }) async {
    final sessionId = _uuid.v4();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: durationMinutes));

    final session = AttendanceSession(
      sessionId: sessionId,
      teacherId: teacherId,
      subject: subject,
      createdAt: now,
      expiresAt: expiresAt,
    );

    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .set(session.toMap());

    return session;
  }

  // Fetch a session by ID (used later when student scans the QR)
  Future<AttendanceSession?> getSession(String sessionId) async {
    final doc = await _firestore.collection('sessions').doc(sessionId).get();
    if (!doc.exists) return null;
    return AttendanceSession.fromMap(doc.data()!);
  }

  // Fetch all sessions created by a teacher, sorted newest first
  Future<List<AttendanceSession>> getSessionsForTeacher(String teacherId) async {
    final query = await _firestore
        .collection('sessions')
        .where('teacherId', isEqualTo: teacherId)
        .get();
    final sessions = query.docs
        .map((doc) => AttendanceSession.fromMap(doc.data()))
        .toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  // Batch-fetch sessions by a list of IDs — used by the student history screen
  Future<Map<String, AttendanceSession>> getSessionsMapByIds(
      List<String> sessionIds) async {
    if (sessionIds.isEmpty) return {};
    final futures = sessionIds.map((id) => getSession(id));
    final results = await Future.wait(futures);
    final map = <String, AttendanceSession>{};
    for (int i = 0; i < sessionIds.length; i++) {
      if (results[i] != null) map[sessionIds[i]] = results[i]!;
    }
    return map;
  }

  // Fetch all sessions created within a given calendar month
  Future<List<AttendanceSession>> getSessionsForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final query = await _firestore
        .collection('sessions')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    return query.docs
        .map((doc) => AttendanceSession.fromMap(doc.data()))
        .toList();
  }

  // Mark a session as BLE-enabled after the teacher's beacon starts.
  Future<void> updateBleEnabled(String sessionId,
      {required bool enabled}) async {
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .update({'bleEnabled': enabled});
  }

  // Check if teacher has an ongoing, unexpired session for the specified subject
  Future<AttendanceSession?> getActiveSessionForSubject({
    required String teacherId,
    required String subject,
  }) async {
    final sessions = await getSessionsForTeacher(teacherId);
    final now = DateTime.now();
    for (final session in sessions) {
      if (session.subject.trim().toLowerCase() == subject.trim().toLowerCase() &&
          session.expiresAt.isAfter(now)) {
        return session;
      }
    }
    return null;
  }
}

