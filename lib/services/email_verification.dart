class EmailVerificationDelivery {
  const EmailVerificationDelivery({
    required this.expiresAt,
    required this.resendAt,
  });

  final DateTime expiresAt;
  final DateTime resendAt;

  factory EmailVerificationDelivery.fromMap(Map<String, dynamic> data) =>
      EmailVerificationDelivery(
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (data['expiresAt'] as num).toInt(),
        ),
        resendAt: DateTime.fromMillisecondsSinceEpoch(
          (data['resendAt'] as num).toInt(),
        ),
      );
}
