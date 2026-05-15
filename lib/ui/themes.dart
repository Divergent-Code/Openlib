// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:google_fonts/google_fonts.dart';

// Project imports:
import 'package:openlib/ui/extensions.dart';

final secondaryColor = '#FB0101'.toColor();

ThemeData lightTheme = ThemeData(
  primaryColor: Colors.white,
  colorScheme: ColorScheme.light(
    primary: Colors.white,
    secondary: secondaryColor,
    tertiary: Colors.black,
    tertiaryContainer: '#F2F2F2'.toColor(),
    error: Colors.red,
    surfaceContainer: Colors.grey.shade200,
    outline: Colors.grey,
    surface: Colors.white,
  ),
  textTheme: TextTheme(
      displayLarge: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 21,
      ),
      displayMedium: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.black,
        overflow: TextOverflow.ellipsis,
      ),
      headlineMedium: TextStyle(
        color: "#595E60".toColor(),
      ),
      headlineSmall: TextStyle(
        color: "#7F7F7F".toColor(),
      )),
  fontFamily: GoogleFonts.nunito().fontFamily,
  useMaterial3: true,
  textSelectionTheme: TextSelectionThemeData(
    selectionColor: secondaryColor,
    selectionHandleColor: secondaryColor,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey, width: 2),
      borderRadius: BorderRadius.all(Radius.circular(50)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2),
      borderRadius: BorderRadius.all(Radius.circular(50)),
    ),
    filled: true,
    fillColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: '#F2F2F2'.toColor(),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  ),
);

ThemeData darkTheme = ThemeData(
  primaryColor: Colors.black,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: ColorScheme.dark(
    primary: Colors.black,
    secondary: secondaryColor,
    tertiary: Colors.white,
    tertiaryContainer: '#141414'.toColor(),
    error: Colors.red.shade400,
    surfaceContainer: '#1C1C1C'.toColor(),
    outline: Colors.grey.shade700,
    surface: Colors.black,
  ),
  textTheme: TextTheme(
    displayLarge: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 21,
    ),
    displayMedium: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      overflow: TextOverflow.ellipsis,
    ),
    headlineMedium: TextStyle(
      color: "#F5F5F5".toColor(),
    ),
    headlineSmall: TextStyle(
      color: "#E8E2E2".toColor(),
    ),
  ),
  fontFamily: GoogleFonts.nunito().fontFamily,
  useMaterial3: true,
  textSelectionTheme: TextSelectionThemeData(
    selectionColor: secondaryColor,
    selectionHandleColor: secondaryColor,
  ),
  inputDecorationTheme: InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(50)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white, width: 2),
      borderRadius: BorderRadius.all(Radius.circular(50)),
    ),
    filled: true,
    fillColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: '#141414'.toColor(),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.black,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  ),
);
