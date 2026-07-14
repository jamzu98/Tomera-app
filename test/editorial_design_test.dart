import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomera/core/theme.dart';
import 'package:tomera/core/widgets/editorial.dart';
import 'package:tomera/core/widgets/form_group.dart';
import 'package:tomera/core/widgets/section_header.dart';
import 'package:tomera/core/widgets/soft_tile.dart';
import 'package:tomera/features/settings/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fonts = FontLoader(bodyFontFamily)
      ..addFont(rootBundle.load('assets/fonts/HankenGrotesk-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/HankenGrotesk-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/HankenGrotesk-Bold.ttf'));
    await fonts.load();
  });

  test('themes expose the editorial monochrome design tokens', () {
    final dark = buildDarkTheme();
    final light = buildLightTheme();
    final darkTokens = dark.extension<TomeraTokens>()!;
    final lightTokens = light.extension<TomeraTokens>()!;

    expect(light.colorScheme.surface, const Color(0xFFF5F5F3));
    expect(light.colorScheme.surfaceContainer, const Color(0xFFFFFFFF));
    expect(light.colorScheme.primary, const Color(0xFF141515));
    expect(lightTokens.dockBackground, const Color(0xFF171918));
    expect(lightTokens.dockSelected, Colors.white);

    expect(dark.colorScheme.surface, const Color(0xFF101111));
    expect(dark.colorScheme.surfaceContainer, const Color(0xFF191B1B));
    expect(dark.colorScheme.primary, const Color(0xFFF5F5F3));
    expect(darkTokens.dockBackground, const Color(0xFFF1F1EF));
    expect(darkTokens.warning, const Color(0xFFC5A56D));

    for (final theme in [dark, light]) {
      expect(theme.textTheme.headlineLarge?.fontFamily, bodyFontFamily);
      expect(theme.textTheme.headlineLarge?.fontSize, 28);
      expect(
        theme.navigationBarTheme.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysHide,
      );
      expect(theme.navigationBarTheme.height, 68);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.floatingActionButtonTheme.elevation, 8);
      expect(theme.dialogTheme.elevation, 16);
      expect(theme.bottomSheetTheme.modalElevation, 16);
    }
  });

  test(
    'new installs start light and stored theme choices remain intact',
    () async {
      SharedPreferences.setMockInitialValues({});
      final fresh = ProviderContainer();
      expect(fresh.read(themeModeSettingProvider), ThemeMode.light);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fresh.read(themeModeSettingProvider), ThemeMode.light);
      fresh.dispose();

      SharedPreferences.setMockInitialValues({
        'settings.themeMode': ThemeMode.dark.name,
      });
      final returning = ProviderContainer();
      expect(returning.read(themeModeSettingProvider), ThemeMode.light);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(returning.read(themeModeSettingProvider), ThemeMode.dark);
      returning.dispose();
    },
  );

  for (final (name, theme) in [
    ('dark', buildDarkTheme()),
    ('light', buildLightTheme()),
  ]) {
    testWidgets('editorial component gallery matches $name reference', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(411, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_Gallery(theme: theme));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/editorial_design_$name.png'),
      );
    });
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const _GalleryScaffold(),
    );
  }
}

class _GalleryScaffold extends StatelessWidget {
  const _GalleryScaffold();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Quick add',
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.dockBackground,
            borderRadius: BorderRadius.circular(36),
            boxShadow: editorialShadow(context, strong: true),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(36),
            clipBehavior: Clip.antiAlias,
            child: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today_rounded),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Calendar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.work_outline_rounded),
                  label: 'Work',
                ),
                NavigationDestination(
                  icon: Icon(Icons.group_outlined),
                  label: 'Contacts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.euro_outlined),
                  label: 'Finance',
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 96),
        children: [
          const EditorialScreenHeader(
            title: 'Today',
            subtitle: 'Tuesday, July 14',
          ),
          EditorialFeaturedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Up next', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Prepare project proposal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Today · Studio',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Open task'),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Upcoming work'),
          const EditorialPanel(
            children: [
              SoftTile(
                embedded: true,
                margin: EdgeInsets.zero,
                leading: _ShapeMark(),
                title: Text('Review client notes'),
                subtitle: Text('Tomorrow · Studio'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
              SoftTile(
                embedded: true,
                margin: EdgeInsets.zero,
                leading: _ShapeMark(),
                title: Text('Send invoice'),
                subtitle: Text('Friday · Finance'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Tasks')),
                ButtonSegment(value: 1, label: Text('Projects')),
                ButtonSegment(value: 2, label: Text('Notes')),
              ],
              selected: const {0},
              onSelectionChanged: (_) {},
            ),
          ),
          const FormGroupCard(
            title: 'Details',
            children: [
              FormFieldRow(
                icon: Icons.schedule_outlined,
                label: 'Schedule',
                child: Text('Today, 2:00 PM'),
              ),
              FormFieldRow(
                icon: Icons.work_outline_rounded,
                label: 'Workspace',
                child: Text('Studio'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShapeMark extends StatelessWidget {
  const _ShapeMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Icon(Icons.check_rounded, size: 19),
  );
}
