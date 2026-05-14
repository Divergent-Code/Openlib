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
