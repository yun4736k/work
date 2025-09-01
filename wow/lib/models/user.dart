class User {
  final String id;
  final String password;

  User({required this.id, required this.password});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      password: json['password'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,         // ✅ 대문자
      'PW': password,   // ✅ 대문자
    };
  }

  User copyWith({String? id, String? password}) {
    return User(
      id: id ?? this.id,
      password: password ?? this.password,
    );
  }
}