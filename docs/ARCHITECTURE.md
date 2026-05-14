# Openlib — State Management Architecture

> **Status:** Accepted Design | **Created:** 2026-05-14

---

## 1. Purpose

This document captures the validated design for migrating Openlib's state
management from a mixed MVC/Riverpod pattern to a pure, idiomatic
**Riverpod 2.x** architecture using standard `Notifier` and `AsyncNotifier`
classes.

### Goals

- Eliminate `WidgetRef` leaking into business logic (e.g., static controllers).
- Consolidate scattered `StateProvider`s into unified, immutable state objects.
- Make all business logic independently unit-testable.
- Delete the redundant `lib/controllers/` directory.

### Non-Goals

- Introducing code generation (`riverpod_generator` / `build_runner`).
- Adding integration or widget tests as part of this refactor.
- Changing any visible UI behaviour.

---

## 2. Understanding Summary

| Property | Detail |
|---|---|
| **What** | Refactor state management to pure Riverpod 2.x `Notifier` pattern |
| **Why** | Eliminate `WidgetRef` leaking, scattered state, and mixed MVC patterns |
| **Who** | All current and future contributors to the Openlib codebase |
| **Constraint** | Must use only already-installed `flutter_riverpod: ^2.3.6` |
| **Non-goal** | Do not introduce code generation tools |

### Assumptions

- One active download is supported at a time (no queue).
- `downloadNotifierProvider` is **non-auto-disposing** so downloads survive navigation.
- State resets to `idle` only via an explicit `reset()` call from the UI (e.g., after the user dismisses a success/failure dialog).

---

## 3. Target Directory Structure

```
lib/
├── constants/          # App-wide constants and hardcoded data (categories, etc.)
├── providers/          # All Notifiers, State objects, and derived Providers
│   ├── constants.dart
│   ├── api_providers.dart
│   ├── download_providers.dart   ← DownloadNotifier lives here
│   ├── library_providers.dart    ← LibraryNotifier lives here
│   ├── reader_providers.dart
│   ├── search_providers.dart     ← SearchFiltersNotifier lives here
│   └── ui_providers.dart
├── services/           # Pure Dart data-access classes — zero Riverpod imports
│   ├── annas_archive.dart
│   ├── database.dart
│   ├── download_file.dart
│   ├── files.dart
│   ├── goodreads.dart
│   ├── google_suggest_api.dart
│   ├── open_library.dart
│   └── share_book.dart
├── state/
│   └── state.dart      # Barrel export file — unchanged
├── ui/                 # Pure Flutter widgets; only ref.watch / ref.read allowed
└── main.dart
```

> **Deleted:** `lib/controllers/` — `DownloadController` logic moves into
> `DownloadNotifier` inside `providers/download_providers.dart`.

---

## 4. Design: State Objects and Notifiers

### 4.1 Download Domain

#### `DownloadState` (immutable data class)

```dart
enum DownloadStatus { idle, running, complete, failed }
enum ChecksumStatus { idle, running, success, failed }

class DownloadState {
  final DownloadStatus status;
  final ChecksumStatus checksumStatus;
  final double progress;         // 0.0 – 1.0
  final int downloadedBytes;
  final int totalBytes;
  final bool isMirrorActive;
  final String? errorMessage;

  const DownloadState({...});

  DownloadState copyWith({...});
}
```

#### `DownloadNotifier` (replaces `DownloadController`)

```dart
class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() => const DownloadState(status: DownloadStatus.idle, ...);

  Future<void> startDownload(BookInfoData data, List<String> mirrors) async { ... }
  void cancelDownload() { ... }
  void reset() => state = build(); // Called by UI after dialog dismissal
  Future<void> _saveToLibrary(BookInfoData data) async { ... }
}

final downloadNotifierProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);
```

**Key rule:** The `bytesToFileSize` utility function stays as a pure function in
`download_providers.dart`. Formatted strings are derived in the UI directly from
`downloadState.downloadedBytes` and `downloadState.totalBytes`.

---

### 4.2 Search Domain

#### `SearchFiltersState` (immutable data class)

```dart
class SearchFiltersState {
  final String selectedType;     // default: "All"
  final String selectedSort;     // default: "Most Relevant"
  final String selectedFileType; // default: "All"
  final String query;
  final bool filtersEnabled;

  const SearchFiltersState({...});
  SearchFiltersState copyWith({...});

  // Computed getters replace the derived StateProviders
  String get typeValue => typeValues[selectedType] ?? '';
  String get sortValue => sortValues[selectedSort] ?? '';
  String get fileTypeValue =>
      selectedFileType == "All" ? '' : selectedFileType.toLowerCase();
}
```

