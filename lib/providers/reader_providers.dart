import 'package:flutter_riverpod/flutter_riverpod.dart';

final pdfCurrentPage = StateProvider.autoDispose<int>((ref) => 0);
final totalPdfPage = StateProvider.autoDispose<int>((ref) => 0);
final openPdfWithExternalAppProvider = StateProvider<bool>((ref) => false);
final openEpubWithExternalAppProvider = StateProvider<bool>((ref) => false);
