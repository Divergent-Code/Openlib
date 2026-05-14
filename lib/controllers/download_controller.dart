import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/services/annas_archive.dart' show BookInfoData;
import 'package:openlib/services/database.dart';
import 'package:openlib/services/download_file.dart';
import 'package:openlib/state/state.dart';

class DownloadController {
  static Future<void> startDownload({
    required WidgetRef ref,
    required BookInfoData data,
    required List<String> mirrors,
    required void Function() onSuccess,
    required void Function(String error) onFail,
  }) async {
    downloadFile(
      mirrors: mirrors,
      md5: data.md5,
      format: data.format!,
      onStart: () {
        ref.read(downloadState.notifier).state = ProcessState.running;
      },
      onProgress: (int rcv, int total) async {
        if (ref.read(totalFileSizeInBytes) != total) {
          ref.read(totalFileSizeInBytes.notifier).state = total;
        }
        ref.read(downloadedFileSizeInBytes.notifier).state = rcv;
        ref.read(downloadProgressProvider.notifier).state = rcv / total;

        if (rcv / total == 1.0) {
          MyLibraryDb dataBase = MyLibraryDb.instance;

          await dataBase.insert(MyBook(
              id: data.md5,
              title: data.title,
              author: data.author,
              thumbnail: data.thumbnail,
              link: data.link,
              publisher: data.publisher,
              info: data.info,
              format: data.format,
              description: data.description));

          ref.read(downloadState.notifier).state = ProcessState.complete;
          ref.read(checkSumState.notifier).state = CheckSumProcessState.running;

          try {
            final checkSum = await verifyFileCheckSum(
                md5Hash: data.md5, format: data.format!);
            if (checkSum == true) {
              ref.read(checkSumState.notifier).state =
                  CheckSumProcessState.success;
            } else {
              ref.read(checkSumState.notifier).state =
                  CheckSumProcessState.failed;
            }
          } catch (_) {
            ref.read(checkSumState.notifier).state =
                CheckSumProcessState.failed;
          }
          
          // ignore: unused_result
          ref.refresh(checkIdExists(data.md5));
          // ignore: unused_result
          ref.refresh(myLibraryProvider);
          
          onSuccess();
        }
      },
      cancelDownlaod: (CancelToken downloadToken) {
        ref.read(cancelCurrentDownload.notifier).state = downloadToken;
      },
      mirrorStatus: (val) {
        ref.read(mirrorStatusProvider.notifier).state = val;
      },
      onDownlaodFailed: (msg) {
        onFail(msg.toString());
      },
    );
  }
}