#### `SearchFiltersNotifier`

```dart
class SearchFiltersNotifier extends Notifier<SearchFiltersState> {
  @override
  SearchFiltersState build() => const SearchFiltersState(...);

  void setType(String type) => state = state.copyWith(selectedType: type);
  void setSort(String sort) => state = state.copyWith(selectedSort: sort);
  void setFileType(String fileType) => ...;
  void setQuery(String query) => ...;
  void toggleFilters() => ...;
  void reset() => state = build();
}

final searchFiltersProvider =
    NotifierProvider<SearchFiltersNotifier, SearchFiltersState>(
        SearchFiltersNotifier.new);
```

> **Deleted:** `selectedTypeState`, `selectedSortState`, `selectedFileTypeState`,
> `searchQueryProvider`, `enableFiltersState`, `getTypeValue`, `getSortValue`,
> `getFileTypeValue` — all replaced by `searchFiltersProvider`.

---

### 4.3 Library Domain

The two free-floating functions in `library_providers.dart` that accept
`WidgetRef` are migrated into a `LibraryNotifier`:

```dart
class LibraryNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> savePdfPosition(String fileName) async {
    final page = ref.read(pdfCurrentPage);
    await MyLibraryDb.instance.saveBookState(fileName, page.toString());
  }

  Future<void> saveEpubPosition(String fileName, String? position) async {
    await MyLibraryDb.instance.saveBookState(fileName, position ?? '');
  }
}

final libraryNotifierProvider =
    NotifierProvider<LibraryNotifier, void>(LibraryNotifier.new);
```

> **Deleted:** `savePdfState()` and `saveEpubState()` free functions.

---

## 5. UI Contract

Widgets in `lib/ui/` **must** follow these rules:

| Allowed | Not Allowed |
|---|---|
| `ref.watch(someProvider)` | Accepting `WidgetRef` as a constructor/method argument |
| `ref.read(someProvider.notifier).someMethod()` | Calling static controller methods |
| Reading computed properties from state objects | Accessing multiple separate providers for one logical concept |

---

## 6. Error Handling

- All errors are caught inside Notifiers and surfaced via the `errorMessage`
  field on the state object.
- The UI reacts to `status == DownloadStatus.failed` to display error UI.
- State is never left in an inconsistent intermediate condition (e.g., progress
  at 100% while status is still `running`).

---

## 7. Testing Strategy

- Unit tests use Riverpod's `ProviderContainer` — no Flutter widget tree needed.
- Service dependencies (e.g., `MyLibraryDb`) are overridden with fakes via
  `ProviderContainer(overrides: [...])`.
- Each Notifier's state transitions are asserted directly.

---

## 8. Decision Log

| # | Decision | Alternatives Considered | Reason Chosen |
|---|---|---|---|
| 1 | Use standard `Notifier` classes | `riverpod_generator`, Coordinator Provider | No new dependencies; uses already-installed tools |
| 2 | Unified immutable `State` objects per domain | Scattered `StateProvider`s | Single rebuild per tick; no inconsistent state; extensible |
| 3 | `DownloadNotifier` replaces `DownloadController` | Keep static controller | Eliminates `WidgetRef` leaking into business logic |
| 4 | Delete `controllers/` directory | Keep for future use | YAGNI — logic now lives in `providers/` |
| 5 | `downloadNotifierProvider` is non-auto-disposing | Auto-dispose | Download must survive widget navigation |
| 6 | State resets via explicit `reset()` call | Auto-reset; reset on new download start | UI controls lifecycle; prevents accidental state flashes |
| 7 | Computed getters replace derived `StateProvider`s | Keep derived providers | Reduces provider count; logic co-located with data |

---

## 9. Service Layer Abstraction

> **Status:** Accepted Design | **Created:** 2026-05-14

### 9.1 Purpose

Decouple the search and book-detail feature from a single hardcoded `AnnasArchive`
class by introducing a `BookSearchRepository` abstraction with automatic mirror
fallback and graceful degradation when all mirrors are exhausted.

### 9.2 Goals

- Provide resilience against individual mirror outages via an ordered fallback chain.
- Surface a distinct "Service Unavailable" UI (not a generic error) when all mirrors fail.
- Move `BookData`/`BookInfoData` models into a source-agnostic `lib/models/` layer.
- Inject the repository via Riverpod — fully testable with fake implementations.

