import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/providers/constants.dart';

final cookieProvider = StateProvider<String>((ref) => "");
final userAgentProvider = StateProvider<String>((ref) => "");
final webViewLoadingState = StateProvider.autoDispose<bool>((ref) => true);
final downloadProgressProvider = StateProvider.autoDispose<double>((ref) => 0.0);
final mirrorStatusProvider = StateProvider.autoDispose<bool>((ref) => false);
final totalFileSizeInBytes = StateProvider.autoDispose<int>((ref) => 0);
final downloadedFileSizeInBytes = StateProvider.autoDispose<int>((ref) => 0);
final downloadState = StateProvider.autoDispose<ProcessState>((ref) => ProcessState.waiting);
final checkSumState = StateProvider.autoDispose<CheckSumProcessState>((ref) => CheckSumProcessState.waiting);
final cancelCurrentDownload = StateProvider<CancelToken>((ref) {
  return CancelToken();
});

String bytesToFileSize(int bytes) {
  const int decimals = 1;
  const suffixes = ["b", " Kb", "Mb", "Gb", "Tb"];
  if (bytes == 0) return '0${suffixes[0]}';
  var i = (log(bytes) / log(1024)).floor();
  return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + suffixes[i];
}

final getTotalFileSize = StateProvider.autoDispose<String>((ref) {
  return bytesToFileSize(ref.watch(totalFileSizeInBytes));
});

final getDownloadedFileSize = StateProvider.autoDispose<String>((ref) {
  return bytesToFileSize(ref.watch(downloadedFileSizeInBytes));
});
