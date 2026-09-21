import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser?> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? rollNumber,
    List<double>? faceEmbedding,
  }) async {
    UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user;
    if (user == null) return null;

    final appUser = AppUser(
      uid: user.uid,
      name: name,
      email: email,
      role: role,
      status: role == 'teacher' ? 'pending' : 'approved',
      rollNumber: role == 'student' ? rollNumber : null,
      faceEmbedding: role == 'student' ? faceEmbedding : null,
    );

    await _firestore.collection('users').doc(user.uid).set(appUser.toMap());

    return appUser;
  }

  Future<AppUser?> loginUser({
    required String email,
    required String password,
  }) async {
    UserCredential cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return AppUser.fromMap(doc.data()!);
  }

  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return AppUser.fromMap(doc.data()!);
  }

  Future<List<AppUser>> getAllStudents() async {
    final query = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();
    final students = query.docs
        .map((doc) => AppUser.fromMap(doc.data()))
        .toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  Future<List<AppUser>> getAllTeachers() async {
    final query = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .get();
    final teachers = query.docs
        .map((doc) => AppUser.fromMap(doc.data()))
        .toList();
    teachers.sort((a, b) => a.name.compareTo(b.name));
    return teachers;
  }

  Future<List<AppUser>> getPendingTeachers() async {
    final query = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .where('status', isEqualTo: 'pending')
        .get();
    final teachers = query.docs
        .map((doc) => AppUser.fromMap(doc.data()))
        .toList();
    teachers.sort((a, b) => a.name.compareTo(b.name));
    return teachers;
  }

  Future<void> approveTeacher(String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'status': 'approved'});
  }

  Future<void> rejectTeacher(String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'status': 'rejected'});
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}