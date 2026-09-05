class PasskeyException implements Exception {
  PasskeyException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PasskeyRecord {
  const PasskeyRecord({
    required this.id,
    required this.email,
    required this.userId,
    required this.label,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String userId;
  final String label;
  final String createdAt;

  factory PasskeyRecord.fromJson(Map<String, dynamic> json) => PasskeyRecord(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        label: json['label'] as String? ?? 'Passkey',
        createdAt: json['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'userId': userId,
        'label': label,
        'createdAt': createdAt,
      };
}

class PasskeyAssertion {
  const PasskeyAssertion({
    required this.credentialId,
    this.userHandle,
  });

  final String credentialId;
  final String? userHandle;
}
