final diagnosticWindowsPathPattern = RegExp(
  r'(?:[A-Za-z]:\\|\\\\)[^|"\r\n]*?(?=\s+\((?:error|code)\b|[|"\r\n]|$)',
  caseSensitive: false,
);
final diagnosticUnixPathPattern = RegExp(
  r'/(?:Users|home)/[^|"\r\n]*?(?=\s+\((?:error|code)\b|[|"\r\n]|$)',
  caseSensitive: false,
);
final diagnosticUrlQueryPattern = RegExp(
  r'(https?://[^\s?|]+)\?[^\s|]+',
  caseSensitive: false,
);
final diagnosticSecretFieldPattern = RegExp(
  r'\b(access[_-]?key|auth[_-]?token|token|device[_-]?id|session[_-]?id)\s*[:=]\s*[^&\s|]+',
  caseSensitive: false,
);

String redactDiagnosticData(String text) {
  return text
      .replaceAll(diagnosticWindowsPathPattern, '[local path]')
      .replaceAll(diagnosticUnixPathPattern, '[local path]')
      .replaceAllMapped(
        diagnosticUrlQueryPattern,
        (match) => '${match.group(1)}?[redacted]',
      )
      .replaceAllMapped(
        diagnosticSecretFieldPattern,
        (match) => '${match.group(1)}=[redacted]',
      );
}
