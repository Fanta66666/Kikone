import 'package:flutter/material.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

import 'liquid_glass_layout.dart';

/// 液态玻璃导航项的显式图标配置。
///
/// 显式传入可避免「只改标签、图标仍按旧索引硬编码」的问题，
/// 例如 iOS 三入口结构下本地/喜爱会错误沿用搜索/设置图标。
class MainBottomNavIcons {
  const MainBottomNavIcons({
    required this.icon,
    required this.selectedIcon,
    required this.sfSymbol,
    required this.selectedSfSymbol,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String sfSymbol;
  final String selectedSfSymbol;
}

/// 旧的四入口图标（主页 / 搜索 / 我的 / 设置）。
const List<MainBottomNavIcons> kLegacyNavIcons = [
  MainBottomNavIcons(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    sfSymbol: 'house',
    selectedSfSymbol: 'house.fill',
  ),
  MainBottomNavIcons(
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    sfSymbol: 'magnifyingglass',
    selectedSfSymbol: 'magnifyingglass',
  ),
  MainBottomNavIcons(
    icon: Icons.favorite_border,
    selectedIcon: Icons.favorite,
    sfSymbol: 'heart',
    selectedSfSymbol: 'heart.fill',
  ),
  MainBottomNavIcons(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    sfSymbol: 'gearshape',
    selectedSfSymbol: 'gearshape.fill',
  ),
];

/// iOS 三入口图标（在线 / 本地 / 喜爱）。
const List<MainBottomNavIcons> kIOSNavIcons = [
  MainBottomNavIcons(
    icon: Icons.public_outlined,
    selectedIcon: Icons.public,
    sfSymbol: 'globe',
    selectedSfSymbol: 'globe',
  ),
  MainBottomNavIcons(
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
    sfSymbol: 'folder',
    selectedSfSymbol: 'folder.fill',
  ),
  MainBottomNavIcons(
    icon: Icons.favorite_border,
    selectedIcon: Icons.favorite,
    sfSymbol: 'heart',
    selectedSfSymbol: 'heart.fill',
  ),
];

class MainBottomNavigationBar extends StatelessWidget {
  const MainBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.miniPlayer = const SizedBox.shrink(),
    this.liquidGlass = false,
    this.fallbackGlassTransparency = 0.4,
    this.showUpdateBadge = false,
    this.onLayoutExtentChanged,
    this.itemIcons,
    this.updateBadgeIndex,
  });

  static const double navigationBarHeight = 58;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget miniPlayer;
  final bool liquidGlass;
  final double fallbackGlassTransparency;
  final bool showUpdateBadge;
  final ValueChanged<double>? onLayoutExtentChanged;

  /// 显式图标配置，长度应与 [destinations] 对应。
  final List<MainBottomNavIcons>? itemIcons;

  /// 更新红点落点索引；传 null 表示落在最后一项，传负数表示不显示。
  final int? updateBadgeIndex;

  @override
  Widget build(BuildContext context) {
    if (liquidGlass) {
      return _LiquidGlassBottomNavigation(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        miniPlayer: miniPlayer,
        fallbackGlassTransparency: fallbackGlassTransparency,
        showUpdateBadge: showUpdateBadge,
        onLayoutExtentChanged: onLayoutExtentChanged,
        itemIcons: itemIcons,
        updateBadgeIndex: updateBadgeIndex,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        miniPlayer,
        NavigationBar(
          height: navigationBarHeight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      ],
    );
  }
}

class _LiquidGlassBottomNavigation extends StatelessWidget {
  const _LiquidGlassBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.miniPlayer,
    required this.fallbackGlassTransparency,
    required this.showUpdateBadge,
    required this.onLayoutExtentChanged,
    this.itemIcons,
    this.updateBadgeIndex,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget miniPlayer;
  final double fallbackGlassTransparency;
  final bool showUpdateBadge;
  final ValueChanged<double>? onLayoutExtentChanged;
  final List<MainBottomNavIcons>? itemIcons;
  final int? updateBadgeIndex;

  List<MainBottomNavIcons> get _items {
    final provided = itemIcons;
    if (provided != null) return provided;
    // 未显式提供时按旧的四入口图标表回退，保持既有平台行为不变。
    return kLegacyNavIcons;
  }

  List<LiquidGlassBarItem> _itemsForDestinations() {
    final items = _items;
    return [
      for (var index = 0; index < destinations.length; index++)
        LiquidGlassBarItem(
          icon: index < items.length
              ? items[index].icon
              : Icons.circle_outlined,
          selectedIcon: index < items.length
              ? items[index].selectedIcon
              : Icons.circle,
          sfSymbol: index < items.length ? items[index].sfSymbol : 'circle',
          selectedSfSymbol: index < items.length
              ? items[index].selectedSfSymbol
              : 'circle.fill',
          label: destinations[index].label,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final navigationBarHeight = LiquidGlassLayout.navigationBarHeight(context);
    return LiquidGlassDockExtentReporter(
      onChanged: onLayoutExtentChanged ?? (_) {},
      child: Padding(
        padding: EdgeInsets.only(
          bottom: LiquidGlassLayout.dockBottomInset(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: miniPlayer,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LiquidGlassLayout.horizontalPadding,
                LiquidGlassLayout.verticalPadding,
                LiquidGlassLayout.horizontalPadding,
                LiquidGlassLayout.navigationBarBottomPadding,
              ),
              child: SizedBox(
                height: navigationBarHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final expansion = LiquidGlassLayout.nativeTabBarExpansion(
                      context,
                    );
                    final barWidth = constraints.maxWidth + expansion * 2;
                    final bar = ClipRRect(
                      borderRadius: BorderRadius.circular(
                        navigationBarHeight / 2,
                      ),
                      child: SizedBox(
                        width: barWidth,
                        child: LiquidGlassBottomBar(
                          items: _itemsForDestinations(),
                          currentIndex: selectedIndex,
                          onTap: onDestinationSelected,
                          height: navigationBarHeight,
                          showLabels: true,
                          tint: Theme.of(context).colorScheme.primary,
                          fallbackIntensity: fallbackGlassTransparency,
                        ),
                      ),
                    );

                    final expandedBar = expansion == 0
                        ? bar
                        : OverflowBox(
                            minWidth: barWidth,
                            maxWidth: barWidth,
                            minHeight: navigationBarHeight,
                            maxHeight: navigationBarHeight,
                            alignment: Alignment.center,
                            child: bar,
                          );

                    final badgeIndex =
                        updateBadgeIndex ?? (destinations.length - 1);
                    if (!showUpdateBadge ||
                        destinations.isEmpty ||
                        badgeIndex < 0 ||
                        badgeIndex >= destinations.length) {
                      return expandedBar;
                    }

                    final itemWidth = barWidth / destinations.length;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        expandedBar,
                        Positioned(
                          top: 10,
                          left: itemWidth * (badgeIndex + 0.5) - 4,
                          child: IgnorePointer(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
