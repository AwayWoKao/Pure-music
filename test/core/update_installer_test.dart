import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_music/core/update_checker.dart';
import 'package:pure_music/core/update_installer.dart';

void main() {
  test('refuses install when release has no checksum', () {
    final info = UpdateInfo.fromJson({'tag_name': 'v2.3.0'});
    expect(
      () => ensureUpdateHasChecksum(
        info: info,
        channel: UpdateChannel.github,
        portableBuild: false,
      ),
      throwsA(
        isA<UpdateInstallException>().having(
          (error) => error.message,
          'message',
          contains('校验'),
        ),
      ),
    );
  });

  test('allows install metadata when sha256 is present', () {
    final info = UpdateInfo.fromJson({
      'tag_name': 'v2.3.0',
      'installer_sha256': 'a' * 64,
    });
    ensureUpdateHasChecksum(
      info: info,
      channel: UpdateChannel.github,
      portableBuild: false,
    );
  });

  test('rejects path traversal in portable package entries', () {
    expect(isSafePortableEntryPath(r'C:\pkg', '../evil.exe'), isFalse);
    expect(isSafePortableEntryPath(r'C:\pkg', 'data/app.so'), isTrue);
  });

  test('verifies extracted portable files against the manifest', () async {
    final root = await Directory.systemTemp.createTemp('pure_music_pkg_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final payload = File('${root.path}/pure_music.exe');
    await payload.writeAsString('portable-bytes');
    final digest = (await sha256.bind(payload.openRead()).first).toString();
    final updateDir = Directory('${root.path}/.update');
    await updateDir.create();
    await File('${updateDir.path}/package_manifest.json').writeAsString(
      '{"version":"2.3.0","files":[{"path":"pure_music.exe","sha256":"$digest"}]}',
    );
    await verifyExtractedPortablePackage(root.path);
  });

  test('accepts a locally packed portable directory', () async {
    final dir = Directory('output/pure_music_2.3.0_release_portable');
    if (!dir.existsSync()) {
      markTestSkipped('no local packed portable directory');
      return;
    }
    await verifyExtractedPortablePackage(dir.path);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
