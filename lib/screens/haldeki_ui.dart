// lib/ui/haldeki_ui.dart
import 'package:flutter/material.dart';

class HaldekiUI {
  /// Genel köşe yarıçapı
  static const radius = 14.0;

  // -------------------- COLOR SCHEMES --------------------

  /// Açık tema için Haldeki renk şeması
  static ColorScheme lightScheme(BuildContext context) {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF062F22), // koyu kartgreen
      onPrimary: Colors.white,
      secondary: Color(0xFF10B981),
      onSecondary: Colors.white,
      error: Color(0xFFEF4444),
      onError: Colors.white,
      surface: Color(0xFFF9FAFB),
      onSurface: Color(0xFF0B1220),
      tertiary: Color(0xFF64748B),
      onTertiary: Colors.white,
      outline: Color(0xFFE5E7EB),
      outlineVariant: Color(0xFFD9DEE6),
      shadow: Colors.black12,
      scrim: Colors.black54,
      surfaceContainerHighest: Color(0xFFF9FAFB),
      surfaceContainerLow: Color(0xFFF9FAFB),
      surfaceContainer: Color(0xFFF9FAFB),
    );
  }

  // -------------------- INPUTS / TABLES --------------------

  /// Hafif yoğun inputlar
  static InputDecorationTheme inputDense(BuildContext context) =>
      InputDecorationTheme(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.4,
          ),
        ),
      );

  /// DataTable için zebra/hover dostu tema
  static DataTableThemeData dataTableTheme(ColorScheme cs) {
    return DataTableThemeData(
      headingRowColor: MaterialStatePropertyAll(cs.primary.withOpacity(.04)),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: .2,
        fontSize: 12.5,
      ),
      dataTextStyle: const TextStyle(fontSize: 13.5),
      dividerThickness: .6,
      columnSpacing: 28,
      horizontalMargin: 10,
      headingRowHeight: 42,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 52,
    );
  }

  // -------------------- SURFACE / CARDS --------------------

  /// Kart
  static Card card(BuildContext ctx, {required Widget child, EdgeInsets? p}) {
    final cs = Theme.of(ctx).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(padding: p ?? const EdgeInsets.all(16), child: child),
    );
  }

  // -------------------- BADGE / CHIPS --------------------

  /// Rozet
  static Widget badge(BuildContext ctx, String text,
      {IconData? icon, Color? color}) {
    final cs = Theme.of(ctx).colorScheme;
    final c = color ?? cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  /// Dikdörtgen (oval kenarlı) seçenek — `FilterChip` alternatifidir.
  /// Hover/pressed efektleri eklenmiştir.
  static Widget rectOption({
    required BuildContext context,
    required String text,
    required bool selected,
    required VoidCallback onTap,
    IconData? iconWhenSelected = Icons.check,
    double height = 38,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16),
    double borderRadius = 12,
  }) {
    final cs = Theme.of(context).colorScheme;

    final bg = selected ? cs.primary.withOpacity(.10) : cs.surface;
    final bd = selected ? cs.primary : cs.outlineVariant;
    final fg = selected ? cs.onSurface : cs.tertiary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: cs.primary.withOpacity(.08),
        hoverColor: cs.primary.withOpacity(.05),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: bd, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(iconWhenSelected, size: 16, color: cs.primary),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(fontWeight: FontWeight.w600, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- BUTTON THEMES --------------------

  /// Tüm butonları oval-dikdörtgen stilde toplayan tema
  static ThemeData withRectButtons(BuildContext context, ColorScheme cs) {
    final shape12 =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Theme.of(context).copyWith(
      colorScheme: cs,
      // Inputs
      inputDecorationTheme: inputDense(context),

      // Filled / Outlined / Text buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape12,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape12,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shape12,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: shape12,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),

      // Chips (FilterChip vs kullandığın yerler için)
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: cs.outlineVariant),
        selectedColor: cs.primary.withOpacity(.10),
        backgroundColor: cs.surface,
        labelStyle: TextStyle(color: cs.tertiary),
        secondaryLabelStyle: TextStyle(color: cs.onSurface),
      ),
    );
  }

  /// Oval geri butonu (pill)
  static Widget backPillButton(BuildContext context, {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap ?? () => Navigator.of(context).maybePop(),
      icon: Icon(Icons.arrow_back_rounded, size: 18, color: cs.primary),
      label: Text('Geri', style: TextStyle(color: cs.primary)),
      style: OutlinedButton.styleFrom(
        backgroundColor: cs.surface,
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  // -------------------- MINI UI PARÇALARI --------------------

  /// Bölüm başlığı (solunda renk şeridi)
  static Widget sectionHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 6,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
