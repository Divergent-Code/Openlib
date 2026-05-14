// Source-agnostic book data models.
// All services that return book data import from here — never from annas_archive.dart.

// ---------------------------------------------------------------------------
// Search result model
// ---------------------------------------------------------------------------

class BookData {
  final String title;
  final String? author;
  final String? thumbnail;
  final String link;
  final String md5;
  final String? publisher;
  final String? info;

  BookData({
    required this.title,
    this.author,
    this.thumbnail,
    required this.link,
    required this.md5,
    this.publisher,
    this.info,
  });
}

// ---------------------------------------------------------------------------
// Book detail model (extends search result with extra fields)
// ---------------------------------------------------------------------------

class BookInfoData extends BookData {
  String? mirror;
  final String? description;
  final String? format;

  BookInfoData({
    required super.title,
    required super.author,
    required super.thumbnail,
    required super.publisher,
    required super.info,
    required super.link,
    required super.md5,
    required this.format,
    required this.mirror,
    required this.description,
  });
}
