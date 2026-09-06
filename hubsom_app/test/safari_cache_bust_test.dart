import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final web = Directory('web');
  final indexHtml = File('web/index.html');
  final afiaHtml = File('web/Afia.html');
  final firebase = File('firebase.json');
  final stampScript = File('scripts/stamp_hosting.py');
  final deployScript = File('scripts/deploy_hosting.sh');

  test('source HTML keeps unstamped bootstrap tags for the deploy rewriter', () {
    final index = indexHtml.readAsStringSync();
    final afia = afiaHtml.readAsStringSync();
    expect(index, contains('src="flutter_bootstrap.js"'));
    expect(index, isNot(contains('src="flutter_bootstrap.js?')));
    expect(afia, contains('src="flutter_bootstrap.js"'));
    expect(afia, contains('src="/afia_gate.js"'));
    expect(afia, contains('id="afia-form"'));
    expect(afia, contains('hubsomAfiaStart()'));
  });

  test('HTML wipes Safari service workers and Cache Storage before boot', () {
    for (final file in [indexHtml, afiaHtml]) {
      final html = file.readAsStringSync();
      expect(html, contains("caches.delete"));
      expect(html, contains('serviceWorker.getRegistrations'));
      expect(html, contains('reg.unregister()'));
      expect(html, contains('serviceWorker.register = function'));
      expect(html, contains("location.reload()"));
      expect(html, contains('no-store, no-cache, must-revalidate'));
      expect(html, contains('http-equiv="Expires"'));
    }
    expect(indexHtml.readAsStringSync(), contains('apple-mobile-web-app-capable" content="no"'));
  });

  test('hosting headers tell Safari not to keep HTML or JS', () {
    final json = firebase.readAsStringSync();
    expect(json, contains('no-store, no-cache, must-revalidate, max-age=0'));
    expect(json, contains('Clear-Site-Data'));
    expect(json, contains('\\"cache\\"'));
    expect(json, isNot(contains('"storage"')));
    expect(json, contains('/flutter_service_worker.js'));
    expect(File('web/manifest.json').readAsStringSync(), contains('"display": "browser"'));
  });

  test('deploy stamps unique JS filenames instead of query strings', () {
    expect(stampScript.existsSync(), isTrue);
    expect(deployScript.readAsStringSync(), contains('stamp_hosting.py'));
    expect(deployScript.readAsStringSync(), isNot(contains('flutter_bootstrap.js?v=')));
  });

  test('stamp_hosting copies JS to unique names Safari has never seen', () async {
    expect(web.existsSync(), isTrue);
    final dir = Directory.systemTemp.createTempSync('hubsom-stamp');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    File('${dir.path}/flutter_bootstrap.js').writeAsStringSync(
      '_flutter.buildConfig = {"builds":[{"mainJsPath":"main.dart.js"}]};\n'
      '_flutter.loader.load({serviceWorkerSettings:{}});\n',
    );
    File('${dir.path}/main.dart.js').writeAsStringSync('window.hubsomMain = true;');
    File('${dir.path}/afia_gate.js').writeAsStringSync('window.hubsomAfiaStart = function () {};');
    File('${dir.path}/flutter.js').writeAsStringSync('m("main.dart.js")');
    File('${dir.path}/index.html').writeAsStringSync(
      '<!DOCTYPE html><script src="flutter_bootstrap.js"></script>',
    );
    File('${dir.path}/Afia.html').writeAsStringSync(
      '<!DOCTYPE html><script src="/afia_gate.js"></script>'
      '<script src="flutter_bootstrap.js"></script>',
    );

    final result = await Process.run('python3', [
      stampScript.path,
      '--web-dir',
      dir.path,
      '--stamp',
      '20260906v100',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    expect(File('${dir.path}/flutter_bootstrap.20260906v100.js').existsSync(), isTrue);
    expect(File('${dir.path}/main.dart.20260906v100.js').existsSync(), isTrue);
    expect(File('${dir.path}/afia_gate.20260906v100.js').existsSync(), isTrue);

    final index = File('${dir.path}/index.html').readAsStringSync();
    expect(index, contains('src="flutter_bootstrap.20260906v100.js"'));
    expect(index, contains('<!-- hubsom-deploy 20260906v100 -->'));
    expect(index, isNot(contains('flutter_bootstrap.js?')));

    final afia = File('${dir.path}/Afia.html').readAsStringSync();
    expect(afia, contains('src="/afia_gate.20260906v100.js"'));
    expect(afia, contains('src="flutter_bootstrap.20260906v100.js"'));

    final bootstrap =
        File('${dir.path}/flutter_bootstrap.20260906v100.js').readAsStringSync();
    expect(bootstrap, contains('"mainJsPath":"main.dart.20260906v100.js"'));
    expect(bootstrap, contains('_flutter.loader.load();'));
    expect(bootstrap, isNot(contains('main.dart.js?')));

    final worker = File('${dir.path}/flutter_service_worker.js').readAsStringSync();
    expect(worker, contains('registration.unregister()'));
    expect(worker, contains('caches.delete'));
    expect(worker, isNot(contains('main.dart.js')));
  });
}
