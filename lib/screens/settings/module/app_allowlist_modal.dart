import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/services/module_config_service.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';

class AppAllowlistModal extends StatefulWidget {
  const AppAllowlistModal({super.key});

  @override
  State<AppAllowlistModal> createState() => _AppAllowlistModalState();
}

class _AppAllowlistModalState extends State<AppAllowlistModal> {
  final ModuleConfigService _service = ModuleConfigService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _installedApps = [];
  Set<String> _selectedPackages = {};
  String _filter = 'all'; // 'all' or 'selected'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.readAppAllowlist(),
      _service.getInstalledApps(forceRefresh: forceRefresh),
    ]);

    final allowlist = results[0] as List<String>;
    final allowSet = allowlist.toSet();
    final installed = results[1] as List<Map<String, dynamic>>;

    // Ensure allowlisted packages are present in the list even if not in third-party pm output
    final existingPkgs = installed.map((e) => e['package'] as String).toSet();
    for (final pkg in allowlist) {
      if (!existingPkgs.contains(pkg)) {
        installed.insert(0, {
          'package': pkg,
          'name': ModuleConfigService.resolveKnownAppName(pkg),
          'uid': null,
          'icon': null,
        });
      }
    }

    // Sort selected apps to the top, then alphabetically by app name
    installed.sort((a, b) {
      final aSel = allowSet.contains(a['package'] as String);
      final bSel = allowSet.contains(b['package'] as String);
      if (aSel != bSel) return aSel ? -1 : 1;
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    if (!mounted) return;
    setState(() {
      _selectedPackages = allowSet;
      _installedApps = installed;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final ok = await _service.saveAppAllowlist(_selectedPackages.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: ok
          ? '已保存并即时生效（共放行 ${_selectedPackages.length} 款应用）'
          : '保存失败，请检查 Root 权限',
      color: ok ? Colors.green : Colors.red,
    );
    Navigator.of(context).pop(true);
  }

  void _showAddCustomPackageDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动输入包名'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请输入应用的完整 Android 包名（例如 com.example.app）：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'com.package.name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final pkg = controller.text.trim();
              if (pkg.isNotEmpty) {
                setState(() {
                  _selectedPackages.add(pkg);
                  if (!_installedApps.any((e) => e['package'] == pkg)) {
                    _installedApps.insert(0, <String, dynamic>{
                      'package': pkg,
                      'name': pkg,
                      'uid': null,
                      'isSystem': false,
                      'icon': null,
                    });
                  }
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredApps = _installedApps.where((app) {
      final name = (app['name'] as String? ?? '').toLowerCase();
      final pkg = (app['package'] as String? ?? '').toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          pkg.contains(_searchQuery);
      if (!matchesSearch) return false;
      if (_filter == 'selected') {
        return _selectedPackages.contains(app['package']);
      }
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Top Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '应用放行名单',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '已放行 ${_selectedPackages.length} 款应用',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: '刷新应用列表',
                  onPressed:
                      _loading ? null : () => _loadData(forceRefresh: true),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: '手动添加包名',
                  onPressed: _showAddCustomPackageDialog,
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('保存'),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Search & Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      hintText: '搜索应用名称或包名…',
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('已放行 (${_selectedPackages.length})'),
                  selected: _filter == 'selected',
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _filter = val ? 'selected' : 'all';
                    });
                  },
                ),
              ],
            ),
          ),
          // List of Apps
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? '未找到匹配的应用'
                              : (_filter == 'selected'
                                  ? '暂无放行应用，可点击右上角添加或在列表中勾选'
                                  : '未获取到已安装应用列表'),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredApps.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 64),
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final pkg = app['package'] as String? ?? '';
                          final name = app['name'] as String? ?? pkg;
                          final iconBytes = app['icon'] as Uint8List?;
                          final isChecked = _selectedPackages.contains(pkg);

                          return RepaintBoundary(
                            child: CheckboxListTile(
                              value: isChecked,
                              activeColor: colorScheme.primary,
                              secondary: iconBytes != null &&
                                      iconBytes.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        iconBytes,
                                        width: 38,
                                        height: 38,
                                        cacheWidth: 72,
                                        cacheHeight: 72,
                                        filterQuality: FilterQuality.low,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: 19,
                                      backgroundColor: isChecked
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                      child: Text(
                                        name.isNotEmpty
                                            ? name.characters.first
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isChecked
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                              title: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isChecked
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                pkg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (val == true) {
                                    _selectedPackages.add(pkg);
                                  } else {
                                    _selectedPackages.remove(pkg);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
