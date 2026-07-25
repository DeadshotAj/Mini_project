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
}