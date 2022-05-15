
class FormValidator {
  static String? Function(String?) maxLength(int maxLength, { String? errorText }) {
    return (String? value) => value != null && (value.length > maxLength) ? errorText : null;
  }

  static String? Function(String?) required({ String? errorText }) {
    return (String? value) => value == null || value == ''? errorText : null;
  }

  static String? Function(String?) buildValidator(List<String? Function(String?)> validators) {
    return (value) {
      for (Function validator in validators) {
        final error = validator(value);
        if (error != null) {
          return error;
        }
      }

      return null;
    };
  }
}