### 9.3 Non-Goals

- User-configurable mirror lists (future enhancement).
- Aggregating results from multiple independent sources in parallel.
- Changes to the existing `TrendingBooksImpl` pattern.

---

### 9.4 Updated Directory Structure

```
lib/
├── constants/
├── models/                        # NEW — source-agnostic data classes
│   └── book.dart                  # BookData, BookInfoData
├── providers/
│   ├── api_providers.dart         # Updated — injects BookSearchRepository
│   └── ... (others unchanged)
├── services/
│   ├── annas_archive.dart         # Updated — accepts baseUrl via constructor
│   ├── book_search_repository.dart  # NEW — abstract class + AnnasArchiveRepository
│   └── ... (others unchanged)
├── state/
│   └── state.dart                 # Barrel — adds models/book.dart export
└── ui/
    └── components/
        └── service_unavailable_widget.dart  # NEW — distinct degraded UI
```

---

### 9.5 Mirror Configuration (`constants.dart`)

```dart
const List<String> annasArchiveMirrors = [
  'https://annas-archive.se',
  'https://annas-archive.org',
  'https://annas-archive.gs',
];
```

Mirror order matters — the first URL is the primary. The list is the single place
to update when a mirror goes offline.

---

### 9.6 Repository Interface & Implementation

```dart
// Abstract contract
abstract class BookSearchRepository {
  Future<List<BookData>> searchBooks({
    required String searchQuery,
    String content,
    String sort,
    String fileType,
    bool enableFilters,
  });

  Future<BookInfoData> bookInfo({required String url});
}

// Concrete implementation with mirror fallback
class AnnasArchiveRepository implements BookSearchRepository {
  @override
  Future<List<BookData>> searchBooks({...}) async {
    for (final mirror in annasArchiveMirrors) {
      try {
        return await AnnasArchive(baseUrl: mirror).searchBooks(...);
      } on DioException catch (_) {
        continue;
      }
    }
    throw const AllMirrorsFailedException();
  }

  @override
  Future<BookInfoData> bookInfo({required String url}) async {
    for (final mirror in annasArchiveMirrors) {
      try {
        final mirrorUrl = url.replaceFirst(RegExp(r'https://[^/]+'), mirror);
        return await AnnasArchive(baseUrl: mirror).bookInfo(url: mirrorUrl);
      } on DioException catch (_) {
        continue;
      }
    }
    throw const AllMirrorsFailedException();
  }
}

// Typed exception — distinguishes total failure from query errors
class AllMirrorsFailedException implements Exception {
  const AllMirrorsFailedException();
  @override
  String toString() => 'AllMirrorsFailedException: all known mirrors are unreachable.';
}

// Riverpod registration
final bookSearchRepositoryProvider = Provider<BookSearchRepository>(
  (ref) => AnnasArchiveRepository(),
);
```

---

### 9.7 Provider Injection (`api_providers.dart`)

```dart
// Before
final AnnasArchive annasArchive = AnnasArchive();
List<BookData> data = await annasArchive.searchBooks(...);

// After
final repository = ref.watch(bookSearchRepositoryProvider);
List<BookData> data = await repository.searchBooks(...);
```

---

### 9.8 Degraded UI

`AllMirrorsFailedException` propagates through the `FutureProvider` as an
`AsyncError`. The `results_page.dart` error handler pattern-matches on the
exception type:

```dart
error: (err, _) {
  if (err is AllMirrorsFailedException) {
    return ServiceUnavailableWidget(
      onRetry: () => ref.refresh(searchProvider(searchQuery)),
    );
  }
  return CustomErrorWidget(error: err, stackTrace: _);
},
```

`ServiceUnavailableWidget` shows a distinct icon, message
("All sources are currently unreachable"), and a Retry button.

---

### 9.9 Decision Log (Service Layer)

| # | Decision | Alternatives Considered | Reason Chosen |
|---|---|---|---|
| 8 | `BookSearchRepository` only; leave `TrendingBooksImpl` untouched | Unified `BookRepository` | `TrendingBooksImpl` already works and has its own fallback logic |
| 9 | Models in `lib/models/book.dart` | Keep in service; re-export barrel | True source-agnosticism; ready for caching serialisation |
| 10 | Mirror list in `constants.dart` | Hardcoded in repository; user-configurable | Config stays separate from logic; single update point |
| 11 | `AllMirrorsFailedException` typed exception | String error message | Enables type-safe UI pattern-matching; no string parsing |
| 12 | `AnnasArchive` accepts `baseUrl` via constructor | Static field; factory method | Minimal change; enables per-mirror instantiation in the loop |

