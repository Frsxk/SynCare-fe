import 'dart:convert';
import 'dart:io';

/// Host-only fixture adapter; never import into the app or its browser bundle.
Map<String, dynamic> readPrivateFixture(File file) {
  final text = file.readAsStringSync();
  if (!text.startsWith('dpapi:')) {
    return jsonDecode(text) as Map<String, dynamic>;
  }
  final helper = File.fromUri(
    file.absolute.uri.resolve('../src/security/private-files.cjs'),
  );
  final result = Process.runSync('node', [
    '-e',
    'const {readPrivateJson}=require(process.argv[1]);'
        'process.stdout.write(JSON.stringify(readPrivateJson(process.argv[2])));',
    helper.path,
    file.absolute.path,
  ], runInShell: false);
  if (result.exitCode != 0) {
    throw const FormatException('private_fixture_unavailable');
  }
  try {
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  } on FormatException {
    throw const FormatException('private_fixture_unavailable');
  }
}
