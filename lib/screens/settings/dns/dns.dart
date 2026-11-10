// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:adguard_home_manager/l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/settings/dns/test_upstream_dns_modal.dart';
import 'package:adguard_home_manager/screens/settings/dns/clear_dns_cache_dialog.dart';
import 'package:adguard_home_manager/widgets/custom_switch_list_tile.dart';
import 'package:adguard_home_manager/widgets/section_label.dart';

import 'package:adguard_home_manager/classes/process_modal.dart';
import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/functions/clear_dns_cache.dart';
import 'package:adguard_home_manager/functions/snackbar.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/dns_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class DnsSettings extends StatefulWidget {
  final bool splitView;

  const DnsSettings({
    super.key,
    this.splitView = false,
  });

  @override
  State<DnsSettings> createState() => _DnsSettingsState();
}

class _DnsSettingsState extends State<DnsSettings> {
  final _upstreamController = TextEditingController();
  final _bootstrapController = TextEditingController();
  final _fallbackController = TextEditingController();

  String _upstreamMode = '';
  String _blockingMode = 'default';
  bool _optimisticCache = true;
  bool _disableIpv6 = false;
  bool _enableDnssec = false;
  bool _enableEdns = false;
  bool _userModified = false;

  @override
  void initState() {
    super.initState();
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);
    if (dnsProvider.dnsInfo != null) {
      _applyInfo(dnsProvider.dnsInfo!);
    }
    _loadData();
  }

  @override
  void dispose() {
    _upstreamController.dispose();
    _bootstrapController.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);
    final ok = await dnsProvider.fetchDnsData(
      showLoading: dnsProvider.dnsInfo == null,
    );
    if (!mounted) return;
    if (ok && dnsProvider.dnsInfo != null && !_userModified) {
      setState(() {
        _applyInfo(dnsProvider.dnsInfo!);
      });
    }
  }

  void _applyInfo(dynamic info) {
    _upstreamController.text = info.upstreamDns.join('\n');
    _bootstrapController.text = info.bootstrapDns.join('\n');
    _fallbackController.text = (info.fallbackDns ?? []).join('\n');
    final mode = info.upstreamMode ?? '';
    _upstreamMode = (mode == 'load_balance') ? '' : mode;
    _blockingMode = info.blockingMode == 'strong' ? 'strong' : 'default';
    _optimisticCache = info.cacheOptimistic ?? true;
    _disableIpv6 = info.disableIpv6;
    _enableDnssec = info.dnssecEnabled;
    _enableEdns = info.ednsCsEnabled;
  }

  List<String> _parseLines(String raw) {
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _applyPreset({
    required List<String> upstreams,
    required List<String> bootstraps,
    List<String>? fallbacks,
    required String mode,
    required String presetName,
  }) async {
    HapticFeedback.lightImpact();
    setState(() {
      _userModified = true;
      _upstreamController.text = upstreams.join('\n');
      _bootstrapController.text = bootstraps.join('\n');
      if (fallbacks != null) {
        _fallbackController.text = fallbacks.join('\n');
      }
      _upstreamMode = mode;
    });
    await _saveAll(silent: true, customSuccessLabel: '已应用并保存「$presetName」');
  }

  Future<void> _saveAll({
    bool silent = false,
    String? customSuccessLabel,
  }) async {
    final dnsProvider = Provider.of<DnsProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final isZh = Localizations.localeOf(context)
        .languageCode
        .toLowerCase()
        .startsWith('zh');

    final upstreams = _parseLines(_upstreamController.text);
    final bootstraps = _parseLines(_bootstrapController.text);
    final fallbacks = _parseLines(_fallbackController.text);

    if (upstreams.isEmpty || bootstraps.isEmpty) {
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: isZh
            ? '上游 DNS 与 Bootstrap DNS 不能为空'
            : 'Upstream DNS and Bootstrap DNS cannot be empty',
        color: Colors.red,
      );
      return;
    }

    ProcessModal? processModal;
    if (!silent) {
      processModal = ProcessModal();
      processModal.open(AppLocalizations.of(context)!.savingConfig);
    }

    final info = dnsProvider.dnsInfo;
    final result = await dnsProvider.saveUnifiedDnsConfig({
      'upstream_dns': upstreams,
      'upstream_mode': _upstreamMode,
      'bootstrap_dns': bootstraps,
      'fallback_dns': fallbacks,
      'blocking_mode': _blockingMode,
      'edns_cs_enabled': _enableEdns,
      'dnssec_enabled': _enableDnssec,
      'disable_ipv6': _disableIpv6,
      'cache_optimistic': _optimisticCache,
      // 保留后端原有高级数值参数，无需用户在手机上手填
      if (info?.cacheSize != null) 'cache_size': info!.cacheSize,
      if (info?.cacheTtlMin != null) 'cache_ttl_min': info!.cacheTtlMin,
      if (info?.cacheTtlMax != null) 'cache_ttl_max': info!.cacheTtlMax,
      if (info?.ratelimit != null) 'ratelimit': info!.ratelimit,
    });

    processModal?.close();
    if (!mounted) return;

    if (result.successful) {
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: customSuccessLabel ?? AppLocalizations.of(context)!.dnsConfigSaved,
        color: Colors.green,
      );
    } else {
      showSnackbar(
        appConfigProvider: appConfigProvider,
        label: result.statusCode == 400
            ? AppLocalizations.of(context)!.someValueNotValid
            : AppLocalizations.of(context)!.dnsConfigNotSaved,
        color: Colors.red,
      );
    }
  }

  Future<void> _clearCache() async {
    final serversProvider =
        Provider.of<ServersProvider>(context, listen: false);
    final appConfigProvider =
        Provider.of<AppConfigProvider>(context, listen: false);
    final result =
        await clearDnsCache(context, serversProvider.selectedServer!);
    if (!mounted) return;
    showSnackbar(
      appConfigProvider: appConfigProvider,
      label: result.successful == true
          ? AppLocalizations.of(context)!.dnsCacheCleared
          : AppLocalizations.of(context)!.dnsCacheNotCleared,
      color: result.successful == true ? Colors.green : Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dnsProvider = Provider.of<DnsProvider>(context);
    final isZh = Localizations.localeOf(context)
        .languageCode
        .toLowerCase()
        .startsWith('zh');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dnsSettings),
        actions: [
          IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => const TestUpstreamDnsModal(),
            ),
            icon: const Icon(Icons.speed_rounded),
            tooltip: AppLocalizations.of(context)!.testUpstreamDnsServers,
          ),
          IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => ClearDnsCacheDialog(onConfirm: _clearCache),
            ),
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: AppLocalizations.of(context)!.clearDnsCache,
          ),
          IconButton(
            onPressed:
                dnsProvider.loadStatus == LoadStatus.loaded ? _saveAll : null,
            icon: const Icon(Icons.save_rounded),
            tooltip: AppLocalizations.of(context)!.save,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            switch (dnsProvider.loadStatus) {
              case LoadStatus.loading:
                return const Center(child: CircularProgressIndicator());

              case LoadStatus.error:
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context)!.dnsConfigNotLoaded),
                    ],
                  ),
                );

              case LoadStatus.loaded:
                return ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    SectionLabel(
                      label: isZh
                          ? '一键加密 DNS 预设（国内外通用）'
                          : 'Quick Encrypted DNS Presets',
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.flash_on_rounded, size: 16),
                            label: Text(
                              isZh
                                  ? '国内极速 (阿里 + 腾讯 DoH)'
                                  : 'CN Fast (AliDNS + DNSPod)',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            onPressed: () => _applyPreset(
                              presetName: isZh
                                  ? '国内极速 (阿里 + 腾讯)'
                                  : 'CN Fast (AliDNS + DNSPod)',
                              upstreams: const [
                                'https://223.5.5.5/dns-query',
                                'https://1.12.12.12/dns-query',
                              ],
                              bootstraps: const [
                                '223.5.5.5',
                                '119.29.29.29',
                                '223.6.6.6',
                                '1.1.1.1',
                                '8.8.8.8',
                              ],
                              fallbacks: const [
                                'https://223.5.5.5/dns-query',
                                'https://223.6.6.6/dns-query',
                                'https://1.12.12.12/dns-query',
                                'https://1.1.1.1/dns-query',
                                'https://8.8.8.8/dns-query',
                              ],
                              mode: 'parallel',
                            ),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.public_rounded, size: 16),
                            label: Text(
                              isZh
                                  ? '海外优选 (CF + Google + 境内政务分流)'
                                  : 'Global Fast (CF + Google + CN Split)',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            onPressed: () => _applyPreset(
                              presetName: isZh
                                  ? '海外优选 (CF + Google + 境内政务分流)'
                                  : 'Global Fast (CF + Google)',
                              upstreams: const [
                                '[/gov.cn/edu.cn/12306.cn/]https://223.5.5.5/dns-query',
                                '[/gov.cn/edu.cn/12306.cn/]https://1.12.12.12/dns-query',
                                'https://1.1.1.1/dns-query',
                                'https://1.0.0.1/dns-query',
                                'https://8.8.8.8/dns-query',
                                'https://9.9.9.9/dns-query',
                              ],
                              bootstraps: const [
                                '1.1.1.1',
                                '1.0.0.1',
                                '8.8.8.8',
                                '9.9.9.9',
                                '223.5.5.5',
                                '119.29.29.29',
                              ],
                              fallbacks: const [
                                'https://1.1.1.1/dns-query',
                                'https://1.0.0.1/dns-query',
                                'https://8.8.8.8/dns-query',
                                'https://8.8.4.4/dns-query',
                                'https://9.9.9.9/dns-query',
                                'https://223.5.5.5/dns-query',
                                'https://1.12.12.12/dns-query',
                              ],
                              mode: 'parallel',
                            ),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.shield_outlined, size: 16),
                            label: Text(
                              isZh
                                  ? '海外纯净隐私 (Quad9 + Mullvad)'
                                  : 'Global Privacy (Quad9 + Mullvad)',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            onPressed: () => _applyPreset(
                              presetName: isZh
                                  ? '海外纯净隐私 (Quad9 + Mullvad)'
                                  : 'Global Privacy (Quad9 + Mullvad)',
                              upstreams: const [
                                'https://9.9.9.9/dns-query',
                                'https://dns.mullvad.net/dns-query',
                              ],
                              bootstraps: const [
                                '9.9.9.9',
                                '1.1.1.1',
                              ],
                              mode: 'parallel',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SectionLabel(
                      label: AppLocalizations.of(context)!.upstreamDns,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _upstreamController,
                        onChanged: (_) => _userModified = true,
                        minLines: 3,
                        maxLines: 6,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          hintText:
                              'https://1.1.1.1/dns-query\nhttps://8.8.8.8/dns-query',
                          helperText: isZh
                              ? '每行填写一个上游 DNS 地址（支持 DoH / DoT / DoQ / IP，# 开头为注释）'
                              : 'One upstream DNS server per line (DoH / DoT / DoQ / IP, # for comments)',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment<String>(
                            value: '',
                            label: Text(
                              isZh ? '负载均衡' : 'Load Balance',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'parallel',
                            label: Text(
                              isZh ? '并行请求' : 'Parallel',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'fastest_addr',
                            label: Text(
                              isZh ? '最快 IP' : 'Fastest IP',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        selected: {
                          {'', 'parallel', 'fastest_addr'}
                                  .contains(_upstreamMode)
                              ? _upstreamMode
                              : ''
                        },
                        onSelectionChanged: (v) {
                          setState(() {
                            _userModified = true;
                            _upstreamMode = v.first;
                          });
                          _saveAll(silent: true);
                        },
                      ),
                    ),
                    SectionLabel(
                      label: AppLocalizations.of(context)!.bootstrapDns,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _bootstrapController,
                        onChanged: (_) => _userModified = true,
                        minLines: 2,
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          hintText: '223.5.5.5\n1.1.1.1',
                          helperText: isZh
                              ? '用于解析上方加密 DNS 域名的纯 IP 服务器（每行一个）'
                              : 'Plain IP servers used to resolve encrypted upstream hostnames (one per line)',
                        ),
                      ),
                    ),
                    SectionLabel(
                      label: AppLocalizations.of(context)!.fallbackDnsServers,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _fallbackController,
                        onChanged: (_) => _userModified = true,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          hintText: isZh ? '选填，每行一个后备 DNS' : 'Optional, one per line',
                        ),
                      ),
                    ),
                    SectionLabel(
                      label: isZh ? '拦截模式与解析策略' : 'Blocking & Resolution Strategy',
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment<String>(
                            value: 'default',
                            icon: const Icon(Icons.shield_outlined, size: 16),
                            label: Text(
                              isZh
                                  ? '默认模式 (0.0.0.0)'
                                  : 'Default (0.0.0.0)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'strong',
                            icon: const Icon(Icons.security_rounded, size: 16),
                            label: Text(
                              isZh
                                  ? '强力模式 (拒绝连接)'
                                  : 'Strong (REFUSED)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        selected: {_blockingMode},
                        onSelectionChanged: (v) {
                          setState(() {
                            _userModified = true;
                            _blockingMode = v.first;
                          });
                          _saveAll(silent: true);
                        },
                      ),
                    ),
                    CustomSwitchListTile(
                      value: _optimisticCache,
                      onChanged: (v) {
                        setState(() {
                          _userModified = true;
                          _optimisticCache = v;
                        });
                        _saveAll(silent: true);
                      },
                      title: AppLocalizations.of(context)!.optimisticCaching,
                      subtitle: AppLocalizations.of(context)!
                          .optimisticCachingDescription,
                    ),
                    CustomSwitchListTile(
                      value: _disableIpv6,
                      onChanged: (v) {
                        setState(() {
                          _userModified = true;
                          _disableIpv6 = v;
                        });
                        _saveAll(silent: true);
                      },
                      title: AppLocalizations.of(context)!.disableResolvingIpv6,
                      subtitle: AppLocalizations.of(context)!
                          .disableResolvingIpv6Description,
                    ),
                    CustomSwitchListTile(
                      value: _enableDnssec,
                      onChanged: (v) {
                        setState(() {
                          _userModified = true;
                          _enableDnssec = v;
                        });
                        _saveAll(silent: true);
                      },
                      title: AppLocalizations.of(context)!.enableDnssec,
                      subtitle:
                          AppLocalizations.of(context)!.enableDnssecDescription,
                    ),
                    CustomSwitchListTile(
                      value: _enableEdns,
                      onChanged: (v) {
                        setState(() {
                          _userModified = true;
                          _enableEdns = v;
                        });
                        _saveAll(silent: true);
                      },
                      title: AppLocalizations.of(context)!.enableEdns,
                      subtitle:
                          AppLocalizations.of(context)!.enableEdnsDescription,
                    ),
                  ],
                );
            }
          },
        ),
      ),
    );
  }
}
