import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../screens/settings_screen.dart';

/// 主壳右上角的设置入口。
///
/// 复用既有 [SettingsScreen]，并在进入前刷新设置缓存，
/// 保留原有的更新红点提示行为。
class MainSettingsAction extends ConsumerWidget {
  const MainSettingsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showUpdateBadge = ref.watch(showUpdateRedDotProvider);
    final s = S.of(context);

    return IconButton(
      tooltip: s.navSettings,
      onPressed: () {
        ref.read(settingsCacheRefreshTriggerProvider.notifier).state++;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      },
      icon: Badge(
        isLabelVisible: showUpdateBadge,
        child: const Icon(Icons.settings_outlined),
      ),
    );
  }
}
