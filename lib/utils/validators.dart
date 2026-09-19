class Validators {
  static String? requiredField(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? mobile(String? value) {
    final required = requiredField(value, fieldName: 'Mobile');
    if (required != null) return required;
    final digits = value!.trim();
    if (digits.length < 10) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String fieldName = 'Value'}) {
    final required = requiredField(value, fieldName: fieldName);
    if (required != null) return required;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null || parsed <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }
}
