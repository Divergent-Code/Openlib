// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import 'package:openlib/ui/components/error_widget.dart';
import 'package:openlib/ui/results_page.dart';
import 'package:openlib/ui/components/book_grid_item.dart';

import 'package:openlib/state/state.dart'
    show getTrendingBooks, searchFiltersProvider;

class TrendingPage extends ConsumerWidget {
  const TrendingPage({super.key});

  final double imageHeight = 145;
  final double imageWidth = 105;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingBooks = ref.watch(getTrendingBooks);
    return trendingBooks.when(
        skipLoadingOnRefresh: false,
        data: (data) {
          return Padding(
            padding: const EdgeInsets.only(left: 5, right: 5, top: 10),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(5),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10.0,
                      crossAxisSpacing: 13.0,
                      mainAxisExtent: 205,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        return BookGridItem(
                          title: data[index].title!,
                          thumbnail: data[index].thumbnail!,
                          imageHeight: imageHeight,
                          imageWidth: imageWidth,
                          onTap: () {
                            ref.read(searchFiltersProvider.notifier).disableFilters();
                            Navigator.push(context, MaterialPageRoute(
                                builder: (BuildContext context) {
                              return ResultPage(
                                  searchQuery: data[index].title!);
                            }));
                          },
                        );
                      },
                      childCount: data.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        error: (error, _) {
          return CustomErrorWidget(
            error: error,
            stackTrace: _,
            onRefresh: () {
              // ignore: unused_result
              ref.refresh(getTrendingBooks);
            },
          );
        },
        loading: () {
          return Center(
              child: SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.secondary,
              strokeCap: StrokeCap.round,
            ),
          ));
        });
  }
}