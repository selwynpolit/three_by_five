/// Minimal email structure extracted from pasted plain-text email.
class EmailClip {
  const EmailClip({
    this.subject,
    this.sender,
    this.bodySnippet,
    this.originalDate,
  });

  final String? subject;
  final String? sender;
  final String? bodySnippet;
  final DateTime? originalDate;
}

/// Detects and parses pasted raw email text into structured fields.
class EmailClipService {
  static final _from = RegExp(
    r'^From:\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  );
  static final _subject = RegExp(
    r'^Subject:\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  );
  static final _date = RegExp(
    r'^Date:\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  );

  bool looksLikeEmail(String text) =>
      _from.hasMatch(text) && _subject.hasMatch(text);

  EmailClip? parse(String text) {
    if (!looksLikeEmail(text)) return null;

    final sender = _from.firstMatch(text)?.group(1)?.trim();
    final subject = _subject.firstMatch(text)?.group(1)?.trim();
    final dateStr = _date.firstMatch(text)?.group(1)?.trim();
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

    // Body is everything after the headers block (first blank line).
    final bodyStart = text.indexOf('\n\n');
    final snippet = bodyStart >= 0
        ? text.substring(bodyStart).trim().split('\n').take(5).join(' ')
        : null;

    return EmailClip(
      subject: subject,
      sender: sender,
      bodySnippet: snippet,
      originalDate: date,
    );
  }
}
