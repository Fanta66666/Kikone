import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/device_library.dart';
import 'package:kikoeru_flutter/src/services/audio_import_service.dart';

void main() {
  group('DeviceIdentity', () {
    test('规范化 origin 保留协议、主机与端口，丢弃路径与查询串', () {
      expect(
        DeviceIdentity.normalizeOrigin('https://example.com/api?token=abc'),
        'https://example.com',
      );
      expect(
        DeviceIdentity.normalizeOrigin('http://example.com:8080/foo/bar'),
        'http://example.com:8080',
      );
      expect(
        DeviceIdentity.normalizeOrigin('EXAMPLE.com/'),
        'http://example.com',
      );
    });

    test('不同服务器上的相同 workId 不会碰撞', () {
      final a = DeviceIdentity.remote(origin: 'https://a.com', remoteId: 42);
      final b = DeviceIdentity.remote(origin: 'https://b.com', remoteId: 42);
      expect(a, isNot(equals(b)));
    });

    test('同一服务器的相同作品产生相同 key，与路径无关', () {
      final a = DeviceIdentity.remote(
        origin: 'https://example.com/ignored',
        remoteId: 7,
      );
      final b = DeviceIdentity.remote(origin: 'example.com', remoteId: 7);
      expect(a, equals(b));
    });

    test('导入与下载使用独立命名空间，不与在线 key 混淆', () {
      final online = DeviceIdentity.remote(origin: 'https://a.com', remoteId: 1);
      final imported = DeviceIdentity.imported('1');
      final download = DeviceIdentity.download('1');
      expect({online, imported, download}.length, 3);
    });
  });

  group('DeviceFavorite 序列化', () {
    test('往返序列化保持字段一致且不包含任何凭据字段', () {
      final favorite = DeviceFavorite(
        key: DeviceIdentity.remote(origin: 'https://a.com', remoteId: 9),
        source: DeviceItemSource.online,
        title: '示例作品',
        coverUrl: 'https://a.com/cover.jpg',
        origin: 'https://a.com',
        remoteId: 9,
        createdAt: DateTime.parse('2026-10-11T00:00:00.000Z'),
      );

      final json = favorite.toJson();
      expect(json.containsKey('token'), isFalse);
      expect(json.containsKey('cookie'), isFalse);

      final restored = DeviceFavorite.fromJson(json);
      expect(restored, equals(favorite));
    });

    test('导入条目保存受控相对路径', () {
      final audio = ImportedAudio(
        id: 'abc',
        title: '曲目',
        fileName: '曲目.mp3',
        relativePath: 'imports/abc/audio.mp3',
        extension: 'mp3',
        sizeBytes: 1024,
        importedAt: DateTime.parse('2026-10-11T00:00:00.000Z'),
      );

      final restored = ImportedAudio.fromJson(audio.toJson());
      expect(restored, equals(audio));
      expect(restored.relativePath, 'imports/abc/audio.mp3');
    });
  });

  group('AudioImportService 白名单', () {
    test('首版仅接受直接音频扩展名', () {
      expect(AudioImportService.allowedExtensions, containsAll(['mp3', 'm4a', 'aac', 'wav']));
      expect(AudioImportService.allowedExtensions, isNot(contains('zip')));
      expect(AudioImportService.allowedExtensions, isNot(contains('rar')));
      expect(AudioImportService.allowedExtensions, isNot(contains('7z')));
    });
  });
}
