import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSession {
  final String sessionId;
  final String teacherId;
  final String subject;
  final DateTime createdAt;
  final DateTime expiresAt;
  /// True when the teacher device successfully started BLE advertising.
  /// Students check this flag to decide whether to run the proximity scan.
  final bool bleEnabled;

  AttendanceSession({
    required this.sessionId,
    required this.teacherId,
    required this.subject,
    required this.createdAt,
    required this.expiresAt,
    this.bleEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'teacherId': teacherId,
      'subject': subject,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'bleEnabled': bleEnabled,
    };
  }

  factory AttendanceSession.fromMap(Map<String, dynamic> map) {
    return AttendanceSession(
      sessionId: map['sessionId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subject: map['subject'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      bleEnabled: map['bleEnabled'] ?? false,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}