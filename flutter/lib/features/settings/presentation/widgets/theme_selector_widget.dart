import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_themes.dart';
import '../../../../shared/providers/theme_provider.dart';

/// Theme selector widget matching web app's ThemeSelector component
class ThemeSelectorWidget extends ConsumerWidget {
  final bool compact;

  const ThemeSelectorWidget({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeId = ref.watch(themeIdProvider);
    final currentMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (compact) {
      return _buildCompactSelector(context, ref, currentThemeId, currentMode, colorScheme);
    }

    return _buildFullSelector(context, ref, currentThemeId, currentMode, colorScheme);
  }

  Widget _buildCompactSelector(
    BuildContext context,
    WidgetRef ref,
    String currentThemeId,
    ThemeMode currentMode,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode selector
        _buildModeRow(ref, currentMode, colorScheme),
        const SizedBox(height: 16),
        // Theme grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: AppThemes.all.length,
          itemBuilder: (context, index) {
            final appTheme = AppThemes.all[index];
            final isSelected = appTheme.id == currentThemeId;
            return _buildThemeCircle(
              context,
              ref,
              appTheme,
              isSelected,
              colorScheme,
            );
          },
        ),
      ],
    );
  }

  Widget _buildFullSelector(
    BuildContext context,
    WidgetRef ref,
    String currentThemeId,
    ThemeMode currentMode,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your preferred color theme and mode',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 24),
            // Mode section
            Text(
              'Mode',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildModeRow(ref, currentMode, colorScheme),
            const SizedBox(height: 24),
            // Theme section
            Text(
              'Color Theme',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: AppThemes.all.length,
                itemBuilder: (context, index) {
                  final appTheme = AppThemes.all[index];
                  final isSelected = appTheme.id == currentThemeId;
                  return _buildThemeCard(
                    context,
                    ref,
                    appTheme,
                    isSelected,
                    colorScheme,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeRow(WidgetRef ref, ThemeMode currentMode, ColorScheme colorScheme) {
    return Row(
      children: [
        _buildModeButton(
          ref,
          ThemeMode.light,
          currentMode,
          Icons.light_mode_outlined,
          'Light',
          colorScheme,
        ),
        const SizedBox(width: 8),
        _buildModeButton(
          ref,
          ThemeMode.dark,
          currentMode,
          Icons.dark_mode_outlined,
          'Dark',
          colorScheme,
        ),
        const SizedBox(width: 8),
        _buildModeButton(
          ref,
          ThemeMode.system,
          currentMode,
          Icons.settings_suggest_outlined,
          'System',
          colorScheme,
        ),
      ],
    );
  }

  Widget _buildModeButton(
    WidgetRef ref,
    ThemeMode mode,
    ThemeMode currentMode,
    IconData icon,
    String label,
    ColorScheme colorScheme,
  ) {
    final isSelected = mode == currentMode;
    return Expanded(
      child: Material(
        color: isSelected
            ? colorScheme.primary.withOpacity(0.15)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCircle(
    BuildContext context,
    WidgetRef ref,
    AppThemeData appTheme,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    final brightness = Theme.of(context).brightness;
    final scheme = brightness == Brightness.dark
        ? appTheme.darkScheme
        : appTheme.lightScheme;

    return Tooltip(
      message: appTheme.name,
      child: GestureDetector(
        onTap: () => ref.read(themeIdProvider.notifier).setTheme(appTheme.id),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.tertiary,
                ],
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Center(
                    child: Icon(
                      Icons.check,
                      color: scheme.onPrimary,
                      size: 16,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    WidgetRef ref,
    AppThemeData appTheme,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    final brightness = Theme.of(context).brightness;
    final scheme = brightness == Brightness.dark
        ? appTheme.darkScheme
        : appTheme.lightScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(themeIdProvider.notifier).setTheme(appTheme.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              // Color preview
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        scheme.tertiary,
                        scheme.secondary,
                      ],
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: scheme.onPrimary.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: scheme.primary,
                              size: 16,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              // Name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(11),
                  ),
                ),
                child: Text(
                  appTheme.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
