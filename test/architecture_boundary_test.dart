import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces Set&Sit's modular boundaries, persistence isolation, audio
/// decoupling, zero global/static mutable state, and strict analyzer lints.
void main() {
  final repoRoot = Directory.current.path;
  final libDir = Directory('$repoRoot/lib');

  List<File> collectDartFiles() {
    if (!libDir.existsSync()) return const <File>[];
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  String toRepoRelative(String absPath) {
    final normalizedRoot = repoRoot.replaceAll('\\', '/');
    final normalizedAbs = absPath.replaceAll('\\', '/');
    if (normalizedAbs.startsWith('$normalizedRoot/')) {
      return normalizedAbs.substring(normalizedRoot.length + 1);
    }
    return normalizedAbs;
  }

  List<String> extractImportUris(String content) {
    final pattern = RegExp(
      r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    return pattern
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toList(growable: false);
  }

  String? resolveToLibRelative(String sourceLibRelPath, String uri) {
    if (uri.startsWith('package:setandsit/')) {
      return 'lib/${uri.substring('package:setandsit/'.length)}';
    }
    if (uri.startsWith('dart:') || uri.startsWith('package:')) {
      return null;
    }
    final lastSlash = sourceLibRelPath.lastIndexOf('/');
    final sourceDir =
        lastSlash > 0 ? sourceLibRelPath.substring(0, lastSlash) : 'lib';
    final combined = '$sourceDir/$uri';
    final segments = combined.split('/');
    final stack = <String>[];
    for (final seg in segments) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (stack.isNotEmpty) stack.removeLast();
      } else {
        stack.add(seg);
      }
    }
    return stack.join('/');
  }

  String stripComments(String source) {
    final blockComments = RegExp(r'/\*[\s\S]*?\*/');
    final lineComments = RegExp(r'//.*$', multiLine: true);
    return source.replaceAll(blockComments, '').replaceAll(lineComments, '');
  }

  test('all Set&Sit modular architecture invariants pass', () {
    final files = collectDartFiles();
    expect(files, isNotEmpty);

    final violations = <String>[];

    const nonShellPrefixes = <String>[
      'lib/setandsit_root.dart',
      'lib/state/',
      'lib/services/',
      'lib/engine/',
      'lib/storage/',
      'lib/audio/',
      'lib/models/',
      'lib/data/',
      'lib/theme/',
      'lib/screens/',
      'lib/widgets/',
    ];

    for (final file in files) {
      final relPath = toRepoRelative(file.path);
      final raw = file.readAsStringSync();
      final codeOnly = stripComments(raw);
      final uris = extractImportUris(raw);

      final isScreenOrWidget = relPath.startsWith('lib/screens/') ||
          relPath.startsWith('lib/widgets/');
      final isNonShellCore = nonShellPrefixes.any(
        (prefix) => prefix.endsWith('/')
            ? relPath.startsWith(prefix)
            : relPath == prefix,
      );

      for (final uri in uris) {
        final resolved = resolveToLibRelative(relPath, uri);

        // 1. shared_preferences isolated strictly to lib/shell/shared_preferences_key_value_store.dart
        if (uri.startsWith('package:shared_preferences/') &&
            relPath != 'lib/shell/shared_preferences_key_value_store.dart') {
          violations.add(
            '[Boundary 1] $relPath must not import $uri (only lib/shell/shared_preferences_key_value_store.dart may)',
          );
        }

        // 3. Thin UI screens/widgets: no shared_preferences, dart:convert, services, shell, or bundled audio
        if (isScreenOrWidget) {
          if (uri == 'dart:convert' ||
              uri.startsWith('package:shared_preferences/')) {
            violations.add(
              '[Boundary 3] UI file $relPath must not import $uri',
            );
          }
          if (resolved != null &&
              (resolved == 'lib/services/preferences_service.dart' ||
                  resolved == 'lib/services/audio_manifest_service.dart' ||
                  resolved == 'lib/audio/bundled_audio_sources.dart' ||
                  resolved.startsWith('lib/shell/'))) {
            violations.add(
              '[Boundary 3] UI file $relPath must not import $resolved',
            );
          }
        }

        // 4. Non-shell module files must never import lib/shell/ or lib/main.dart
        if (isNonShellCore && resolved != null) {
          if (resolved.startsWith('lib/shell/') ||
              resolved == 'lib/main.dart') {
            violations.add(
              '[Boundary 4] Non-shell file $relPath must not import $resolved',
            );
          }
        }
      }

      // Note: lib/setandsit_module.dart exports the embeddable API (including bundled offline default)
      // and must never export lib/shell/ or lib/main.dart.
      if (relPath == 'lib/setandsit_module.dart') {
        for (final uri in uris) {
          final resolved = resolveToLibRelative(relPath, uri);
          if (resolved != null &&
              (resolved.startsWith('lib/shell/') ||
                  resolved == 'lib/main.dart')) {
            violations.add(
              '[Boundary 4] lib/setandsit_module.dart must not export/import $resolved',
            );
          }
        }
      }

      // 2. rootBundle and AssetSource( confined strictly to lib/audio/bundled_audio_sources.dart
      if (relPath != 'lib/audio/bundled_audio_sources.dart') {
        if (codeOnly.contains('rootBundle')) {
          violations.add(
            '[Boundary 2] $relPath references rootBundle outside bundled_audio_sources.dart',
          );
        }
        if (codeOnly.contains('AssetSource(')) {
          violations.add(
            '[Boundary 2] $relPath constructs AssetSource(...) outside bundled_audio_sources.dart',
          );
        }
      }

      // 5. Zero global/static mutable caches or singletons in lib/
      for (final pattern in <RegExp>[
        RegExp(r'\bstatic\s+(?:late\s+)?SharedPreferences\b'),
        RegExp(r'\bstatic\s+(?:final\s+|late\s+)?Map<[^>]+>\s+\w+\s*[=;]'),
        RegExp(r'\bstatic\s+final\s+Random\b'),
        RegExp(r'static\s+(?:final\s+)?[A-Za-z0-9_<>?]+\s+_?instance\s*='),
      ]) {
        if (pattern.hasMatch(codeOnly)) {
          violations.add(
            '[Boundary 5] $relPath declares forbidden static mutable/singleton field (${pattern.pattern})',
          );
        }
      }

      // Guard against non-const mutable static fields (allow static const/final, getters, and methods)
      final staticFieldLines = codeOnly.split('\n');
      for (final line in staticFieldLines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('static ')) continue;
        if (trimmed.startsWith('static const ') ||
            trimmed.startsWith('static final ') ||
            trimmed.contains(' get ') ||
            trimmed.contains('(')) {
          continue;
        }
        if (RegExp(r'^static\s+[A-Za-z0-9_<>?]+\s+[A-Za-z0-9_]+').hasMatch(trimmed)) {
          violations.add(
            '[Boundary 5] $relPath declares mutable static field: $trimmed',
          );
        }
      }
    }

    // 6. Strict analyzer lints & no broad deprecated_member_use: ignore
    final analysisFile = File('$repoRoot/analysis_options.yaml');
    expect(analysisFile.existsSync(), isTrue);
    final analysisYaml = analysisFile.readAsStringSync();
    for (final requiredRule in const <String>[
      'unawaited_futures: true',
      'cancel_subscriptions: true',
      'close_sinks: true',
      'avoid_print: true',
      'prefer_const_constructors: true',
    ]) {
      if (!analysisYaml.contains(requiredRule)) {
        violations.add(
          '[Boundary 6] analysis_options.yaml missing "$requiredRule"',
        );
      }
    }
    if (RegExp(r'deprecated_member_use\s*:\s*ignore').hasMatch(analysisYaml)) {
      violations.add(
        '[Boundary 6] analysis_options.yaml must not contain "deprecated_member_use: ignore"',
      );
    }

    expect(
      violations,
      isEmpty,
      reason: 'Architectural boundary violations:\n${violations.join('\n')}',
    );
  });
}
