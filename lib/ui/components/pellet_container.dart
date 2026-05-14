import 'package:flutter/material.dart';

class PelletContainer extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onTrendingSelected;
  final VoidCallback onCategoriesSelected;

  const PelletContainer({
    super.key,
    required this.selectedIndex,
    required this.onTrendingSelected,
    required this.onCategoriesSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 105,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Theme.of(context).colorScheme.secondary,
        border: Border.all(color: Theme.of(context).colorScheme.secondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left Button (Trending)
          Expanded(
            child: GestureDetector(
              onTap: onTrendingSelected,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: selectedIndex == 0
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(25),
                    bottomLeft: Radius.circular(25),
                    topRight: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                ),
                child: TextButton.icon(
                  onPressed: null, // Disable direct onPressed to avoid conflict
                  icon: Icon(
                    Icons.trending_up,
                    color: selectedIndex == 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                  label: const Text(''), // Empty label
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(
            width: 0,
            thickness: 1,
            color: Colors.grey,
          ),
          // Right Button (Categories)
          Expanded(
            child: GestureDetector(
              onTap: onCategoriesSelected,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: selectedIndex == 1
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(0),
                    bottomLeft: Radius.circular(0),
                    topRight: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                ),
                child: TextButton.icon(
                  onPressed: null,
                  icon: Icon(
                    Icons.dashboard_rounded,
                    color: selectedIndex == 1
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                  label: const Text(''), // Empty label
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
