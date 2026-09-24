import 'dart:convert';
import 'dart:io';

class ModuleConfigService {
  static const String moduleConfigPath = '/data/adb/agh/scripts/config.prop';
  static const String moduleYamlPath = '/data/adb/agh/bin/AdGuardHome.yaml';

  bool get _isAndroid => Platform.isAndroid;

  Future<bool> hasRoot() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run('su', ['-c', 'id']);
      return result.stdout.toString().contains('uid=0');
    } catch (_) {
      return false;
    }
  }

  Future<String?> readAdGuardYaml() async {
    if (!_isAndroid) return null;
    try {
      final result = await Process.run('su', ['-c', 'cat $moduleYamlPath']);
      if (result.exitCode != 0) {
        return null;
      }
      return result.stdout.toString();
    } catch (_) {
      return null;
    }
  }

  String? parseHttpAddress(String yamlText) {
    final lines = yamlText.split('\n');
    var inHttp = false;
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('http:')) {
        inHttp = true;
        continue;
      }
      if (inHttp) {
        if (trimmed.isNotEmpty && !line.startsWith(' ')) {
          inHttp = false;
        }
        if (trimmed.startsWith('address:')) {
          final value = trimmed.substring('address:'.length).trim();
          return value.replaceAll('"', '').replaceAll("'", '');
        }
      }
    }
    return null;
  }

  Future<String?> readHttpAddress() async {
    final yaml = await readAdGuardYaml();
    if (yaml == null) return null;
    return parseHttpAddress(yaml);
  }

  Future<String> readProxyUrl() async {
    if (!_isAndroid) return '';
    try {
      final result = await Process.run('su', ['-c', 'cat $moduleConfigPath']);
      if (result.exitCode != 0) {
        return '';
      }
      final content = result.stdout.toString();
      final line = content.split('\n').firstWhere(
            (line) => line.trimLeft().startsWith('PROXY_URL='),
            orElse: () => '',
          );
      if (line.isEmpty) return '';
      // 模块配置默认写入 PROXY_URL=" "（引号内一个空格）作为占位，
      // 去掉引号后再 trim，空白值统一按“未设置”处理，不显示到输入框。
      return line
          .substring(line.indexOf('PROXY_URL=') + 'PROXY_URL='.length)
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim();
    } catch (_) {
      return '';
    }
  }

  Future<bool> saveProxyUrl(String proxyUrl) async {
    if (!_isAndroid) return false;
    try {
      final readResult =
          await Process.run('su', ['-c', 'cat $moduleConfigPath']);
      if (readResult.exitCode != 0) return false;

      final value = proxyUrl.trim();
      final lines = readResult.stdout.toString().split('\n');
      final updatedLines = <String>[];
      var replaced = false;

      for (final line in lines) {
        if (line.trimLeft().startsWith('PROXY_URL=')) {
          replaced = true;
          // 空值时保留模块原有的空格占位，避免变量缺失导致模块脚本报错。
          updatedLines
              .add(value.isNotEmpty ? 'PROXY_URL="$value"' : 'PROXY_URL=" "');
          continue;
        }
        updatedLines.add(line);
      }
      if (!replaced) {
        updatedLines
            .add(value.isNotEmpty ? 'PROXY_URL="$value"' : 'PROXY_URL=" "');
      }
      final content = updatedLines.join('\n');

      final writer =
          await Process.start('su', ['-c', 'cat > $moduleConfigPath']);
      writer.stdin.add(utf8.encode(content));
      await writer.stdin.close();
      final writeResult = await writer.exitCode;
      return writeResult == 0;
    } catch (_) {
      return false;
    }
  }
}
