import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/widgets/buff_chip.dart';
import 'package:gocalgo/config/theme.dart';

/// Verifies acceptance criterion for story US-GCG-7:
/// "Active buffs are prominently displayed (2× candy and bonus XP etc)"
///
/// Tests that BuffChip and BuffChipList widgets render buff information
/// prominently with category-specific styling, icons, and readable text.
void main() {
  Widget buildChip(Buff buff) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(child: BuffChip(buff: buff)),
      ),
    );
  }

  Widget buildChipList(List<Buff> buffs) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: BuffChipList(buffs: buffs),
      ),
    );
  }

  const multiplierBuff = Buff(
    text: '2× Catch Stardust',
    iconUrl: 'https://example.com/stardust.png',
    category: BuffCategory.multiplier,
    multiplier: 2.0,
    resource: 'Stardust',
  );

  const durationBuff = Buff(
    text: '3-hour Incense',
    iconUrl: 'https://example.com/incense.png',
    category: BuffCategory.duration,
    resource: 'Incense',
  );

  const probabilityBuff = Buff(
    text: 'Increased Shiny rate',
    category: BuffCategory.probability,
  );

  const tradeBuff = Buff(
    text: '½ Trade Stardust cost',
    category: BuffCategory.trade,
    resource: 'Stardust',
  );

  const otherBuff = Buff(
    text: 'Extra Raid Pass',
    category: BuffCategory.other,
    disclaimer: 'Up to 5 free passes',
  );

  group('BuffChip', () {
    testWidgets('displays buff text', (tester) async {
      await tester.pumpWidget(buildChip(multiplierBuff));

      expect(find.text('2× Catch Stardust'), findsOneWidget);
    });

    testWidgets('displays a category icon', (tester) async {
      await tester.pumpWidget(buildChip(multiplierBuff));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(Icons.trending_up));
    });

    testWidgets('uses bold/semi-bold text for prominence', (tester) async {
      await tester.pumpWidget(buildChip(multiplierBuff));

      final text = tester.widget<Text>(find.text('2× Catch Stardust'));
      expect(text.style?.fontWeight, equals(FontWeight.w600));
    });

    testWidgets('multiplier buff has green styling', (tester) async {
      await tester.pumpWidget(buildChip(multiplierBuff));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BuffChip),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFE8F5E9)));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, equals(const Color(0xFF2E7D32)));
    });

    testWidgets('duration buff has orange styling', (tester) async {
      await tester.pumpWidget(buildChip(durationBuff));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BuffChip),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFFFF3E0)));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(Icons.timer));
    });

    testWidgets('probability buff has pink styling', (tester) async {
      await tester.pumpWidget(buildChip(probabilityBuff));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BuffChip),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFFCE4EC)));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(Icons.auto_awesome));
    });

    testWidgets('trade buff has purple styling', (tester) async {
      await tester.pumpWidget(buildChip(tradeBuff));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BuffChip),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFEDE7F6)));
    });

    testWidgets('other buff has grey styling', (tester) async {
      await tester.pumpWidget(buildChip(otherBuff));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BuffChip),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFF5F5F5)));
    });

    testWidgets('chip has rounded corners for pill shape', (tester) async {
      await tester.pumpWidget(buildChip(multiplierBuff));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BuffChip),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        equals(BorderRadius.circular(16)),
      );
    });

    testWidgets('each category has a unique icon', (tester) async {
      final icons = <IconData>{};
      for (final cat in BuffCategory.values) {
        icons.add(BuffCategoryStyle.icon(cat));
      }
      expect(icons.length, equals(BuffCategory.values.length));
    });

    testWidgets('each category has a unique background colour', (tester) async {
      final colours = <Color>{};
      for (final cat in BuffCategory.values) {
        colours.add(BuffCategoryStyle.color(cat));
      }
      expect(colours.length, equals(BuffCategory.values.length));
    });
  });

  group('BuffChipList', () {
    testWidgets('renders all buffs when multiple are provided', (tester) async {
      await tester.pumpWidget(buildChipList([
        multiplierBuff,
        durationBuff,
        probabilityBuff,
      ]));

      expect(find.byType(BuffChip), findsNWidgets(3));
      expect(find.text('2× Catch Stardust'), findsOneWidget);
      expect(find.text('3-hour Incense'), findsOneWidget);
      expect(find.text('Increased Shiny rate'), findsOneWidget);
    });

    testWidgets('renders nothing when buffs list is empty', (tester) async {
      await tester.pumpWidget(buildChipList([]));

      expect(find.byType(BuffChip), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('uses Wrap for multi-line layout', (tester) async {
      await tester.pumpWidget(buildChipList([
        multiplierBuff,
        durationBuff,
        probabilityBuff,
        tradeBuff,
        otherBuff,
      ]));

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(BuffChip), findsNWidgets(5));
    });

    testWidgets('chips have spacing between them', (tester) async {
      await tester.pumpWidget(buildChipList([
        multiplierBuff,
        durationBuff,
      ]));

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, equals(8));
      expect(wrap.runSpacing, equals(6));
    });

    testWidgets('single buff is displayed prominently', (tester) async {
      await tester.pumpWidget(buildChipList([multiplierBuff]));

      expect(find.byType(BuffChip), findsOneWidget);
      expect(find.text('2× Catch Stardust'), findsOneWidget);

      // Verify the chip is visible and has styling
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(Icons.trending_up));
      expect(icon.color, equals(const Color(0xFF2E7D32)));
    });
  });

  group('BuffCategoryStyle', () {
    test('all categories have opaque background colours', () {
      for (final cat in BuffCategory.values) {
        final bg = BuffCategoryStyle.color(cat);
        expect(bg.alpha, equals(255), reason: '${cat.name} background must be opaque');
      }
    });

    test('all categories have opaque foreground colours', () {
      for (final cat in BuffCategory.values) {
        final fg = BuffCategoryStyle.foreground(cat);
        expect(fg.alpha, equals(255), reason: '${cat.name} foreground must be opaque');
      }
    });

    test('foreground is darker than background for readability', () {
      for (final cat in BuffCategory.values) {
        final bg = BuffCategoryStyle.color(cat);
        final fg = BuffCategoryStyle.foreground(cat);
        // Foreground luminance should be lower (darker) for contrast
        expect(
          fg.computeLuminance(),
          lessThan(bg.computeLuminance()),
          reason: '${cat.name} foreground must be darker than background',
        );
      }
    });
  });
}
