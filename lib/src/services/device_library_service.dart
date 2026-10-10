import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/device_library.dart';
import 'log_service.dart';

/// 设备本地资料库：统一收藏（在线 / 下载 / 导入）与导入音频索引。
///
/// 设计要点：
/// - 使用独立的 Hive box `device_library`，不放入可清理的 cache box，
///   因此切换账号、退出登录、清除缓存都不会丢失。
/// - 所有读改写通过串行队列执行，保证同一时刻只有一个事务在提交。
/// - 只保存展示快照与受控相对路径，绝不保存 token / cookie / 临时播放地址。
class DeviceLibraryService {
  DeviceLibraryService._();

  static const String _boxName = 'device_library';
  static const String _favoritesKey = 'favorites';
  static const String _importsKey = 'imports';

  /// 导入内容根目录名（相对应用持久目录）。
  static const String importRootName = 'imports';

  static Box? _box;
  static Directory? _rootDir;

  /// 串行写队列。
  static Future<void> _queue = Future<void>.value();

  static Future<void> init() async {
    if (_box != null) return;
    _box = await Hive.openBox(_boxName);
    _rootDir = await getApplicationSupportDirectory();
  }

  static Box get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('DeviceLibraryService 尚未初始化，请先调用 init()。');
    }
    return box;
  }

  /// 应用持久根目录（导入副本的相对基准）。
  static Future<Directory> rootDirectory() async {
    return _rootDir ??= await getApplicationSupportDirectory();
  }

  /// 将受控相对路径解析为绝对路径。
  static Future<String> absolutePath(String relativePath) async {
    final root = await rootDirectory();
    return p.join(root.path, relativePath);
  }

  /// 把绝对路径转换为相对应用持久根目录的受控路径。
  static Future<String> relativePathOf(String absolutePath) async {
    final root = await rootDirectory();
    final normalizedRoot = p.normalize(root.path);
    final normalized = p.normalize(absolutePath);
    if (!p.isWithin(normalizedRoot, normalized) &&
        normalized != normalizedRoot) {
      throw ArgumentError('路径不在应用持久目录内：$absolutePath');
    }
    return p.relative(normalized, from: normalizedRoot);
  }

  /// 串行执行写入事务。
  static Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // 收藏
  // ---------------------------------------------------------------------------

  static List<DeviceFavorite> _readFavorites() {
    final raw = _requireBox.get(_favoritesKey);
    if (raw is! List) return const [];
    final result = <DeviceFavorite>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          result.add(
            DeviceFavorite.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (error) {
          logOutput('[DeviceLibrary] 跳过无法解析的收藏条目: $error');
        }
      }
    }
    return result;
  }

  static List<DeviceFavorite> favorites() {
    final list = _readFavorites();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static bool isFavorite(String key) {
    return _readFavorites().any((item) => item.key == key);
  }

  static DeviceFavorite? favoriteOf(String key) {
    for (final item in _readFavorites()) {
      if (item.key == key) return item;
    }
    return null;
  }

  /// 新增或更新收藏。返回 true 表示状态发生变化。
  static Future<bool> setFavorite(DeviceFavorite favorite) {
    return _serialize(() async {
      final list = _readFavorites();
      final index = list.indexWhere((item) => item.key == favorite.key);
      if (index >= 0) {
        // 已收藏：仅刷新展示快照，保持原收藏时间。
        final merged = favorite.copyWith(
          title: favorite.title,
          coverUrl: favorite.coverUrl,
          localRelativePath: favorite.localRelativePath,
        );
        list[index] = DeviceFavorite(
          key: merged.key,
          source: merged.source,
          title: merged.title,
          coverUrl: merged.coverUrl,
          origin: merged.origin,
          remoteId: merged.remoteId,
          importId: merged.importId,
          localRelativePath: merged.localRelativePath,
          createdAt: list[index].createdAt,
        );
      } else {
        list.add(favorite);
      }
      await _requireBox.put(
        _favoritesKey,
        list.map((item) => item.toJson()).toList(),
      );
      await _requireBox.flush();
      return index < 0;
    });
  }

  static Future<bool> removeFavorite(String key) {
    return _serialize(() async {
      final list = _readFavorites();
      final before = list.length;
      list.removeWhere((item) => item.key == key);
      if (list.length == before) return false;
      await _requireBox.put(
        _favoritesKey,
        list.map((item) => item.toJson()).toList(),
      );
      await _requireBox.flush();
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // 导入音频索引
  // ---------------------------------------------------------------------------

  static List<ImportedAudio> _readImports() {
    final raw = _requireBox.get(_importsKey);
    if (raw is! List) return const [];
    final result = <ImportedAudio>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          result.add(ImportedAudio.fromJson(Map<String, dynamic>.from(item)));
        } catch (error) {
          logOutput('[DeviceLibrary] 跳过无法解析的导入条目: $error');
        }
      }
    }
    return result;
  }

  static List<ImportedAudio> imports() {
    final list = _readImports();
    list.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return list;
  }

  static ImportedAudio? importById(String id) {
    for (final item in _readImports()) {
      if (item.id == id) return item;
    }
    return null;
  }

  static Future<void> addImport(ImportedAudio audio) {
    return _serialize(() async {
      final list = _readImports();
      list.removeWhere((item) => item.id == audio.id);
      list.add(audio);
      await _requireBox.put(
        _importsKey,
        list.map((item) => item.toJson()).toList(),
      );
      await _requireBox.flush();
    });
  }

  static Future<void> removeImport(String id) {
    return _serialize(() async {
      final list = _readImports();
      list.removeWhere((item) => item.id == id);
      await _requireBox.put(
        _importsKey,
        list.map((item) => item.toJson()).toList(),
      );
      await _requireBox.flush();
    });
  }

  /// 清理未被索引引用的导入残留目录（仅限本模块的 imports 根目录）。
  static Future<void> cleanupOrphanImports() async {
    try {
      final root = await rootDirectory();
      final importRoot = Directory(p.join(root.path, importRootName));
      if (!await importRoot.exists()) return;

      final known = _readImports().map((e) => e.id).toSet();
      await for (final entity in importRoot.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (known.contains(name)) continue;
        try {
          await entity.delete(recursive: true);
          logOutput('[DeviceLibrary] 清理未登记导入目录: $name');
        } catch (error) {
          logOutput('[DeviceLibrary] 清理导入目录失败 $name: $error');
        }
      }
    } catch (error) {
      logOutput('[DeviceLibrary] 清理导入残留失败: $error');
    }
  }

  /// 校验导入副本是否仍然存在。
  static Future<bool> importFileExists(ImportedAudio audio) async {
    try {
      final absolute = await absolutePath(audio.relativePath);
      return File(absolute).exists();
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static void resetForTest(Box box) {
    _box = box;
    _queue = Future<void>.value();
  }
}
