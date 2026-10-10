import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../models/audio_tap_playlist_mode.dart';
import '../models/audio_track.dart';
import '../models/device_library.dart';
import '../providers/audio_provider.dart';
import '../providers/device_library_provider.dart';
import '../services/device_library_service.dart';
import '../widgets/device_favorite_button.dart';
import '../widgets/main_settings_action.dart';
import '../widgets/pushed_page_scaffold.dart';
import 'history_screen.dart';
import 'local_downloads_screen.dart';
import 'subtitle_library_screen.dart';

/// iOS「本地」入口：已下载作品 + 已导入音频。
class LocalLibraryScreen extends ConsumerStatefulWidget {
  const LocalLibraryScreen({super.key});

  @override
  ConsumerState<LocalLibraryScreen> createState() => _LocalLibraryScreenState();
}

class _LocalLibraryScreenState extends ConsumerState<LocalLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _handleImport() async {
    final notifier = ref.read(deviceLibraryProvider.notifier);
    final result = await notifier.importAudio();
    if (!mounted || result.cancelled) return;

    final s = S.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final buffer = StringBuffer();
    if (result.imported > 0) {
      buffer.write(s.importedNFiles(result.imported));
    }
    if (result.hasFailures) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(result.errors.join('\n'));
    }
    if (buffer.isEmpty) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(buffer.toString()),
        duration: Duration(seconds: result.hasFailures ? 5 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isImportsTab = _tabController.index == 1;
    final isImporting =
        ref.watch(deviceLibraryProvider.select((state) => state.isImporting));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navLocal),
        actions: [
          if (isImportsTab)
            IconButton(
              tooltip: s.importAudioFile,
              onPressed: isImporting ? null : _handleImport,
              icon: isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.library_add_outlined),
            ),
          IconButton(
            tooltip: s.historyRecord,
            onPressed: () => _push(
              PushedPageScaffold(
                title: s.historyRecord,
                child: const HistoryScreen(),
              ),
            ),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: s.subtitleLibrary,
            onPressed: () => _push(
              PushedPageScaffold(
                title: s.subtitleLibrary,
                child: const SubtitleLibraryScreen(),
              ),
            ),
            icon: const Icon(Icons.subtitles_outlined),
          ),
          const MainSettingsAction(),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.downloaded),
            Tab(text: s.importedAudio),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          LocalDownloadsScreen(toolbarTop: 8),
          _ImportedAudioTab(),
        ],
      ),
    );
  }
}

class _ImportedAudioTab extends ConsumerStatefulWidget {
  const _ImportedAudioTab();

  @override
  ConsumerState<_ImportedAudioTab> createState() => _ImportedAudioTabState();
}

class _ImportedAudioTabState extends ConsumerState<_ImportedAudioTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _play(ImportedAudio audio) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final absolute =
          await DeviceLibraryService.absolutePath(audio.relativePath);
      final track = AudioTrack(
        id: DeviceIdentity.imported(audio.id),
        title: audio.title,
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

  Future<void> _confirmDelete(ImportedAudio audio) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.delete),
        content: Text(s.deleteImportConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(deviceLibraryProvider.notifier).deleteImport(audio);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final imports =
        ref.watch(deviceLibraryProvider.select((state) => state.imports));

    if (imports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_music_outlined,
                size: 56,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 12),
              Text(
                s.noImportedAudio,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: imports.length,
      itemBuilder: (context, index) {
        final audio = imports[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.audiotrack)),
          title: Text(audio.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            audio.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _play(audio),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DeviceFavoriteButton(
                favorite: DeviceFavorite(
                  key: DeviceIdentity.imported(audio.id),
                  source: DeviceItemSource.imported,
                  title: audio.title,
                  importId: audio.id,
                  localRelativePath: audio.relativePath,
                  createdAt: DateTime.now(),
                ),
              ),
              IconButton(
                tooltip: s.delete,
                onPressed: () => _confirmDelete(audio),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }
}
