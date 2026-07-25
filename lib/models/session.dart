import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSession {
  final String sessionId;
  final String teacherId;
  final String subject;
  final DateTime createdAt;
  final DateTime expiresAt;

  AttendanceSession({
    required this.sessionId,
    required this.teacherId,
    required this.subject,
    required this.createdAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'teacherId': teacherId,
      'subject': subject,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory AttendanceSession.fromMap(Map<String, dynamic> map) {
    return AttendanceSession(
      sessionId: map['sessionId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subject: map['subject'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}