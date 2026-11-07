/// Shared registration policy. Existing accounts can still use their password.
String? registrationPasswordError(String? password) {
  if (password == null || password.length < 10) {
    return 'Mật khẩu cần ít nhất 10 ký tự';
  }
  if (password.length > 128) return 'Mật khẩu tối đa 128 ký tự';
  if (!RegExp(r'[a-z]').hasMatch(password) ||
      !RegExp(r'[A-Z]').hasMatch(password) ||
      !RegExp(r'[0-9]').hasMatch(password) ||
      !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(password)) {
    return 'Cần chữ hoa, chữ thường, số và ký tự đặc biệt';
  }
  return null;
}
