import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

import '../../l10n/app_localizations.dart';
import '../providers/audio_provider.dart';
import '../providers/update_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/main_bottom_navigation_bar.dart';
import '../widgets/main_navigation_destinations.dart';
import '../widgets/mini_player.dart';
import '../widgets/liquid_glass_layout.dart';
import '../widgets/main_settings_action.dart';
import 'works_screen.dart';
import 'search_screen.dart';
import 'my_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'local_library_screen.dart';
import 'device_favorites_screen.dart';
import '../providers/settings_provider.dart';

/// iOS 三入口结构：在线 / 本地 / 喜爱；其他平台保持原有四入口。
///
/// 判定逻辑见 [useIOSNavigationStructure]，刻意做成可被测试覆盖的形式。
bool get _useIOSStructure => useIOSNavigationStructure();

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _currentIndex;
  static const int _settingsTabIndex = 3;

  /// iOS 上设置不再占用主入口，改为各页右上角入口。
  bool get _hasSettingsTab => !_useIOSStructure;

  // 使用 PageStorageBucket 来保存页面状态
  final PageStorageBucket _bucket = PageStorageBucket();
  final ValueNotifier<double> _liquidDockExtent = ValueNotifier(0);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // iOS 无账号时默认落在「本地」；已有账号默认「在线」。
    final hasAccount = ref.read(authProvider).currentUser != null;
    _currentIndex = _useIOSStructure ? (hasAccount ? 0 : 1) : 0;
    _screens = _useIOSStructure
        ? const [
            _OnlineTab(key: PageStorageKey('online_tab')),
            LocalLibraryScreen(key: PageStorageKey('local_library_screen')),
            DeviceFavoritesScreen(key: PageStorageKey('favorites_screen')),
          ]
        : const [
            WorksScreen(key: PageStorageKey('works_screen')),
            SearchScreen(key: PageStorageKey('search_screen')),
            MyScreen(key: PageStorageKey('my_screen')),
            SettingsScreen(key: PageStorageKey('settings_screen')),
          ];
  }

  @override
  void dispose() {
    _liquidDockExtent.dispose();
    super.dispose();
  }

  List<NavigationDestination> _buildDestinations(
      BuildContext context, bool showUpdateBadge) {
    return buildMainDestinations(
      s: S.of(context),
      useIOSStructure: _useIOSStructure,
      showUpdateBadge: showUpdateBadge,
    );
  }

  void _handleDestinationSelected(int index) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    if (_hasSettingsTab && index == _settingsTabIndex) {
      ref.read(settingsCacheRefreshTriggerProvider.notifier).state++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final showUpdateBadge = ref.watch(showUpdateRedDotProvider);
    final useLiquidGlass = ref.watch(liquidGlassNavigationProvider);
    final destinations = _buildDestinations(context, showUpdateBadge);

    if (isLandscape) {
      // 横屏布局：使用 NavigationRail
      final landscapeScaffold = Scaffold(
        body: Stack(
          children: [
            // 主内容区域
            Row(
              children: [
                // 侧边导航栏
                SafeArea(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: useLiquidGlass
                              ? const EdgeInsets.all(8)
                              : EdgeInsets.zero,
                          child: useLiquidGlass
                              ? Consumer(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: _buildNavigationRail(destinations),
                                  ),
                                  builder: (context, ref, child) {
                                    return LiquidGlassContainer(
                                      shape: const LiquidGlassShape
                                          .roundedRectangle(28),
                                      fallbackIntensity: ref.watch(
                                        fallbackGlassTransparencyProvider,
                                      ),
                                      child: child,
                                    );
                                  },
                                )
                              : _buildNavigationRail(destinations),
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // 页面内容
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final authState = ref.watch(authProvider);
                      final isOfflineMode = authState.currentUser != null &&
                          !authState.isLoggedIn &&
                          authState.error != null;

                      final pages = PageStorage(
                        bucket: _bucket,
                        child: IndexedStack(
                          index: _currentIndex,
                          children: List.generate(_screens.length, (index) {
                            return HeroMode(
                              enabled: index == _currentIndex,
                              child: _screens[index],
                            );
                          }),
                        ),
                      );
                      final miniPlayer = Consumer(
                        builder: (context, ref, child) {
                          final currentTrack = ref.watch(currentTrackProvider);
                          return currentTrack.when(
                            data: (track) => track != null
                                ? const MiniPlayer()
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
                      );

                      final content = useLiquidGlass
                          ? LiquidGlassDockOverlay(
                              onExtentChanged: (extent) {
                                if (_liquidDockExtent.value != extent) {
                                  _liquidDockExtent.value = extent;
                                }
                              },
                              dock: AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.bottomCenter,
                                child: miniPlayer,
                              ),
                              child: pages,
                            )
                          : Column(
                              children: [
                                Expanded(child: pages),
                                miniPlayer,
                              ],
                            );

                      return Padding(
                        padding: EdgeInsets.only(top: isOfflineMode ? 30 : 0),
                        child: SafeArea(
                          top: false,
                          bottom: !useLiquidGlass,
                          child: content,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // 离线模式提示横幅（覆盖在顶部）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Consumer(
                builder: (context, ref, child) {
                  final authState = ref.watch(authProvider);
                  final isOfflineMode = authState.currentUser != null &&
                      !authState.isLoggedIn &&
                      authState.error != null;

                  if (!isOfflineMode) {
                    return const SizedBox.shrink();
                  }

                  final topPadding = MediaQuery.of(context).padding.top;

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(12, topPadding + 4, 12, 4),
                    color: Colors.orange.shade800,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            S.of(context).offlineModeMessage,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final notifier = ref.read(authProvider.notifier);
                            await notifier.retryConnection();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            S.of(context).retry,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
      return useLiquidGlass
          ? LiquidGlassDockScope(
              notifier: _liquidDockExtent,
              child: landscapeScaffold,
            )
          : landscapeScaffold;
    }

    // 竖屏布局：液态玻璃模式把导航栏悬浮在页面内容上方，经典模式
    // 继续使用 Scaffold 的 bottomNavigationBar 插槽。
    final miniPlayer = Consumer(
      builder: (context, ref, child) {
        final currentTrack = ref.watch(currentTrackProvider);
        return currentTrack.when(
          data: (track) =>
              track != null ? const MiniPlayer() : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
    final bottomNavigation = Consumer(
      child: miniPlayer,
      builder: (context, ref, child) {
        return MainBottomNavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _handleDestinationSelected,
          destinations: destinations,
          liquidGlass: useLiquidGlass,
          fallbackGlassTransparency:
              ref.watch(fallbackGlassTransparencyProvider),
          showUpdateBadge: showUpdateBadge,
          // iOS 三入口使用独立图标表；设置已移到右上角，红点不再落在导航栏。
          itemIcons: _useIOSStructure ? kIOSNavIcons : kLegacyNavIcons,
          updateBadgeIndex: _useIOSStructure ? -1 : null,
          onLayoutExtentChanged: (extent) {
            if (_liquidDockExtent.value != extent) {
              _liquidDockExtent.value = extent;
            }
          },
          miniPlayer: child!,
        );
      },
    );

    final portraitScaffold = Scaffold(
      body: Stack(
        children: [
          // 主内容
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authProvider);
              final isOfflineMode = authState.currentUser != null &&
                  !authState.isLoggedIn &&
                  authState.error != null;

              return Padding(
                padding: EdgeInsets.only(top: isOfflineMode ? 30 : 0),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: LiquidGlassDockMediaQuery(
                    child: PageStorage(
                      bucket: _bucket,
                      child: IndexedStack(
                        index: _currentIndex,
                        children: List.generate(_screens.length, (index) {
                          return HeroMode(
                            enabled: index == _currentIndex,
                            child: _screens[index],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // 离线模式提示横幅（覆盖在顶部）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(authProvider);
                final isOfflineMode = authState.currentUser != null &&
                    !authState.isLoggedIn &&
                    authState.error != null;

                if (!isOfflineMode) {
                  return const SizedBox.shrink();
                }

                final topPadding = MediaQuery.of(context).padding.top;

                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(12, topPadding + 4, 12, 4),
                  color: Colors.orange.shade800,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          S.of(context).offlineModeMessage,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final notifier = ref.read(authProvider.notifier);
                          await notifier.retryConnection();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          S.of(context).retry,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (useLiquidGlass)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: bottomNavigation,
            ),
        ],
      ),
      bottomNavigationBar: useLiquidGlass ? null : bottomNavigation,
    );
    return useLiquidGlass
        ? LiquidGlassDockScope(
            notifier: _liquidDockExtent,
            child: portraitScaffold,
          )
        : portraitScaffold;
  }

  Widget _buildNavigationRail(List<NavigationDestination> destinations) {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _handleDestinationSelected,
      labelType: NavigationRailLabelType.selected,
      destinations: destinations
          .map((dest) => NavigationRailDestination(
                icon: dest.icon,
                selectedIcon: dest.selectedIcon,
                label: Text(dest.label),
              ))
          .toList(),
    );
  }
}

/// iOS「在线」入口。
///
/// 未登录（无任何账户）时只展示登录引导，避免 IndexedStack 预构建
/// 在线页面而在无会话状态下触发在线接口。
class _OnlineTab extends ConsumerWidget {
  const _OnlineTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.currentUser != null) {
      return const WorksScreen(key: PageStorageKey('works_screen'));
    }

    return const _OnlineLoginPrompt();
  }
}

class _OnlineLoginPrompt extends StatelessWidget {
  const _OnlineLoginPrompt();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.navOnline),
        actions: const [MainSettingsAction()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 12),
              Text(
                s.offlineModeMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(Icons.login),
                label: Text(s.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
