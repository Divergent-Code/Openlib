/// Centralized book format enum used across the app.
///
/// Map to/from raw strings (DB, Anna's Archive parser, file extensions)
/// through the helpers below so every layer speaks the same language.
enum BookFormat {
  pdf,
  epub,
  cbz,
  cbr,
  azw3,
  unknown;

  // ── Helpers ────────────────────────────────────────────────────────

  /// Lowercase file extension including the leading dot, e.g. `.pdf`.
  String get extension => '.$name';

  /// Human-readable label (e.g. "CBZ", "EPUB").
  String get displayName => name.toUpperCase();

  /// True for formats that have an in-app reader.
  bool get hasBuiltInReader => this == epub || this == pdf;

  /// Parse from a lowercase string returned by parsers / DB.
  static BookFormat fromString(String? raw) {
    if (raw == null) return BookFormat.unknown;
    switch (raw.trim().toLowerCase()) {
      case 'pdf':
        return BookFormat.pdf;
      case 'epub':
        return BookFormat.epub;
      case 'cbz':
        return BookFormat.cbz;
      case 'cbr':
        return BookFormat.cbr;
      case 'azw3':
      case 'azw':
      case 'mobi':
        return BookFormat.azw3;
      default:
        return BookFormat.unknown;
    }
  }

  /// Parse from a MIME type string.
  static BookFormat fromMimeType(String mime) {
    switch (mime.toLowerCase()) {
      case 'application/pdf':
        return BookFormat.pdf;
      case 'application/epub+zip':
        return BookFormat.epub;
      case 'application/vnd.comicbook+zip':
      case 'application/x-cbz':
        return BookFormat.cbz;
      case 'application/vnd.comicbook-rar':
      case 'application/x-cbr':
        return BookFormat.cbr;
      case 'application/vnd.amazon.ebook':
        return BookFormat.azw3;
      default:
        return BookFormat.unknown;
    }
  }
}
