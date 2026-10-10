import 'package:equatable/equatable.dart';

/// 设备本地收藏条目的来源类型。
///
/// - [online]   在线作品（服务器作品详情）
/// - [download] 已下载作品的本机副本
/// - [imported] 从系统文件选择器导入的本地音频
enum DeviceItemSource { online, download, imported }

extension DeviceItemSourceX on DeviceItemSource {
  String get storageValue => name;

  static DeviceItemSource fromStorage(String? value) {
    return DeviceItemSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DeviceItemSource.imported,
    );
  }
}

/// 收藏身份的构造工具。
///
/// 身份键规则（跨平台稳定，不含账号信息）：
/// - 在线/已知来源下载：`remote:<规范化 origin>:<服务器作品 id>`
/// - 来源未知的旧下载：`download:<本机持久 id>`
/// - 导入音频：`import:<本机随机 id>`
///
/// 规范化 origin 只保留协议、主机与端口，不含路径、查询串或任何凭据，
/// 从而保证不同服务器上相同 workId 不会被合并。
class DeviceIdentity {
  DeviceIdentity._();

  static String remote({required String origin, required int remoteId}) =>
      'remote:${normalizeOrigin(origin)}:$remoteId';

  static String download(String persistentId) => 'download:$persistentId';

  static String imported(String importId) => 'import:$importId';

  /// 规范化服务器地址：保留 scheme / host / port，丢弃路径、查询串与用户信息。
  static String normalizeOrigin(String? rawHost) {
    final raw = (rawHost ?? '').trim();
    if (raw.isEmpty) return '';

    var candidate = raw;
    if (!candidate.contains('://')) {
      candidate = 'http://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) {
      // 无法解析时退回去尾斜杠的小写字符串，仍保证不含凭据。
      return raw.replaceAll(RegExp(r'/+$'), '').toLowerCase();
    }

    final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme.toLowerCase();
    final buffer = StringBuffer('$scheme://${uri.host.toLowerCase()}');
    if (uri.hasPort) {
      buffer.write(':${uri.port}');
    }
    return buffer.toString();
  }
}

/// 设备本地收藏条目。保存的是展示快照，不含任何 token / cookie / 临时播放地址。
class DeviceFavorite extends Equatable {
  /// 稳定身份键，见 [DeviceIdentity]。
  final String key;
  final DeviceItemSource source;
  final String title;
  final String? coverUrl;

  /// 规范化服务器 origin（仅在线与已知来源下载有值）。
  final String? origin;

  /// 服务器作品 id（仅在线与已知来源下载有值）。
  final int? remoteId;

  /// 导入音频 id（仅导入条目有值）。
  final String? importId;

  /// 本机副本相对路径（相对应用持久根目录，仅本机内容有值）。
  final String? localRelativePath;

  final DateTime createdAt;

  const DeviceFavorite({
    required this.key,
    required this.source,
    required this.title,
    required this.createdAt,
    this.coverUrl,
    this.origin,
    this.remoteId,
    this.importId,
    this.localRelativePath,
  });

  bool get isLocalSource => source != DeviceItemSource.online;

  Map<String, dynamic> toJson() => {
        'key': key,
        'source': source.storageValue,
        'title': title,
        'coverUrl': coverUrl,
        'origin': origin,
        'remoteId': remoteId,
        'importId': importId,
        'localRelativePath': localRelativePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DeviceFavorite.fromJson(Map<String, dynamic> json) {
    return DeviceFavorite(
      key: json['key'] as String,
      source: DeviceItemSourceX.fromStorage(json['source'] as String?),
      title: (json['title'] as String?) ?? '',
      coverUrl: json['coverUrl'] as String?,
      origin: json['origin'] as String?,
      remoteId: json['remoteId'] as int?,
      importId: json['importId'] as String?,
      localRelativePath: json['localRelativePath'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  DeviceFavorite copyWith({
    String? title,
    String? coverUrl,
    String? localRelativePath,
  }) {
    return DeviceFavorite(
      key: key,
      source: source,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      origin: origin,
      remoteId: remoteId,
      importId: importId,
      localRelativePath: localRelativePath ?? this.localRelativePath,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        key,
        source,
        title,
        coverUrl,
        origin,
        remoteId,
        importId,
        localRelativePath,
        createdAt,
      ];
}

/// 已导入的本地音频索引条目。
class ImportedAudio extends Equatable {
  final String id;
  final String title;

  /// 原始文件名（仅用于展示与默认标题）。
  final String fileName;

  /// 相对应用持久根目录的受控路径，例如 `imports/<id>/audio.mp3`。
  final String relativePath;

  final String extension;
  final int sizeBytes;
  final DateTime importedAt;

  const ImportedAudio({
    required this.id,
    required this.title,
    required this.fileName,
    required this.relativePath,
    required this.extension,
    required this.sizeBytes,
    required this.importedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fileName': fileName,
        'relativePath': relativePath,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'importedAt': importedAt.toIso8601String(),
      };

  factory ImportedAudio.fromJson(Map<String, dynamic> json) {
    return ImportedAudio(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      fileName: (json['fileName'] as String?) ?? '',
      relativePath: (json['relativePath'] as String?) ?? '',
      extension: (json['extension'] as String?) ?? '',
      sizeBytes: (json['sizeBytes'] as int?) ?? 0,
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  List<Object?> get props =>
      [id, title, fileName, relativePath, extension, sizeBytes, importedAt];
}
