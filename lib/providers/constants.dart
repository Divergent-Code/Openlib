Map<String, String> typeValues = {
  'All': '',
  'Any Books': 'book_any',
  'Unknown Books': 'book_unknown',
  'Fiction Books': 'book_fiction',
  'Non-fiction Books': 'book_nonfiction',
  'Comic Books': 'book_comic',
  'Magazine': 'magazine',
  'Standards Document': 'standards_document',
  'Journal Article': 'journal_article'
};

Map<String, String> sortValues = {
  'Most Relevant': '',
  'Newest': 'newest',
  'Oldest': 'oldest',
  'Largest': 'largest',
  'Smallest': 'smallest',
};

List<String> fileType = ["All", "PDF", "Epub", "Cbr", "Cbz"];

enum ProcessState { waiting, running, complete }

enum CheckSumProcessState { waiting, running, failed, success }

class FileName {
  final String md5;
  final String format;

  FileName({required this.md5, required this.format});
}

// Ordered list of Anna's Archive mirrors.
// The repository tries each in sequence; update this list when a mirror changes.
const List<String> annasArchiveMirrors = [
  'https://annas-archive.se',
  'https://annas-archive.org',
  'https://annas-archive.gs',
];

