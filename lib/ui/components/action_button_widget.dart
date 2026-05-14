import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/services/annas_archive.dart' show BookInfoData;
import 'package:openlib/ui/components/file_buttons_widget.dart';
import 'package:openlib/ui/components/snack_bar_widget.dart';
import 'package:openlib/ui/webview_page.dart';
import 'package:openlib/controllers/download_controller.dart';
import 'package:openlib/state/state.dart'
    show
        totalFileSizeInBytes,
        downloadedFileSizeInBytes,
        downloadProgressProvider,
        getTotalFileSize,
        getDownloadedFileSize,
        cancelCurrentDownload,
        mirrorStatusProvider,
        ProcessState,
        CheckSumProcessState,
        downloadState,
        checkSumState,
        checkIdExists;

class ActionButtonWidget extends ConsumerStatefulWidget {
  const ActionButtonWidget({super.key, required this.data});
  final BookInfoData data;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ActionButtonWidgetState();
}

class _ActionButtonWidgetState extends ConsumerState<ActionButtonWidget> {
  @override
  Widget build(BuildContext context) {
    final isBookExist = ref.watch(checkIdExists(widget.data.md5));

    return isBookExist.when(
      data: (isExists) {
        if (isExists) {
          return FileOpenAndDeleteButtons(
            id: widget.data.md5,
            format: widget.data.format!,
            onDelete: () async {
              await Future.delayed(const Duration(seconds: 1));
              // ignore: unused_result
              ref.refresh(checkIdExists(widget.data.md5));
            },
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(top: 21, bottom: 21),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.start, // Aligns buttons properly
              children: [
                // Button for "Add To My Library"
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    if (widget.data.mirror != null &&
                        widget.data.mirror != '') {
                      final result = await Navigator.push(context,
                          MaterialPageRoute(builder: (BuildContext context) {
                        return Webview(url: widget.data.mirror ?? '');
                      }));

                      if (result != null) {
                        await downloadFileWidget(
                            ref, context, widget.data, result);
                      }
                    } else {
                      showSnackBar(
                          context: context, message: 'No mirrors available!');
                    }
                  },
                  child: const Text('Add To My Library'),
                )
              ],
            ),
          );
        }
      },
      error: (error, stackTrace) {
        return Text(error.toString());
      },
      loading: () {
        return CircularProgressIndicator(
          color: Theme.of(context).colorScheme.secondary,
          strokeCap: StrokeCap.round,
        );
      },
    );
  }
}

Future<void> downloadFileWidget(WidgetRef ref, BuildContext context,
    BookInfoData data, List<String> mirrors) async {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ShowDialog(title: data.title);
      });

  DownloadController.startDownload(
    ref: ref,
    data: data,
    mirrors: mirrors,
    onSuccess: () {
      // ignore: use_build_context_synchronously
      showSnackBar(context: context, message: 'Book has been downloaded!');
    },
    onFail: (String msg) {
      Navigator.of(context).pop();
      // ignore: use_build_context_synchronously
      showSnackBar(context: context, message: msg);
    },
  );
}

class _ShowDialog extends ConsumerWidget {
  final String title;

  const _ShowDialog({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadProgress = ref.watch(downloadProgressProvider);
    final fileSize = ref.watch(getTotalFileSize);
    final downloadedFileSize = ref.watch(getDownloadedFileSize);
    final mirrorStatus = ref.watch(mirrorStatusProvider);
    final downloadProcessState = ref.watch(downloadState);
    final checkSumVerifyState = ref.watch(checkSumState);

    if (downloadProgress == 1.0 &&
        (checkSumVerifyState == CheckSumProcessState.failed ||
            checkSumVerifyState == CheckSumProcessState.success)) {
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pop();
        if (checkSumVerifyState == CheckSumProcessState.failed) {
          _showWarningFileDialog(context);
        }
      });
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Container(
            width: double.infinity,
            height: 345,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Theme.of(context).colorScheme.tertiaryContainer,
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      "Downloading Book",
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.tertiary,
                          decoration: TextDecoration.none),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .tertiary
                              .withAlpha(170),
                          decoration: TextDecoration.none),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          mirrorStatus
                              ? const Icon(
                                  Icons.check_circle,
                                  size: 15,
                                  color: Colors.green,
                                )
                              : SizedBox(
                                  width: 9,
                                  height: 9,
                                  child: CircularProgressIndicator(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    strokeWidth: 2.5,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                          const SizedBox(
                            width: 3,
                          ),
                          Text(
                            "Checking mirror availability",
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withAlpha(140),
                                decoration: TextDecoration.none),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            textAlign: TextAlign.start,
                          ),
                        ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          switch (downloadProcessState) {
                            ProcessState.waiting => Icon(
                                Icons.timer_sharp,
                                size: 15,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withAlpha(140),
                              ),
                            ProcessState.running => SizedBox(
                                width: 9,
                                height: 9,
                                child: CircularProgressIndicator(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  strokeWidth: 2.5,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            ProcessState.complete => const Icon(
                                Icons.check_circle,
                                size: 15,
                                color: Colors.green,
                              ),
                          },
                          const SizedBox(
                            width: 3,
                          ),
                          Text(
                            "Downloading",
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withAlpha(140),
                                decoration: TextDecoration.none),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            textAlign: TextAlign.start,
                          ),
                        ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          switch (checkSumVerifyState) {
                            CheckSumProcessState.waiting => Icon(
                                Icons.timer_sharp,
                                size: 15,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withAlpha(140),
                              ),
                            CheckSumProcessState.running => SizedBox(
                                width: 9,
                                height: 9,
                                child: CircularProgressIndicator(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  strokeWidth: 2.5,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            CheckSumProcessState.failed => const Icon(
                                Icons.close,
                                size: 15,
                                color: Colors.red,
                              ),
                            CheckSumProcessState.success => const Icon(
                                Icons.check_circle,
                                size: 15,
                                color: Colors.green,
                              ),
                          },
                          const SizedBox(
                            width: 3,
                          ),
                          Text(
                            "Verifying file checksum",
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withAlpha(140),
                                decoration: TextDecoration.none),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            textAlign: TextAlign.start,
                          ),
                        ]),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '$downloadedFileSize/$fileSize',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                              decoration: TextDecoration.none,
                              letterSpacing: 1),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(50)),
                      child: LinearProgressIndicator(
                        color: Theme.of(context).colorScheme.secondary,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .tertiary
                            .withAlpha(50),
                        value: downloadProgress,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              )),
                          onPressed: () {
                            ref.read(cancelCurrentDownload).cancel();
                            Navigator.of(context).pop();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(3.0),
                            child: Text('Cancel'),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showWarningFileDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          'Checksum failed!',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
              decoration: TextDecoration.none,
              letterSpacing: 1),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(
                'The downloaded book may be malicious. Delete it and get the same book from another source, or use the book at your own risk.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.tertiary.withAlpha(170),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              'Okay',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                  decoration: TextDecoration.none,
                  letterSpacing: 1),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}