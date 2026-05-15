

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';

// Project imports:
import 'package:openlib/models/book_format.dart';
import 'package:openlib/services/files.dart' show getFilePath;
import 'package:openlib/ui/components/snack_bar_widget.dart';
import 'package:openlib/ui/epub_viewer.dart' show launchEpubViewer;
import 'package:openlib/ui/pdf_viewer.dart' show launchPdfViewer;

/// Central reader dispatcher.
///
/// Inspects the [format] and routes to the correct reader:
/// - EPUB → in-app [EpubViewerWidget] (or external app if preferred)
/// - PDF  → in-app [PdfView] (or external app if preferred)
/// - CBZ / CBR / AZW3 / fallback → external app via [OpenFile.open]
Future<void> openBookByFormat({
  required String fileName,
  required String format,
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final bookFormat = BookFormat.fromString(format);

  switch (bookFormat) {
    case BookFormat.epub:
      await launchEpubViewer(
        fileName: fileName,
        context: context,
        ref: ref,
      );
    case BookFormat.pdf:
      await launchPdfViewer(
        fileName: fileName,
        context: context,
        ref: ref,
      );
    case BookFormat.cbz:
    case BookFormat.cbr:
    case BookFormat.azw3:
    case BookFormat.unknown:
      await _openWithExternalApp(fileName, context);
  }
}

/// Opens any file via the system default handler.
///
/// Used for formats without an in-app reader (CBZ, CBR, AZW3, unknown).
Future<void> _openWithExternalApp(
    String fileName, BuildContext context) async {
  try {
    final String path = await getFilePath(fileName);
    await OpenFile.open(path, linuxByProcess: true);
  } catch (_) {
    // ignore: use_build_context_synchronously
    showSnackBar(context: context, message: 'Unable to open file!');
  }
}
