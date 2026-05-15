import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/models/book.dart' show BookInfoData;
import 'package:openlib/ui/components/file_buttons_widget.dart';
import 'package:openlib/ui/components/snack_bar_widget.dart';
import 'package:openlib/ui/webview_page.dart';
import 'package:openlib/state/state.dart'
    show
        DownloadState,
        DownloadStatus,
        ChecksumStatus,
        downloadNotifierProvider,
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
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
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
                        if (!context.mounted) return;
                        await _downloadFileWidget(
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

Future<void> _downloadFileWidget(WidgetRef ref, BuildContext context,
    BookInfoData data, List<String> mirrors) async {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ShowDialog(title: data.title, data: data, mirrors: mirrors);
      });
}

class _ShowDialog extends ConsumerWidget {
  final String title;
  final BookInfoData data;
  final List<String> mirrors;

  const _ShowDialog({
    required this.title,
    required this.data,
    required this.mirrors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadNotifierProvider);
    final task = downloadState.tasks[data.md5];
    final notifier = ref.read(downloadNotifierProvider.notifier);

    // Enqueue if not present
    if (task == null) {
      Future.microtask(
          () => notifier.enqueueDownload(data: data, mirrors: mirrors));
    }

    // Listen to changes for THIS task to handle completion/failure popups
    ref.listen<DownloadState>(downloadNotifierProvider, (prev, next) {
      final t = next.tasks[data.md5];
      if (t == null) return;

      final isDone = t.status == DownloadStatus.complete &&
          (t.checksumStatus == ChecksumStatus.success ||
              t.checksumStatus == ChecksumStatus.failed);

      if (isDone) {
        Future.delayed(const Duration(seconds: 1), () {
          if (!context.mounted) return;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          notifier.dismissTask(data.md5);
          if (t.checksumStatus == ChecksumStatus.failed) {
            _showWarningFileDialog(context);
          } else {
            showSnackBar(
                context: context, message: 'Book has been downloaded!');
          }
        });
      }

      if (t.status == DownloadStatus.failed) {
        if (!context.mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        notifier.dismissTask(data.md5);
        showSnackBar(
            context: context,
            message: t.errorMessage ?? 'Download failed.');
      }
    });

    if (task == null) {
      return const SizedBox(); // Wait for enqueue
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
                  // Mirror check row
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          task.isMirrorActive
                              ? const Icon(Icons.check_circle,
                                  size: 15, color: Colors.green)
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
                          const SizedBox(width: 3),
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
                  // Download progress row
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          switch (task.status) {
                            DownloadStatus.pending => Icon(
                                Icons.queue_sharp,
                                size: 15,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withAlpha(140),
                              ),
                            DownloadStatus.running => SizedBox(
                                width: 9,
                                height: 9,
                                child: CircularProgressIndicator(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  strokeWidth: 2.5,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            DownloadStatus.paused => const Icon(
                                Icons.pause_circle,
                                size: 15,
                                color: Colors.orange),
                            DownloadStatus.complete ||
                            DownloadStatus.failed =>
                              const Icon(Icons.check_circle,
                                  size: 15, color: Colors.green),
                            DownloadStatus.canceled => const Icon(
                                Icons.cancel,
                                size: 15,
                                color: Colors.grey),
                          },
                          const SizedBox(width: 3),
                          Text(
                            task.status == DownloadStatus.pending
                                ? "Queued for download"
                                : "Downloading file",
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
                  // Checksum row
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          switch (task.checksumStatus) {
                            ChecksumStatus.idle => Icon(
                                Icons.timer_sharp,
                                size: 15,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withAlpha(140),
                              ),
                            ChecksumStatus.running => SizedBox(
                                width: 9,
                                height: 9,
                                child: CircularProgressIndicator(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  strokeWidth: 2.5,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            ChecksumStatus.failed => const Icon(Icons.close,
                                size: 15, color: Colors.red),
                            ChecksumStatus.success => const Icon(
                                Icons.check_circle,
                                size: 15,
                                color: Colors.green),
                          },
                          const SizedBox(width: 3),
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
                  // Byte counters
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '${task.formattedDownloadedBytes}/${task.formattedTotalBytes}',
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
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(50)),
                      child: LinearProgressIndicator(
                        color: Theme.of(context).colorScheme.secondary,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .tertiary
                            .withAlpha(50),
                        value: task.progress,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  // Buttons row
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8)),
                          onPressed: () {
                            // Dismiss dialog, leave download running in queue
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(
                            'Run in Background',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withAlpha(180)),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8)),
                          onPressed: () {
                            notifier.cancelDownload(data.md5);
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ),
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
                  color:
                      Theme.of(context).colorScheme.tertiary.withAlpha(170),
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