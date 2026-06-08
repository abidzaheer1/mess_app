class PasswordValidationResult {
  const PasswordValidationResult({required this.isValid, required this.message, required this.score});

  final bool isValid;
  final String message;
  final int score; // 0–4
}

PasswordValidationResult validatePassword(String password) {
  if (password.length < 8) {
    return const PasswordValidationResult(
      isValid: false,
      message: 'At least 8 characters required',
      score: 0,
    );
  }

  var score = 0;
  if (password.length >= 8) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/]').hasMatch(password)) score++;

  if (score < 4) {
    return PasswordValidationResult(
      isValid: false,
      message: 'Include upper & lower case, a number, and a symbol',
      score: score,
    );
  }

  return PasswordValidationResult(
    isValid: true,
    message: 'Strong password',
    score: score,
  );
}

String? passwordFieldValidator(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  final result = validatePassword(value);
  return result.isValid ? null : result.message;
}
