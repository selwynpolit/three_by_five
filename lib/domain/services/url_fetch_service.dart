import 'package:http/http.dart' as http;

class UrlFetchService {
  static final _titlePattern = RegExp(
    r'<title[^>]*>([^<]+)</title>',
    caseSensitive: false,
    dotAll: true,
  );

  /// Fetches page title and infers favicon URL from [url].
  /// Returns null fields on error or timeout.
  Future<({String? title, String? faviconUrl})> fetch(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http
          .get(uri, headers: {'User-Agent': '3by5/1.0'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return (title: null, faviconUrl: _faviconUrl(uri));
      }

      final title = _extractTitle(response.body);
      return (title: title, faviconUrl: _faviconUrl(uri));
    } catch (_) {
      return (title: null, faviconUrl: null);
    }
  }

  String? _extractTitle(String html) {
    final match = _titlePattern.firstMatch(html);
    if (match == null) return null;
    return _decode(match.group(1)!.trim());
  }

  String _faviconUrl(Uri uri) =>
      '${uri.scheme}://${uri.host}/favicon.ico';

  /// Minimal HTML entity decoding for common characters.
  String _decode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
}
