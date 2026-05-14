import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedIndexProvider = StateProvider<int>((ref) => 0);
final homePageSelectedIndexProvider = StateProvider<int>((ref) => 0);
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
