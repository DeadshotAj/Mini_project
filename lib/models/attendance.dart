import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String sessionId;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final DateTime markedAt;
  final bool faceVerified;
  // 'verified' | 'failed' | 'overridden'
  // Defaults to 'verified' for backwards compatibility with existing records.
  final String verificationStatus;

  AttendanceRecord({
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    required this.markedAt,
    this.faceVerified = false,
    this.verificationStatus = 'verified',
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'studentId': studentId,
      'studentName': studentName,
      'rollNumber': rollNumber,
      'markedAt': Timestamp.fromDate(markedAt),
      'faceVerified': faceVerified,
      'verificationStatus': verificationStatus,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      sessionId: map['sessionId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      rollNumber: map['rollNumber'],
      markedAt: (map['markedAt'] as Timestamp).toDate(),
      faceVerified: map['faceVerified'] ?? false,
      verificationStatus: map['verificationStatus'] ?? 'verified',
    );
  }
}