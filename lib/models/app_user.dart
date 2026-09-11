class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  // 'pending' | 'approved' | 'rejected' — only used for teachers
  final String status;
  final String? rollNumber;
  final List<double>? faceEmbedding;  // ADDED

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.status = 'approved',
    this.rollNumber,
    this.faceEmbedding,  // ADDED
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'rollNumber': rollNumber,
      'faceEmbedding': faceEmbedding,  // ADDED
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      status: map['status'] ?? 'approved',
      rollNumber: map['rollNumber'],
      faceEmbedding: map['faceEmbedding'] != null   // ADDED
          ? List<double>.from(map['faceEmbedding']) // ADDED
          : null,                                    // ADDED
    );
  }
}