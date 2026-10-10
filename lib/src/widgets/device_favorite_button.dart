import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../models/device_library.dart';
import '../providers/device_library_provider.dart';

/// 设备统一收藏（本机心形）按钮。
///
/// 与服务器 review（想听 / 在听 / 听过 / 重听 / 搁置）完全独立：
/// 不会读取或写入服务器状态，也不会触发任何网络请求。
class DeviceFavoriteButton extends ConsumerWidget {
  const DeviceFavoriteButton({
    super.key,
    required this.favorite,
    this.iconSize = 22,
    this.onChanged,
  });

  /// 收藏快照。未收藏时用于新增；已收藏时以 [DeviceFavorite.key] 为准。
  final DeviceFavorite favorite;
  final double iconSize;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref
        .watch(deviceLibraryProvider.select((s) => s.isFavorite(favorite.key)));
    final activeColor = Theme.of(context).colorScheme.error;
    final s = S.of(context);

    Future<void> handleTap() async {
      // 在异步操作前捕获依赖 context 的对象，避免跨 await 使用 context。
      final messenger = ScaffoldMessenger.maybeOf(context);
      final notifier = ref.read(deviceLibraryProvider.notifier);
      final nowFavorite = await notifier.toggleFavorite(favorite);
      onChanged?.call(nowFavorite);

      messenger?.showSnackBar(
        SnackBar(
          content: Text(nowFavorite ? s.addFavorite : s.removeFavorite),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return IconButton(
      onPressed: handleTap,
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        size: iconSize,
        color: isFavorite ? activeColor : null,
      ),
      tooltip: isFavorite ? s.removeFavorite : s.addFavorite,
      visualDensity: VisualDensity.compact,
    );
  }
}
