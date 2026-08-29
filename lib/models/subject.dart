import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String subjectId;
  final String name;
  final String code;
  final List<String> teacherIds;
  final DateTime createdAt;

  Subject({
    required this.subjectId,
    required this.name,
    required this.code,
    required this.teacherIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'name': name,
      'code': code,
      'teacherIds': teacherIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      subjectId: map['subjectId'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      teacherIds: List<String>.from(map['teacherIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Subject copyWith({
    String? subjectId,
    String? name,
    String? code,
    List<String>? teacherIds,
    DateTime? createdAt,
  }) {
    return Subject(
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      code: code ?? this.code,
      teacherIds: teacherIds ?? this.teacherIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
