import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 是否启用 iOS 三入口结构（在线 / 本地 / 喜爱）。
///
/// 刻意使用 [defaultTargetPlatform] 而不是 `dart:io` 的 `Platform.isIOS`：
/// 前者可以在测试中通过 `debugDefaultTargetPlatformOverride` 覆盖，
/// 从而让 CI 的单元测试真正执行 iOS 分支；后者读的是宿主真实系统，无法模拟。
/// 真机上两者取值一致，运行时行为不变。
bool useIOSNavigationStructure() =>
    defaultTargetPlatform == TargetPlatform.iOS;

/// 构建主壳导航项。
///
/// 抽成纯函数以便在单元测试中直接验证「iOS 三入口 / 非 iOS 四入口」
/// 两个分支，无需构建整个 MainScreen。
List<NavigationDestination> buildMainDestinations({
  required S s,
  required bool useIOSStructure,
  required bool showUpdateBadge,
}) {
  if (useIOSStructure) {
    return [
      NavigationDestination(
        icon: const Icon(Icons.public_outlined),
        selectedIcon: const Icon(Icons.public),
        label: s.navOnline,
      ),
      NavigationDestination(
        icon: const Icon(Icons.folder_outlined),
        selectedIcon: const Icon(Icons.folder),
        label: s.navLocal,
      ),
      NavigationDestination(
        icon: const Icon(Icons.favorite_border),
        selectedIcon: const Icon(Icons.favorite),
        label: s.navFavorites,
      ),
    ];
  }

  return [
    NavigationDestination(
      icon: const Icon(Icons.home_outlined),
      selectedIcon: const Icon(Icons.home),
      label: s.navHome,
    ),
    NavigationDestination(
      icon: const Icon(Icons.search_outlined),
      selectedIcon: const Icon(Icons.search),
      label: s.navSearch,
    ),
    NavigationDestination(
      icon: const Icon(Icons.favorite_border),
      selectedIcon: const Icon(Icons.favorite),
      label: s.navMy,
    ),
    NavigationDestination(
      icon: Badge(
        isLabelVisible: showUpdateBadge,
        child: const Icon(Icons.settings_outlined),
      ),
      selectedIcon: Badge(
        isLabelVisible: showUpdateBadge,
        child: const Icon(Icons.settings),
      ),
      label: s.navSettings,
    ),
  ];
}
