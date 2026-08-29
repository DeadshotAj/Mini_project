import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/subject.dart';

class SubjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Create a new subject
  Future<Subject> createSubject({
    required String name,
    required String code,
  }) async {
    final subjectId = _uuid.v4();
    final now = DateTime.now();

    final subject = Subject(
      subjectId: subjectId,
      name: name,
      code: code,
      teacherIds: [],
      createdAt: now,
    );

    await _firestore.collection('subjects').doc(subjectId).set(subject.toMap());
    return subject;
  }

  // Fetch all subjects, sorted by name
  Future<List<Subject>> getAllSubjects() async {
    final query = await _firestore.collection('subjects').get();
    final subjects =
        query.docs.map((doc) => Subject.fromMap(doc.data())).toList();
    subjects.sort((a, b) => a.name.compareTo(b.name));
    return subjects;
  }

  // Fetch subjects assigned to a specific teacher
  Future<List<Subject>> getSubjectsForTeacher(String teacherId) async {
    final query = await _firestore
        .collection('subjects')
        .where('teacherIds', arrayContains: teacherId)
        .get();
    final subjects =
        query.docs.map((doc) => Subject.fromMap(doc.data())).toList();
    subjects.sort((a, b) => a.name.compareTo(b.name));
    return subjects;
  }

  // Assign a teacher to a subject
  Future<void> assignTeacher(String subjectId, String teacherId) async {
    await _firestore.collection('subjects').doc(subjectId).update({
      'teacherIds': FieldValue.arrayUnion([teacherId]),
    });
  }

  // Remove a teacher from a subject
  Future<void> removeTeacher(String subjectId, String teacherId) async {
    await _firestore.collection('subjects').doc(subjectId).update({
      'teacherIds': FieldValue.arrayRemove([teacherId]),
    });
  }

  // Update a subject name/code
  Future<void> updateSubject(
      String subjectId, String name, String code) async {
    await _firestore.collection('subjects').doc(subjectId).update({
      'name': name,
      'code': code,
    });
  }

  // Delete a subject
  Future<void> deleteSubject(String subjectId) async {
    await _firestore.collection('subjects').doc(subjectId).delete();
  }
}
