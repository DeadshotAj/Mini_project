class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role; // "teacher" or "student"
  final String? rollNumber; // only relevant for students

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.rollNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'rollNumber': rollNumber,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      rollNumber: map['rollNumber'],
    );
  }
}