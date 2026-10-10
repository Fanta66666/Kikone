import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_library.dart';
import '../services/audio_import_service.dart';
import '../services/device_library_service.dart';

/// 设备本地资料库状态：统一收藏 + 导入音频索引。
class DeviceLibraryState extends Equatable {
  final List<DeviceFavorite> favorites;
  final List<ImportedAudio> imports;
  final bool isLoading;
  final bool isImporting;

  const DeviceLibraryState({
    this.favorites = const [],
    this.imports = const [],
    this.isLoading = false,
    this.isImporting = false,
  });

  DeviceLibraryState copyWith({
    List<DeviceFavorite>? favorites,
    List<ImportedAudio>? imports,
    bool? isLoading,
    bool? isImporting,
  }) {
    return DeviceLibraryState(
      favorites: favorites ?? this.favorites,
      imports: imports ?? this.imports,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
    );
  }

  bool isFavorite(String key) => favorites.any((item) => item.key == key);

  DeviceFavorite? favoriteOf(String key) {
    for (final item in favorites) {
      if (item.key == key) return item;
    }
    return null;
  }

  @override
  List<Object?> get props => [favorites, imports, isLoading, isImporting];
}

class DeviceLibraryNotifier extends StateNotifier<DeviceLibraryState> {
  DeviceLibraryNotifier() : super(const DeviceLibraryState()) {
    refresh();
  }

  void refresh() {
    state = state.copyWith(
      favorites: DeviceLibraryService.favorites(),
      imports: DeviceLibraryService.imports(),
      isLoading: false,
    );
  }

  /// 切换收藏状态。返回 true 表示当前处于已收藏。
  Future<bool> toggleFavorite(DeviceFavorite favorite) async {
    final wasFavorite = state.isFavorite(favorite.key);
    if (wasFavorite) {
      await DeviceLibraryService.removeFavorite(favorite.key);
      refresh();
      return false;
    }
    await DeviceLibraryService.setFavorite(favorite);
    refresh();
    return true;
  }

  Future<void> removeFavorite(String key) async {
    await DeviceLibraryService.removeFavorite(key);
    refresh();
  }

  /// 弹出系统文件选择器并导入音频，返回本次结果（用户取消时 cancelled 为 true）。
  Future<AudioImportResult> importAudio() async {
    if (state.isImporting) return AudioImportResult.empty;
    state = state.copyWith(isImporting: true);
    try {
      final result = await AudioImportService.pickAndImport();
      refresh();
      return result;
    } finally {
      if (mounted) {
        state = state.copyWith(isImporting: false);
      }
    }
  }

  Future<void> deleteImport(ImportedAudio audio) async {
    await AudioImportService.deleteImport(audio);
    refresh();
  }

  /// 导入副本是否仍可播放。
  Future<bool> isImportAvailable(ImportedAudio audio) {
    return DeviceLibraryService.importFileExists(audio);
  }
}

final deviceLibraryProvider =
    StateNotifierProvider<DeviceLibraryNotifier, DeviceLibraryState>((ref) {
  return DeviceLibraryNotifier();
});
