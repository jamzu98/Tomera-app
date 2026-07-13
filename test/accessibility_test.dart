import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/theme.dart';
import 'package:tomera/core/widgets/empty_state.dart';
import 'package:tomera/core/widgets/status_ring.dart';

void main() {
  for (final width in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          'shared controls meet accessibility rules at ${width.toInt()}dp, '
          '${scale}x, ${brightness.name}',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final theme = brightness == Brightness.dark
                ? buildDarkTheme()
                : buildLightTheme();

            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Column(
                    children: [
                      Expanded(
                        child: EmptyState(
                          icon: Icons.task_alt_rounded,
                          title: 'Keep work moving',
                          body:
                              'Create a task and add a due date when it matters.',
                          primaryAction: EmptyStateAction(
                            label: 'Create task',
                            onPressed: () {},
                          ),
                        ),
                      ),
                      StatusRing(
                        icon: Icons.check_rounded,
                        color: theme.colorScheme.primary,
                        size: 30,
                        tooltip: 'Complete task',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          },
        );
      }
    }
  }
}
