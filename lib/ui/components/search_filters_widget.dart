import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openlib/providers/constants.dart';
import 'package:openlib/providers/search_providers.dart';

class SearchFiltersWidget extends ConsumerWidget {
  const SearchFiltersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersProvider);
    final dropdownTypeValue = filters.selectedType;
    final dropdownSortValue = filters.selectedSort;
    final dropDownFileTypeValue = filters.selectedFileType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 7, right: 7, top: 19),
          child: SizedBox(
            width: 250,
            child: DropdownButtonFormField(
              decoration: InputDecoration(
                labelText: 'Type',
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              icon: const Icon(Icons.arrow_drop_down),
              value: dropdownTypeValue,
              items: typeValues.keys
                  .toList()
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
              onChanged: (String? val) {
                ref.read(searchFiltersProvider.notifier).setType(val ?? 'All');
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 7, right: 7, top: 19),
          child: SizedBox(
            width: 210,
            child: DropdownButtonFormField(
              decoration: InputDecoration(
                labelText: 'Sort by',
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              value: dropdownSortValue,
              items: sortValues.keys
                  .toList()
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
              onChanged: (String? val) {
                ref.read(searchFiltersProvider.notifier).setSort(val ?? 'Most Relevant');
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 7, right: 7, top: 19),
          child: SizedBox(
            width: 165,
            child: DropdownButtonFormField(
              decoration: InputDecoration(
                labelText: 'File type',
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              value: dropDownFileTypeValue,
              items: fileType.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
              onChanged: (String? val) {
                ref.read(searchFiltersProvider.notifier).setFileType(val ?? 'All');
              },
            ),
          ),
        ),
      ],
    );
  }
}
