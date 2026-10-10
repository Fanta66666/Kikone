import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../models/audio_tap_playlist_mode.dart';
import '../models/audio_track.dart';
import '../models/device_library.dart';
import '../models/work.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/device_library_provider.dart';
import '../services/device_library_service.dart';
import '../services/kikoeru_api_service.dart';
import '../widgets/device_favorite_button.dart';
import '../widgets/main_settings_action.dart';
import 'work_detail_screen.dart';

/// iOS「喜爱」入口：在线作品、已下载作品与导入音频的统一本机收藏。
class DeviceFavoritesScreen extends ConsumerWidget {
  const DeviceFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final favorites =
        ref.watch(deviceLibraryProvider.select((state) => state.favorites));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navFavorites),
        actions: const [MainSettingsAction()],
      ),
      body: favorites.isEmpty
          ? _EmptyState(message: s.favoritesEmpty)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return _FavoriteTile(favorite: favorite);
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 56,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.favorite});

  final DeviceFavorite favorite;

  String _sourceLabel(S s) {
    switch (favorite.source) {
      case DeviceItemSource.online:
        return s.navOnline;
      case DeviceItemSource.download:
        return s.downloaded;
      case DeviceItemSource.imported:
        return s.importedAudio;
    }
  }

  Future<void> _playImported(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final relativePath = favorite.localRelativePath;
    if (relativePath == null) {
      messenger?.showSnackBar(SnackBar(content: Text(s.fileUnavailable)));
      return;
    }
    try {
      final absolute = await DeviceLibraryService.absolutePath(relativePath);
      final track = AudioTrack(
        id: favorite.key,
        title: favorite.title,
        url: Uri.file(absolute).toString(),
        sourcePath: absolute,
      );
      await ref.read(audioPlayerControllerProvider.notifier).playTracks(
            [track],
            playlistMode: AudioTapPlaylistMode.replaceQueue,
          );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('${s.fileUnavailable}: $error')),
      );
    }
  }

  Future<void> _openOnline(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final authState = ref.read(authProvider);
    final remoteId = favorite.remoteId;

    if (remoteId == null) return;

    final currentOrigin = DeviceIdentity.normalizeOrigin(authState.host);
    if (currentOrigin.isEmpty || currentOrigin != favorite.origin) {
      messenger?.showSnackBar(
        SnackBar(content: Text('${s.navOnline}: ${favorite.origin ?? ''}')),
      );
      return;
    }
    if (!authState.isLoggedIn) {
      messenger?.showSnackBar(SnackBar(content: Text(s.offlineModeMessage)));
      return;
    }

    try {
      final api = ref.read(kikoeruApiServiceProvider);
      final json = await api.getWork(remoteId);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkDetailScreen(work: Work.fromJson(json)),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final isImported = favorite.source == DeviceItemSource.imported;

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.favorite)),
      title: Text(favorite.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_sourceLabel(s)),
      onTap: () {
        if (isImported) {
          _playImported(context, ref);
        } else {
          _openOnline(context, ref);
        }
      },
      trailing: DeviceFavoriteButton(favorite: favorite),
    );
  }
}
