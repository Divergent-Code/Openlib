import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/state/state.dart';
import 'package:openlib/ui/categories_page.dart';
import 'package:openlib/ui/components/page_title_widget.dart';
import 'package:openlib/ui/components/pellet_container.dart';
import 'package:openlib/ui/trending_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final List<Widget> _pages = const [
    TrendingPage(),
    GenresPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(homePageSelectedIndexProvider);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5, right: 5, top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TitleText(selectedIndex == 0 ? "Trending" : "Genres"),
                PelletContainer(
                  selectedIndex: selectedIndex,
                  onTrendingSelected: () => {
                    ref.read(homePageSelectedIndexProvider.notifier).state = 0
                  },
                  onCategoriesSelected: () => {
                    ref.read(homePageSelectedIndexProvider.notifier).state = 1
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _pages[selectedIndex]), // Display the selected page
        ],
      ),
    );
  }
}