---

## 10. Data Persistence & Caching Strategy

> **Status:** Accepted Design | **Created:** 2026-05-14

### 10.1 Purpose

Cache `BookInfoData` (book detail pages) in SQLite to eliminate redundant
network fetches for stable data, using a stale-while-revalidate pattern so
users always see data instantly on revisit.

### 10.2 Goals

- Instant perceived load on revisit to any previously viewed book detail page.
- 7-day TTL keeps mirror links fresh without excessive network calls.
- Silent background re-fetch on stale hit; no user-visible disruption.

### 10.3 Non-Goals

- Caching search result lists.
- User-visible cache management UI.
- Real-time UI update during the same session from background re-fetch.

---

### 10.4 Model Serialization (`lib/models/book.dart`)

```dart
class BookInfoData extends BookData {
  Map<String, dynamic> toMap() => {
    'md5': md5, 'title': title, 'author': author,
    'thumbnail': thumbnail, 'publisher': publisher,
    'info': info, 'link': link, 'format': format,
    'mirror': mirror, 'description': description,
    'cachedAt': DateTime.now().millisecondsSinceEpoch,
  };

  factory BookInfoData.fromMap(Map<String, dynamic> map) => BookInfoData(
    md5: map['md5'], title: map['title'], ...
  );
}
```

TTL constant in `constants.dart`:
```dart
const Duration bookDetailCacheTtl = Duration(days: 7);
```

---

### 10.5 Database Schema (version 5 → 6)

New table added via `onCreate` and `onUpgrade`:

```sql
CREATE TABLE bookcache (
  md5         TEXT PRIMARY KEY,
  title       TEXT,
  author      TEXT,
  thumbnail   TEXT,
  publisher   TEXT,
  info        TEXT,
  link        TEXT,
  format      TEXT,
  mirror      TEXT,
  description TEXT,
  cachedAt    INTEGER   -- Unix ms timestamp for TTL comparison
)
```

Three new methods on `MyLibraryDb`:
- `cacheBookInfo(BookInfoData)` — upsert with `ConflictAlgorithm.replace`
- `getCachedBookInfo(String md5)` — returns raw map (includes `cachedAt`) or null
- `evictExpiredBookCache(int cutoffMs)` — deletes rows older than cutoff

---

### 10.6 Repository: Stale-While-Revalidate

```
bookInfo(url) called
  ↓
getCachedBookInfo(md5)
  ├── null (miss)  → _fetchAndCache(url) → return
  └── hit
        ├── fresh  → return BookInfoData.fromMap(cached)
        └── stale  → return BookInfoData.fromMap(cached) immediately
                      + _refreshInBackground(url) [fire and forget]
```

Background re-fetch failures are silently swallowed — stale data already
returned; failure is non-fatal.

`_fetchAndCache` also calls `evictExpiredBookCache` opportunistically to
keep the table lean without a separate scheduled job.

---

### 10.7 UI Behaviour

| Scenario | Behaviour |
|---|---|
| First visit, no cache | Spinner → fetch (2–5s) → data shown → cached |
| Revisit within 7 days | Instant — no spinner, no network call |
| Revisit after 7 days | Instant stale data → background re-fetch for next visit |
| All mirrors fail, no cache | `AllMirrorsFailedException` → `ServiceUnavailableWidget` |
| All mirrors fail, stale cache | Stale data shown instantly; background failure silent |

---

### 10.8 Decision Log (Caching)

| # | Decision | Alternatives | Reason |
|---|---|---|---|
| 13 | Cache `BookInfoData` only | Search results; both | Stable key (md5), high revisit rate, manageable permutations |
| 14 | SQLite `bookcache` table | In-memory Map; separate DB | Survives restarts; no new dependencies |
| 15 | 7-day TTL | 24h; 30 days; forever | Balances freshness vs. redundant fetches; mirror links rotate |
| 16 | Stale-while-revalidate | Block on re-fetch; never re-fetch | Instant perceived load; keeps mirror links fresh |
| 17 | Background re-fetch updates cache only (no same-session UI update) | AsyncNotifier with mid-session invalidation | Simpler; marginal same-session benefit doesn't justify complexity |
