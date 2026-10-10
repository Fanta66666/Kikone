import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/l10n/app_localizations.dart';
import 'package:kikoeru_flutter/src/widgets/main_bottom_navigation_bar.dart';
import 'package:kikoeru_flutter/src/widgets/main_navigation_destinations.dart';

/// 验证 iOS 三入口结构。
///
/// 关键点：这些断言在 Linux/macOS 的 CI 运行器上同样成立，因为被测代码使用
/// `defaultTargetPlatform`，可以被 [debugDefaultTargetPlatformOverride] 覆盖。
/// 如果改回 `dart:io` 的 `Platform.isIOS`，本文件的 iOS 用例会全部失败——
/// 这正是我们希望 CI 能守住的行为。
void main() {
  final zh = lookupS(const Locale('zh'));

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('useIOSNavigationStructure', () {
    test('iOS 平台启用三入口结构', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(useIOSNavigationStructure(), isTrue);
    });

    test('其他平台保持四入口结构', () {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          useIOSNavigationStructure(),
          isFalse,
          reason: '$platform 不应启用 iOS 结构',
        );
      }
    });
  });

  group('buildMainDestinations', () {
    test('iOS 结构恰好三个入口，顺序为 在线 / 本地 / 喜爱', () {
      final destinations = buildMainDestinations(
        s: zh,
        useIOSStructure: true,
        showUpdateBadge: false,
      );

      expect(destinations.length, 3);
      expect(
        destinations.map((d) => d.label).toList(),
        ['在线', '本地', '喜爱'],
      );
    });

    test('非 iOS 结构保持原有四个入口', () {
      final destinations = buildMainDestinations(
        s: zh,
        useIOSStructure: false,
        showUpdateBadge: false,
      );

      expect(destinations.length, 4);
      expect(
        destinations.map((d) => d.label).toList(),
        ['主页', '搜索', '我的', '设置'],
      );
    });

    test('iOS 结构下设置不再占用导航入口（已移到右上角）', () {
      final destinations = buildMainDestinations(
        s: zh,
        useIOSStructure: true,
        showUpdateBadge: true,
      );

      expect(destinations.map((d) => d.label), isNot(contains('设置')));
    });

    test('iOS 结构下搜索不占用导航入口（已并入在线页）', () {
      final destinations = buildMainDestinations(
        s: zh,
        useIOSStructure: true,
        showUpdateBadge: false,
      );

      expect(destinations.map((d) => d.label), isNot(contains('搜索')));
    });
  });

  group('导航图标表', () {
    test('iOS 图标表为三项，且顺序与三入口一致', () {
      expect(kIOSNavIcons.length, 3);
      expect(kIOSNavIcons[0].icon, Icons.public_outlined);
      expect(kIOSNavIcons[1].icon, Icons.folder_outlined);
      expect(kIOSNavIcons[2].icon, Icons.favorite_border);
    });

    test('iOS 图标表长度与 iOS 导航项数量匹配，避免沿用旧索引', () {
      final destinations = buildMainDestinations(
        s: zh,
        useIOSStructure: true,
        showUpdateBadge: false,
      );
      expect(kIOSNavIcons.length, destinations.length);
    });

    test('旧图标表仍为四项，保证非 iOS 行为不变', () {
      final destinations = buildMainDestinations(
        s: zh,
        useIOSStructure: false,
        showUpdateBadge: false,
      );
      expect(kLegacyNavIcons.length, 4);
      expect(kLegacyNavIcons.length, destinations.length);
    });

    test('每个图标项都提供 SF Symbol，供液态玻璃导航使用', () {
      for (final item in [...kIOSNavIcons, ...kLegacyNavIcons]) {
        expect(item.sfSymbol, isNotEmpty);
        expect(item.selectedSfSymbol, isNotEmpty);
      }
    });
  });
}
