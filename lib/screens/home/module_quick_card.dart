// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:adguard_home_manager/functions/get_filtered_status.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/models/logs.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';
import 'package:adguard_home_manager/providers/status_provider.dart';
import 'package:adguard_home_manager/screens/settings/module/app_allowlist_modal.dart';
import 'package:adguard_home_manager/services/module_config_service.dart';

/// 极简内嵌式模块快捷操作区（内嵌于首页顶部保护主卡片中）：
/// - 常态下仅展示一行 3 个高频操作按钮（误杀排错、分应用开关、网络刷新），零视觉噪音；
/// - 仅当检测到核心未运行或 DNS/SNI 转发异常时，才在按钮上方显示一行异常修复提示。
class ModuleQuickActions extends StatefulWidget {
  const ModuleQuickActions({super.key});

  @override
  State<ModuleQuickActions> createState() => _ModuleQuickActionsState();
}

class _ModuleQuickActionsState extends State<ModuleQuickActions> {
  bool _loadingDiag = true;
  bool _flushing = false;
  Map<String, dynamic> _diag = {
    'running': true,
    'natOk': true,
    'sniOk': true,
  };

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics({bool forceRefresh = false}) async {
    final diag = await ModuleConfigService()
        .getModuleDiagnostics(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _diag = diag;
      _loadingDiag = false;
    });
  }

  Future<void> _handleQuickFlush() async {
    if (_flushing) return;
    HapticFeedback.mediumImpact();
    setState(() => _flushing = true);

    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final service = ModuleConfigService();

    await Future.wait([
      if (serversProvider.apiClient2 != null)
        serversProvider.apiClient2!.resetDnsCache(),
      service.flushSystemDnsCache(),
      service.reloadFirewallRules(),
    ]);

    await Future.delayed(const Duration(milliseconds: 500));
    await Future.wait([
      _loadDiagnostics(forceRefresh: true),
      statusProvider.getServerStatus(withLoadingIndicator: false),
    ]);

    if (!mounted) return;
    setState(() => _flushing = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: '已刷新 DNS 缓存并重载规则',
      color: Colors.green,
    );
  }

  Future<void> _openAppAllowlist() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const AppAllowlistModal(),
    );
    if (mounted) {
      _loadDiagnostics();
    }
  }

  Future<void> _openFalsePositiveAssistant() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const _FalsePositiveAssistantModal(),
    );
  }

  String? _getAnomalyMessage(bool generalEnabled) {
    if (_loadingDiag || !generalEnabled) return null;
    final running = _diag['running'] == true;
    final natOk = _diag['natOk'] == true;
    final sniOk = _diag['sniOk'] == true;
    if (!running) return '模块核心未运行';
    if (!natOk && !sniOk) return 'DNS 与 SNI 转发未生效';
    if (!natOk) return 'DNS 转发规则未生效';
    if (!sniOk) return 'SNI 过滤规则未生效';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<StatusProvider>(context);
    final generalEnabled = statusProvider.serverStatus?.generalEnabled ?? true;
    final anomalyMsg = _getAnomalyMessage(generalEnabled);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (anomalyMsg != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    anomalyMsg,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _flushing ? null : _handleQuickFlush,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '一键修复',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.troubleshoot_rounded,
                label: '误杀排错',
                onTap: _openFalsePositiveAssistant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.apps_rounded,
                label: '分应用开关',
                onTap: _openAppAllowlist,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: _flushing
                    ? Icons.hourglass_top_rounded
                    : Icons.bolt_rounded,
                label: _flushing ? '刷新中…' : '网络刷新',
                onTap: _flushing ? () {} : _handleQuickFlush,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final fgColor = colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: fgColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedDomainSummary {
  final String domain;
  int count;
  DateTime latestTime;
  final String ruleText;
  final bool isSni;
  final bool isNewAfterCapture;

  _BlockedDomainSummary({
    required this.domain,
    required this.count,
    required this.latestTime,
    required this.ruleText,
    required this.isSni,
    this.isNewAfterCapture = false,
  });
}

class _DiagnosedDomainItem {
  final String domain;
  final bool blocked;
  final String reasonText;
  final String ruleText;

  const _DiagnosedDomainItem({
    required this.domain,
    required this.blocked,
    required this.reasonText,
    required this.ruleText,
  });
}

class _FalsePositiveAssistantModal extends StatefulWidget {
  const _FalsePositiveAssistantModal();

  @override
  State<_FalsePositiveAssistantModal> createState() =>
      _FalsePositiveAssistantModalState();
}

class _FalsePositiveAssistantModalState
    extends State<_FalsePositiveAssistantModal> with WidgetsBindingObserver {
  int _activeTab = 0; // 0: 最近拦截 & 查规则, 1: 网页排错, 2: 应用排错

  // Tab 0 状态
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<_BlockedDomainSummary> _blockedDomains = [];
  bool _searchingRules = false;
  List<Map<String, String>> _ruleMatches = [];
  Timer? _searchDebounce;

  // Tab 1 (网页排错) 状态
  final TextEditingController _urlController = TextEditingController();
  bool _diagnosingWeb = false;
  String? _webDiagnoseHint;
  List<_DiagnosedDomainItem> _webDomains = [];

  // Tab 2 (应用排错) 状态
  bool _loadingApps = false;
  List<Map<String, dynamic>> _installedApps = [];
  Set<String> _allowlistedApps = {};
  String _appSearchQuery = '';
  final TextEditingController _appSearchController = TextEditingController();
  Map<String, dynamic>? _selectedApp;
  bool _capturingApp = false;
  DateTime? _captureStartTime;
  Set<String> _baselineBlockedDomains = {};
  List<_BlockedDomainSummary> _capturedAppDomains = [];
  bool _scanningAppLocal = false;
  List<_DiagnosedDomainItem> _scannedAppDomains = [];
  bool _togglingAllowlist = false;

  // 通用放行状态
  final Set<String> _unblockedDomains = {};
  final Set<String> _unblockingInProgress = {};
  bool _batchUnblocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchRecentBlocked();
    _searchController.addListener(_onSearchChanged);
    _appSearchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _appSearchQuery = _appSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _urlController.dispose();
    _appSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _capturingApp &&
        _captureStartTime != null) {
      _finishAppCapture();
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
      if (q.length < 2) {
        _ruleMatches = [];
        _searchingRules = false;
      }
    });
    _searchDebounce?.cancel();
    if (q.length >= 2) {
      setState(() => _searchingRules = true);
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        _runRuleSearch(q);
      });
    }
  }

  Future<void> _runRuleSearch(String keyword) async {
    final matches = await ModuleConfigService().searchFilterRules(keyword);
    if (!mounted || _searchQuery != keyword) return;
    setState(() {
      _ruleMatches = matches;
      _searchingRules = false;
    });
  }

  Future<void> _fetchRecentBlocked() async {
    setState(() => _loading = true);
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    if (serversProvider.apiClient2 == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final result = await serversProvider.apiClient2!.getLogs(
      count: 200,
      responseStatus: 'blocked',
    );

    if (!mounted) return;
    if (result.successful == true && result.content is LogsData) {
      final logs = (result.content as LogsData).data;
      final Map<String, _BlockedDomainSummary> map = {};
      for (final log in logs) {
        final domain = log.question.name?.trim() ?? '';
        if (domain.isEmpty) continue;
        final isSni =
            (log.clientProto?.toLowerCase().contains('sni') ?? false) ||
                log.question.type.toUpperCase() == 'SNI';
        final ruleText = log.rules.isNotEmpty
            ? log.rules.first.text
            : (log.rule?.isNotEmpty == true ? log.rule! : log.reason);

        if (map.containsKey(domain)) {
          map[domain]!.count += 1;
          if (log.time.isAfter(map[domain]!.latestTime)) {
            map[domain]!.latestTime = log.time;
          }
        } else {
          map[domain] = _BlockedDomainSummary(
            domain: domain,
            count: 1,
            latestTime: log.time,
            ruleText: ruleText,
            isSni: isSni,
          );
        }
      }
      final list = map.values.toList()
        ..sort((a, b) => b.latestTime.compareTo(a.latestTime));
      setState(() {
        _blockedDomains = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<_DiagnosedDomainItem> _checkSingleDomain(String domain) async {
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    if (serversProvider.apiClient2 == null) {
      return _DiagnosedDomainItem(
        domain: domain,
        blocked: false,
        reasonText: '未连接',
        ruleText: '',
      );
    }
    try {
      final res =
          await serversProvider.apiClient2!.checkHostFiltered(host: domain);
      if (res.successful && res.content is Map) {
        final map = res.content as Map;
        final reason = (map['reason'] ?? '').toString();
        final blocked = isDomainBlocked(reason);
        String ruleText = '';
        if (map['rules'] is List && (map['rules'] as List).isNotEmpty) {
          final firstRule = (map['rules'] as List).first;
          if (firstRule is Map) {
            ruleText = (firstRule['text'] ?? '').toString();
          }
        }
        if (ruleText.isEmpty && map['rule'] != null) {
          ruleText = map['rule'].toString();
        }
        return _DiagnosedDomainItem(
          domain: domain,
          blocked: blocked,
          reasonText: blocked
              ? '被规则拦截'
              : (reason == 'NotFilteredWhiteList' ? '白名单已放行' : '正常放行'),
          ruleText: ruleText,
        );
      }
    } catch (_) {}
    return _DiagnosedDomainItem(
      domain: domain,
      blocked: false,
      reasonText: '正常放行',
      ruleText: '',
    );
  }

  Future<void> _diagnoseWebpage() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty || _diagnosingWeb) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _diagnosingWeb = true;
      _webDiagnoseHint = '正在抓取网页源码并解析外链静态域名…';
      _webDomains = [];
    });

    final domains = await ModuleConfigService().extractWebpageDomains(raw);
    if (!mounted) return;
    if (domains.isEmpty) {
      setState(() {
        _diagnosingWeb = false;
        _webDiagnoseHint = '未能解析出有效域名，请检查输入的网址链接';
      });
      return;
    }

    setState(() {
      _webDiagnoseHint = '已提取 ${domains.length} 个关联域名，正在检测规则拦截状态…';
    });

    final results = await Future.wait(domains.map(_checkSingleDomain));
    if (!mounted) return;

    results.sort((a, b) {
      if (a.blocked != b.blocked) return a.blocked ? -1 : 1;
      return a.domain.compareTo(b.domain);
    });

    final blockedCount = results.where((e) => e.blocked).length;
    setState(() {
      _webDomains = results;
      _diagnosingWeb = false;
      _webDiagnoseHint = blockedCount > 0
          ? '共发现 ${results.length} 个网页关联域名，其中 $blockedCount 个被拦截（疑似导致网页异常的真凶）：'
          : '共检测 ${results.length} 个关联域名，均未被规则库拦截。若仍无法访问，可切换至「最近拦截」查看实时记录。';
    });
  }

  Future<void> _ensureAppsLoaded() async {
    if (_installedApps.isNotEmpty || _loadingApps) return;
    setState(() => _loadingApps = true);
    final service = ModuleConfigService();
    final results = await Future.wait([
      service.getInstalledApps(includeSystem: false),
      service.readAppAllowlist(),
    ]);
    if (!mounted) return;
    setState(() {
      _installedApps = results[0] as List<Map<String, dynamic>>;
      _allowlistedApps = (results[1] as List<String>).toSet();
      _loadingApps = false;
    });
  }

  Future<void> _startAppCapture(Map<String, dynamic> app) async {
    final pkg = (app['package'] ?? '').toString();
    if (pkg.isEmpty) return;
    HapticFeedback.mediumImpact();

    final baseline = _blockedDomains.map((e) => e.domain).toSet();
    final startTime = DateTime.now().subtract(const Duration(seconds: 2));

    setState(() {
      _capturingApp = true;
      _captureStartTime = startTime;
      _baselineBlockedDomains = baseline;
      _capturedAppDomains = [];
    });

    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    if (serversProvider.apiClient2 != null) {
      await serversProvider.apiClient2!.resetDnsCache();
    }

    await ModuleConfigService().launchAppForCapture(pkg, forceStop: true);
  }

  Future<void> _finishAppCapture() async {
    final startTime = _captureStartTime;
    if (startTime == null) return;
    setState(() {
      _capturingApp = false;
    });

    await _fetchRecentBlocked();
    if (!mounted) return;

    final List<_BlockedDomainSummary> newlyTriggered = [];
    for (final item in _blockedDomains) {
      if (item.latestTime.isAfter(startTime)) {
        final isNewDomain = !_baselineBlockedDomains.contains(item.domain);
        newlyTriggered.add(
          _BlockedDomainSummary(
            domain: item.domain,
            count: item.count,
            latestTime: item.latestTime,
            ruleText: item.ruleText,
            isSni: item.isSni,
            isNewAfterCapture: isNewDomain,
          ),
        );
      }
    }

    newlyTriggered.sort((a, b) {
      if (a.isNewAfterCapture != b.isNewAfterCapture) {
        return a.isNewAfterCapture ? -1 : 1;
      }
      return b.latestTime.compareTo(a.latestTime);
    });

    setState(() {
      _capturedAppDomains = newlyTriggered;
    });
  }

  Future<void> _scanSelectedAppDomains(Map<String, dynamic> app) async {
    final pkg = (app['package'] ?? '').toString();
    if (pkg.isEmpty || _scanningAppLocal) return;
    HapticFeedback.lightImpact();

    setState(() {
      _scanningAppLocal = true;
      _scannedAppDomains = [];
    });

    final domains = await ModuleConfigService().scanAppLocalDomains(pkg);
    if (!mounted) return;
    if (domains.isEmpty) {
      setState(() => _scanningAppLocal = false);
      return;
    }

    final checked = await Future.wait(domains.map(_checkSingleDomain));
    if (!mounted) return;

    checked.sort((a, b) {
      if (a.blocked != b.blocked) return a.blocked ? -1 : 1;
      return a.domain.compareTo(b.domain);
    });

    setState(() {
      _scannedAppDomains = checked;
      _scanningAppLocal = false;
    });
  }

  Future<void> _toggleSelectedAppAllowlist(Map<String, dynamic> app) async {
    final pkg = (app['package'] ?? '').toString();
    final name = (app['name'] ?? pkg).toString();
    if (pkg.isEmpty || _togglingAllowlist) return;
    HapticFeedback.mediumImpact();

    setState(() => _togglingAllowlist = true);
    final service = ModuleConfigService();
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final updated = Set<String>.from(_allowlistedApps);
    final adding = !updated.contains(pkg);
    if (adding) {
      updated.add(pkg);
    } else {
      updated.remove(pkg);
    }

    final ok = await service.saveAppAllowlist(updated.toList());
    await service.flushSystemDnsCache();

    if (!mounted) return;
    setState(() {
      _togglingAllowlist = false;
      if (ok) {
        _allowlistedApps = updated;
      }
    });

    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: ok
          ? (adding ? '已将「$name」加入应用白名单并刷新网络' : '已将「$name」移出应用白名单')
          : '操作失败，请重试',
      color: ok ? Colors.green : Colors.red,
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds.clamp(1, 59)}秒前';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _unblockDomain(String domain) async {
    if (_unblockingInProgress.contains(domain) ||
        _unblockedDomains.contains(domain)) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _unblockingInProgress.add(domain));

    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    final ok = await statusProvider.blockUnblockDomain(
      domain: domain,
      newStatus: 'unblock',
    );

    if (ok) {
      await Future.wait([
        if (serversProvider.apiClient2 != null)
          serversProvider.apiClient2!.resetDnsCache(),
        ModuleConfigService().flushSystemDnsCache(),
      ]);
    }

    if (!mounted) return;
    setState(() {
      _unblockingInProgress.remove(domain);
      if (ok) {
        _unblockedDomains.add(domain);
      }
    });

    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: ok ? '已放行 $domain 并刷新缓存' : '放行失败，请重试',
      color: ok ? Colors.green : Colors.red,
    );
  }

  Future<void> _unblockAllDomains(List<String> domains) async {
    final pending =
        domains.where((d) => !_unblockedDomains.contains(d)).toList();
    if (pending.isEmpty || _batchUnblocking) return;
    HapticFeedback.mediumImpact();
    setState(() => _batchUnblocking = true);

    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);

    int successCount = 0;
    for (final d in pending) {
      final ok = await statusProvider.blockUnblockDomain(
        domain: d,
        newStatus: 'unblock',
      );
      if (ok) {
        successCount++;
        if (mounted) {
          setState(() => _unblockedDomains.add(d));
        }
      }
    }

    await Future.wait([
      if (serversProvider.apiClient2 != null)
        serversProvider.apiClient2!.resetDnsCache(),
      ModuleConfigService().flushSystemDnsCache(),
    ]);

    if (!mounted) return;
    setState(() => _batchUnblocking = false);
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: '已一键放行 $successCount 个关联域名并刷新 DNS 缓存',
      color: Colors.green,
    );
  }

  Widget _buildModeSelector(ColorScheme colorScheme) {
    const tabs = [
      (Icons.history_rounded, '最近拦截 & 查规则'),
      (Icons.language_rounded, '网页排错'),
      (Icons.phonelink_setup_rounded, '应用排错'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final selected = _activeTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_activeTab == i) return;
                  HapticFeedback.selectionClick();
                  setState(() => _activeTab = i);
                  if (i == 2) {
                    _ensureAppsLoaded();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? colorScheme.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    tabs[i].$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRecentAndRuleSearchTab(ColorScheme colorScheme) {
    final filtered = _blockedDomains.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.domain.toLowerCase().contains(_searchQuery) ||
          item.ruleText.toLowerCase().contains(_searchQuery);
    }).toList();

    final recentDomainSet = filtered.map((e) => e.domain.toLowerCase()).toSet();
    final extraRuleMatches = _ruleMatches
        .where((m) => !recentDomainSet.contains((m['domain'] ?? '').toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: '搜索最近拦截域名或直接检索规则库 (如 woozooo)…',
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
                vertical: 9,
                horizontal: 12,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (filtered.isEmpty &&
                      extraRuleMatches.isEmpty &&
                      !_searchingRules)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? '未在最近拦截与本地规则库中找到 "$_searchQuery"\n提示：若网页或应用加载异常但不知具体域名，请点击上方「网页排错」或「应用排错」'
                              : '最近暂无拦截记录',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (filtered.isNotEmpty) ...[
                          if (_searchQuery.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 4),
                              child: Text(
                                '最近拦截记录 (${filtered.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ...filtered.map(
                            (item) => _buildBlockedSummaryTile(
                              item,
                              colorScheme,
                            ),
                          ),
                        ],
                        if (_searchingRules)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        if (extraRuleMatches.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              '规则库深度检索命中 (${extraRuleMatches.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          ...extraRuleMatches.map((m) {
                            final domain = m['domain'] ?? '';
                            final rule = m['rule'] ?? '';
                            final filterName = m['filterName'] ?? '';
                            final isUnblocked =
                                _unblockedDomains.contains(domain);
                            final isBusy =
                                _unblockingInProgress.contains(domain);
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2,
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orange.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      '规则库',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      domain,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '$filterName · $rule',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: _buildUnblockButton(
                                domain,
                                isUnblocked,
                                isBusy,
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildWebTroubleshootTab(ColorScheme colorScheme) {
    final blockedItems =
        _webDomains.where((e) => e.blocked && !_unblockedDomains.contains(e.domain)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  onSubmitted: (_) => _diagnoseWebpage(),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    hintText: '粘贴异常网页链接 (如 https://m997.lanzoue.com/…)',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_urlController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() {
                              _urlController.clear();
                              _webDomains = [];
                              _webDiagnoseHint = null;
                            }),
                          ),
                        IconButton(
                          tooltip: '粘贴剪贴板链接',
                          icon: const Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                          ),
                          onPressed: () async {
                            final data =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null &&
                                data!.text!.trim().isNotEmpty) {
                              setState(() {
                                _urlController.text = data.text!.trim();
                              });
                              _diagnoseWebpage();
                            }
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _diagnosingWeb ? null : _diagnoseWebpage,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _diagnosingWeb
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('诊断'),
              ),
            ],
          ),
        ),
        if (_webDiagnoseHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _webDiagnoseHint!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (blockedItems.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _batchUnblocking
                    ? null
                    : () => _unblockAllDomains(
                          blockedItems.map((e) => e.domain).toList(),
                        ),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(
                  _batchUnblocking
                      ? '正在放行…'
                      : '一键放行全部 ${blockedItems.length} 个被拦截依赖域名',
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: _diagnosingWeb
              ? const Center(child: CircularProgressIndicator())
              : _webDomains.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          '遇到网页打不开、按钮点击无反应（如蓝奏云外链 JS 被拦截）时：\n直接粘贴网址点击「诊断」，将自动抓取网页源码中引用的所有第三方静态资源/CDN 域名并检测哪一个被规则库拦截。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _webDomains.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (context, index) {
                        final item = _webDomains[index];
                        return _buildDiagnosedDomainTile(item, colorScheme);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAppTroubleshootTab(ColorScheme colorScheme) {
    if (_selectedApp == null) {
      final filteredApps = _installedApps.where((app) {
        if (_appSearchQuery.isEmpty) return true;
        final name = (app['name'] ?? '').toString().toLowerCase();
        final pkg = (app['package'] ?? '').toString().toLowerCase();
        return name.contains(_appSearchQuery) || pkg.contains(_appSearchQuery);
      }).toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _appSearchController,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: '第一步：搜索并选择异常的应用名称或包名…',
                suffixIcon: _appSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _appSearchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 9,
                  horizontal: 12,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingApps
                ? const Center(child: CircularProgressIndicator())
                : filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          '未找到匹配应用',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredApps.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final pkg = (app['package'] ?? '').toString();
                          final name = (app['name'] ?? pkg).toString();
                          final icon = app['icon'] as Uint8List?;
                          final isAllowlisted = _allowlistedApps.contains(pkg);

                          return ListTile(
                            dense: true,
                            leading: icon != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      icon,
                                      width: 34,
                                      height: 34,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 17,
                                    backgroundColor:
                                        colorScheme.primaryContainer,
                                    child: Icon(
                                      Icons.android_rounded,
                                      size: 18,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isAllowlisted) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.green.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '已在白名单',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              pkg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedApp = app;
                                _capturedAppDomains = [];
                                _scannedAppDomains = [];
                              });
                              _scanSelectedAppDomains(app);
                            },
                          );
                        },
                      ),
          ),
        ],
      );
    }

    final app = _selectedApp!;
    final pkg = (app['package'] ?? '').toString();
    final name = (app['name'] ?? pkg).toString();
    final isAllowlisted = _allowlistedApps.contains(pkg);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selectedApp = null),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.arrow_back_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            pkg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedApp = null),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('更换应用', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _startAppCapture(app),
                        icon: const Icon(Icons.play_arrow_rounded, size: 17),
                        label: const Text(
                          '清缓存并启动抓包',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _togglingAllowlist
                            ? null
                            : () => _toggleSelectedAppAllowlist(app),
                        icon: Icon(
                          isAllowlisted
                              ? Icons.verified_user_rounded
                              : Icons.shield_outlined,
                          size: 16,
                        ),
                        label: Text(
                          isAllowlisted ? '已在全局白名单' : '加入全局白名单',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              if (_capturedAppDomains.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Text(
                    '抓包复现期间触发的拦截域名 (${_capturedAppDomains.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                ..._capturedAppDomains.map(
                  (item) => _buildBlockedSummaryTile(item, colorScheme),
                ),
                const Divider(height: 12),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '应用本地配置/缓存域名扫描 (${_scannedAppDomains.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    if (_scanningAppLocal)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      InkWell(
                        onTap: () => _scanSelectedAppDomains(app),
                        child: Text(
                          '重新扫描',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_scanningAppLocal && _scannedAppDomains.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '未在该应用本地存储中扫描到明文域名。\n建议点击上方「清缓存并启动抓包」，在应用内操作复现问题后返回本页面，即可自动捕获刚刚被拦截的域名；或者直接点击「加入全局白名单」让该应用完全绕过拦截。',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ..._scannedAppDomains.map(
                  (item) => _buildDiagnosedDomainTile(item, colorScheme),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlockedSummaryTile(
    _BlockedDomainSummary item,
    ColorScheme colorScheme,
  ) {
    final isUnblocked = _unblockedDomains.contains(item.domain);
    final isBusy = _unblockingInProgress.contains(item.domain);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 1.5,
            ),
            decoration: BoxDecoration(
              color: (item.isSni ? Colors.purple : Colors.red)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              item.isSni ? 'SNI' : 'DNS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: item.isSni ? Colors.purple : Colors.red,
              ),
            ),
          ),
          if (item.isNewAfterCapture) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                '新触发',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${_formatRelativeTime(item.latestTime)} · ${item.count}次 · ${item.ruleText}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _buildUnblockButton(item.domain, isUnblocked, isBusy),
    );
  }

  Widget _buildDiagnosedDomainTile(
    _DiagnosedDomainItem item,
    ColorScheme colorScheme,
  ) {
    final isUnblocked = _unblockedDomains.contains(item.domain);
    final isBusy = _unblockingInProgress.contains(item.domain);
    final effectiveBlocked = item.blocked && !isUnblocked;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 1.5,
            ),
            decoration: BoxDecoration(
              color: (effectiveBlocked ? Colors.red : Colors.green)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              effectiveBlocked ? '被拦截' : '正常',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: effectiveBlocked ? Colors.red : Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    effectiveBlocked ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        item.ruleText.isNotEmpty
            ? '${item.reasonText} · ${item.ruleText}'
            : item.reasonText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          color: effectiveBlocked ? Colors.red : colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: (item.blocked || isUnblocked)
          ? _buildUnblockButton(item.domain, isUnblocked, isBusy)
          : null,
    );
  }

  Widget _buildUnblockButton(String domain, bool isUnblocked, bool isBusy) {
    return FilledButton.tonal(
      onPressed: isUnblocked || isBusy ? null : () => _unblockDomain(domain),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: isBusy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              isUnblocked ? '已放行' : '放行',
              style: const TextStyle(fontSize: 12),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    '误杀排错中心',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: '刷新拦截记录',
                  onPressed: _fetchRecentBlocked,
                ),
              ],
            ),
          ),
          _buildModeSelector(colorScheme),
          Expanded(
            child: _activeTab == 0
                ? _buildRecentAndRuleSearchTab(colorScheme)
                : _activeTab == 1
                    ? _buildWebTroubleshootTab(colorScheme)
                    : _buildAppTroubleshootTab(colorScheme),
          ),
        ],
      ),
    );
  }
}
