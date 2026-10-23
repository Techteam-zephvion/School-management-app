import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolic/src/core/fluid_ui.dart';
import 'package:schoolic/src/features/shared/components/empty_state_view.dart';

void main() {
  group('Fluid UI Primitives & Mascot Integration', () {
    testWidgets('FluidPressable renders child and executes onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluidPressable(
                onTap: () => tapped = true,
                child: const Text('Press Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Press Me'), findsOneWidget);

      // Verify tapDown triggers scale change
      final gesture = await tester.startGesture(tester.getCenter(find.text('Press Me')));
      await tester.pump(const Duration(milliseconds: 50));

      final animatedScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animatedScale.scale, lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      final restoredScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(restoredScale.scale, equals(1.0));
    });

    testWidgets('FluidDoubleBezel renders outer and inner containers concentrically', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidDoubleBezel(
              outerRadius: 24,
              innerRadius: 20,
              child: Text('Bezel Content'),
            ),
          ),
        ),
      );

      expect(find.text('Bezel Content'), findsOneWidget);
      expect(find.byType(FluidDoubleBezel), findsOneWidget);
    });

    testWidgets('FluidIslandButton renders label and nested trailing icon', (tester) async {
      bool clicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluidIslandButton(
                label: 'Enter Terminal',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => clicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Enter Terminal'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      await tester.tap(find.text('Enter Terminal'));
      await tester.pumpAndSettle();

      expect(clicked, isTrue);
    });

    testWidgets('FluidGlassBar renders translucent bar with safe area', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: FluidGlassBar(
              child: Center(child: Text('Glass Header')),
            ),
            body: SizedBox(),
          ),
        ),
      );

      expect(find.text('Glass Header'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('FluidMascotInsignia renders Lord Espandor seal and opens briefing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluidMascotInsignia(size: 28),
            ),
          ),
        ),
      );

      expect(find.byType(FluidMascotInsignia), findsOneWidget);

      // Tap on the seal to open executive briefing
      await tester.tap(find.byType(FluidMascotInsignia));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears with Lord Espandor title and briefing
      expect(find.text('Lord Espandor'), findsOneWidget);
      expect(find.text('Design Deck'), findsOneWidget);
      expect(find.text('Command Palette'), findsOneWidget);
    });

    testWidgets('FluidInteractiveCard renders content and handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FluidInteractiveCard(
                onTap: () => tapped = true,
                child: const Text('Interactive Card Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Interactive Card Content'), findsOneWidget);
      await tester.tap(find.text('Interactive Card Content'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('FluidSegmentedControl switches tabs smoothly', (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: FluidSegmentedControl<int>(
                    selectedValue: selected,
                    onValueChanged: (val) => setState(() => selected = val),
                    children: const {
                      0: Text('First'),
                      1: Text('Second'),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(selected, equals(0));

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(selected, equals(1));
    });

    testWidgets('EmptyStateView renders mascot placeholder when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              title: 'All Clear, Principal',
              description: 'No exceptions or pending approvals for today.',
              useMascot: true,
            ),
          ),
        ),
      );

      expect(find.text('All Clear, Principal'), findsOneWidget);
      expect(find.text('No exceptions or pending approvals for today.'), findsOneWidget);
      // Mascot mode renders circular decorated container without default inbox icon
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    });
  });
}
