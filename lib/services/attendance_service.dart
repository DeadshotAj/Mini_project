import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> markAttendance(AttendanceRecord record) async {
    final docId = '${record.sessionId}_${record.studentId}';

    final existing = await _firestore.collection('attendance').doc(docId).get();
    if (existing.exists) {
      throw Exception('Attendance already marked for this session.');
    }

    await _firestore.collection('attendance').doc(docId).set(record.toMap());
  }

  // Save a face-failed record so a teacher can review and override it.
  Future<void> markAttendancePending(AttendanceRecord record) async {
    final docId = '${record.sessionId}_${record.studentId}';

    final existing = await _firestore.collection('attendance').doc(docId).get();
    if (existing.exists) {
      throw Exception('Attendance already marked for this session.');
    }

    await _firestore.collection('attendance').doc(docId).set(
      record.toMap()
        ..['verificationStatus'] = 'failed'
        ..['faceVerified'] = false,
    );
  }

  Future<List<AttendanceRecord>> getAttendanceForSession(String sessionId) async {
    final query = await _firestore
        .collection('attendance')
        .where('sessionId', isEqualTo: sessionId)
        .get();
    return query.docs.map((doc) => AttendanceRecord.fromMap(doc.data())).toList();
  }

  Future<List<AttendanceRecord>> getAttendanceForStudent(String studentId) async {
    final query = await _firestore
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .get();
    return query.docs.map((doc) => AttendanceRecord.fromMap(doc.data())).toList();
  }

  // Fetch all attendance records flagged as face-verification failures.
  Future<List<AttendanceRecord>> getFlaggedAttendance() async {
    final query = await _firestore
        .collection('attendance')
        .where('verificationStatus', isEqualTo: 'failed')
        .get();
    final records = query.docs
        .map((doc) => AttendanceRecord.fromMap(doc.data()))
        .toList();
    records.sort((a, b) => b.markedAt.compareTo(a.markedAt));
    return records;
  }

  // Teacher approves a flagged record — marks as verified + overridden.
  Future<void> overrideAttendance(String sessionId, String studentId) async {
    final docId = '${sessionId}_$studentId';
    await _firestore.collection('attendance').doc(docId).update({
      'faceVerified': true,
      'verificationStatus': 'overridden',
    });
  }

  // Teacher rejects a flagged record — deletes it entirely.
  Future<void> rejectAttendance(String sessionId, String studentId) async {
    final docId = '${sessionId}_$studentId';
    await _firestore.collection('attendance').doc(docId).delete();
  }
}