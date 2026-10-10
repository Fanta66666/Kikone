import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/device_library.dart';
import 'device_library_service.dart';
import 'log_service.dart';

/// 单次导入的汇总结果。
class AudioImportResult {
  final bool cancelled;
  final int imported;
  final List<String> errors;

  const AudioImportResult({
    this.cancelled = false,
    this.imported = 0,
    this.errors = const [],
  });

  bool get hasFailures => errors.isNotEmpty;

  static const AudioImportResult empty = AudioImportResult();
}

/// 本地音频导入服务。
///
/// 首版范围：通过系统文件选择器多选「直接音频文件」，复制到应用持久目录后登记索引。
/// 不处理压缩包 / 文件夹 / 视频，不扫描设备，不联网补全元数据。
class AudioImportService {
  AudioImportService._();

  /// 首版支持的扩展名白名单（实际能否解码仍由播放器决定）。
  static const List<String> allowedExtensions = ['mp3', 'm4a', 'aac', 'wav'];

  static final Random _random = Random.secure();

  static String _newId() {
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  /// 弹出系统文件选择器并导入所选音频。
  ///
  /// 用户取消时不做任何写入。
  static Future<AudioImportResult> pickAndImport() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: false,
      );
    } catch (error) {
      logOutput('[AudioImport] 打开文件选择器失败: $error');
      return AudioImportResult(errors: ['无法打开文件选择器：$error']);
    }

    if (picked == null || picked.files.isEmpty) {
      return const AudioImportResult(cancelled: true);
    }

    var imported = 0;
    final errors = <String>[];

    for (final file in picked.files) {
      final sourcePath = file.path;
      if (sourcePath == null || sourcePath.isEmpty) {
        errors.add('${file.name}：无法读取文件路径');
        continue;
      }
      try {
        await _importSingle(
          sourcePath: sourcePath,
          displayName: file.name,
        );
        imported++;
      } catch (error) {
        errors.add('${file.name}：${_describe(error)}');
      }
    }

    return AudioImportResult(imported: imported, errors: errors);
  }

  static String _describe(Object error) {
    if (error is ImportFailure) return error.message;
    return '$error';
  }

  static Future<void> _importSingle({
    required String sourcePath,
    required String displayName,
  }) async {
    final extension = p.extension(displayName).replaceFirst('.', '').toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw ImportFailure('不支持的文件类型');
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw ImportFailure('文件不存在或无法访问');
    }

    final size = await source.length();
    if (size <= 0) {
      throw ImportFailure('文件为空');
    }

    final id = _newId();
    final root = await DeviceLibraryService.rootDirectory();
    final targetDir = Directory(p.join(root.path, DeviceLibraryService.importRootName, id));
    final stagingDir = Directory(
      p.join(root.path, DeviceLibraryService.importRootName, '.staging_$id'),
    );

    // 目标文件名完全受控，不使用用户提供的文件名，避免路径穿越。
    final targetFileName = 'audio.$extension';

    try {
      await stagingDir.create(recursive: true);
      final stagedFile = File(p.join(stagingDir.path, targetFileName));
      await source.copy(stagedFile.path);

      // 校验复制结果完整后再提交。
      final copiedSize = await stagedFile.length();
      if (copiedSize != size) {
        throw ImportFailure('复制不完整');
      }

      await targetDir.parent.create(recursive: true);
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      // 同一卷内 rename，避免再次跨设备拷贝。
      await stagingDir.rename(targetDir.path);

      final relativePath = p.join(
        DeviceLibraryService.importRootName,
        id,
        targetFileName,
      );

      await DeviceLibraryService.addImport(
        ImportedAudio(
          id: id,
          title: p.basenameWithoutExtension(displayName),
          fileName: displayName,
          relativePath: relativePath,
          extension: extension,
          sizeBytes: size,
          importedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      // 任何一步失败都清理本次残留，不留下已登记的索引。
      await _safeDelete(stagingDir);
      await _safeDelete(targetDir);
      if (error is ImportFailure) rethrow;
      throw ImportFailure('导入失败：$error');
    }
  }

  static Future<void> _safeDelete(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (error) {
      logOutput('[AudioImport] 清理失败 ${dir.path}: $error');
    }
  }

  /// 删除已导入副本。只删除应用内受控副本，不触碰来源文件。
  static Future<void> deleteImport(ImportedAudio audio) async {
    // 先提交索引变更（保证收藏失效状态可见），再清理副本。
    await DeviceLibraryService.removeImport(audio.id);
    try {
      final absolute = await DeviceLibraryService.absolutePath(audio.relativePath);
      final file = File(absolute);
      if (await file.exists()) {
        await file.delete();
      }
      final parent = file.parent;
      if (await parent.exists()) {
        await parent.delete(recursive: true);
      }
    } catch (error) {
      logOutput('[AudioImport] 删除导入副本失败: $error');
    }
  }
}

/// 导入过程中可预期的失败（用于给用户明确提示）。
class ImportFailure implements Exception {
  final String message;
  ImportFailure(this.message);

  @override
  String toString() => message;
}
