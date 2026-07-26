import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> markAttendance(AttendanceRecord record) async {
    final docId = '${record.sessionId}_${record.studentId}';

    // Check 1: has this student already marked attendance for this session?
    final existing = await _firestore.collection('attendance').doc(docId).get();
    if (existing.exists) {
      throw Exception('Attendance already marked for this session.');
    }

    // Check 2: has this physical device already been used for a DIFFERENT
    // student in this same session?
    final deviceCheck = await _firestore
        .collection('attendance')
        .where('sessionId', isEqualTo: record.sessionId)
        .where('deviceId', isEqualTo: record.deviceId)
        .get();

    if (deviceCheck.docs.isNotEmpty) {
      throw Exception(
        'This device has already been used to mark attendance for this session.',
      );
    }

    await _firestore.collection('attendance').doc(docId).set(record.toMap());
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
}