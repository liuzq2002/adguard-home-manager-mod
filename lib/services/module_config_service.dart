import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class ModuleConfigService {
  static const String moduleConfigPath = '/data/adb/agh/scripts/config.prop';
  static const String moduleYamlPath = '/data/adb/agh/bin/AdGuardHome.yaml';
  static const MethodChannel _installedAppsChannel =
      MethodChannel('com.jgeek00.adguard_home_manager/installed_apps');

  static Map<String, dynamic>? _cachedDiag;
  static DateTime? _cachedDiagTime;
  static String? _cachedProxyUrl;
  static DateTime? _cachedProxyUrlTime;
  static List<Map<String, dynamic>>? _cachedApps;
  static DateTime? _cachedAppsTime;

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

  Future<String> readProxyUrl({bool forceRefresh = false}) async {
    if (!_isAndroid) return '';
    if (!forceRefresh &&
        _cachedProxyUrl != null &&
        _cachedProxyUrlTime != null &&
        DateTime.now().difference(_cachedProxyUrlTime!) <
            const Duration(seconds: 5)) {
      return _cachedProxyUrl!;
    }
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
      if (line.isEmpty) {
        _cachedProxyUrl = '';
        _cachedProxyUrlTime = DateTime.now();
        return '';
      }
      // 模块配置默认写入 PROXY_URL=" "（引号内一个空格）作为占位，
      // 去掉引号后再 trim，空白值统一按“未设置”处理，不显示到输入框。
      final parsed = line
          .substring(line.indexOf('PROXY_URL=') + 'PROXY_URL='.length)
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim();
      _cachedProxyUrl = parsed;
      _cachedProxyUrlTime = DateTime.now();
      return parsed;
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
      if (writeResult == 0) {
        _cachedProxyUrl = value;
        _cachedProxyUrlTime = DateTime.now();
        Process.run('su', ['-c', 'sh /data/adb/agh/scripts/ProxyConfig.sh --once >/dev/null 2>&1 &']);
      }
      return writeResult == 0;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getModuleDiagnostics({
    bool forceRefresh = false,
  }) async {
    if (!_isAndroid) {
      return {
        'running': false,
        'pid': '',
        'dnsPort': '',
        'natOk': false,
        'sniOk': false,
        'vpnMode': 'off',
        'rssMb': '',
        'allowlistCount': 0,
      };
    }
    if (!forceRefresh &&
        _cachedDiag != null &&
        _cachedDiagTime != null &&
        DateTime.now().difference(_cachedDiagTime!) <
            const Duration(seconds: 5)) {
      return Map<String, dynamic>.from(_cachedDiag!);
    }
    try {
      const cmd = '''
pid=\$(pidof AdGuardHome 2>/dev/null | awk '{print \$1}')
dns_port=\$(sed -n 's/^redir_port=//p' /data/adb/agh/scripts/config.prop 2>/dev/null | head -n 1)
iptables -w 2 -t nat -C OUTPUT -j ADGUARD >/dev/null 2>&1 && nat_ok=1 || nat_ok=0
iptables -w 2 -t filter -C OUTPUT -j AGH_SNI >/dev/null 2>&1 && sni_ok=1 || sni_ok=0
vpn_mode=\$(cat /data/adb/agh/vpn_mode_status 2>/dev/null | head -n 1)
rss_kb=""
[ -n "\$pid" ] && rss_kb=\$(awk '/^VmRSS:/ {print \$2}' "/proc/\$pid/status" 2>/dev/null)
allow_cnt=0
[ -s /data/adb/agh/app-allow.txt ] && allow_cnt=\$(grep -cvE '^[[:space:]]*(#|\$)' /data/adb/agh/app-allow.txt 2>/dev/null || echo 0)
echo "PID=\$pid"
echo "PORT=\$dns_port"
echo "NAT=\$nat_ok"
echo "SNI=\$sni_ok"
echo "VPN=\$vpn_mode"
echo "RSS=\$rss_kb"
echo "ALLOW=\$allow_cnt"
''';
      final result = await Process.run('su', ['-c', cmd]);
      if (result.exitCode != 0) {
        return {
          'running': false,
          'pid': '',
          'dnsPort': '',
          'natOk': false,
          'sniOk': false,
          'vpnMode': 'off',
          'rssMb': '',
          'allowlistCount': 0,
        };
      }
      String pid = '';
      String dnsPort = '';
      bool natOk = false;
      bool sniOk = false;
      String vpnMode = 'off';
      String rssKb = '';
      int allowlistCount = 0;
      for (final line in result.stdout.toString().split('\n')) {
        final t = line.trim();
        if (t.startsWith('PID=')) pid = t.substring(4).trim();
        if (t.startsWith('PORT=')) dnsPort = t.substring(5).trim();
        if (t.startsWith('NAT=')) natOk = t.substring(4).trim() == '1';
        if (t.startsWith('SNI=')) sniOk = t.substring(4).trim() == '1';
        if (t.startsWith('VPN=')) vpnMode = t.substring(4).trim();
        if (t.startsWith('RSS=')) rssKb = t.substring(4).trim();
        if (t.startsWith('ALLOW=')) {
          allowlistCount = int.tryParse(t.substring(6).trim()) ?? 0;
        }
      }
      String rssMb = '';
      final kb = int.tryParse(rssKb);
      if (kb != null && kb > 0) {
        rssMb = '${(kb / 1024).toStringAsFixed(1)} MB';
      }
      final diag = {
        'running': pid.isNotEmpty,
        'pid': pid,
        'dnsPort': dnsPort,
        'natOk': natOk,
        'sniOk': sniOk,
        'vpnMode': vpnMode.isEmpty ? 'off' : vpnMode,
        'rssMb': rssMb,
        'allowlistCount': allowlistCount,
      };
      _cachedDiag = diag;
      _cachedDiagTime = DateTime.now();
      return Map<String, dynamic>.from(diag);
    } catch (_) {
      return {
        'running': false,
        'pid': '',
        'dnsPort': '',
        'natOk': false,
        'sniOk': false,
        'vpnMode': 'off',
        'rssMb': '',
        'allowlistCount': 0,
      };
    }
  }

  Future<String> readModuleLogs({int maxLines = 150}) async {
    if (!_isAndroid) return '';
    try {
      final result = await Process.run(
        'su',
        ['-c', 'tail -n $maxLines /data/adb/agh/agh.log 2>/dev/null'],
      );
      if (result.exitCode != 0) return '';
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<bool> clearModuleLogs() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run(
        'su',
        ['-c', ': > /data/adb/agh/agh.log 2>/dev/null'],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reloadFirewallRules() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run(
        'su',
        [
          '-c',
          'if grep -q -- "--reload" /data/adb/agh/scripts/iptables.sh 2>/dev/null; then if pidof -x /data/adb/agh/scripts/iptables.sh >/dev/null 2>&1; then sh /data/adb/agh/scripts/iptables.sh --reload >/dev/null 2>&1; else sh /data/adb/agh/scripts/iptables.sh >/dev/null 2>&1 & fi; else rm -f /data/adb/agh/scripts/running.lock; pkill -f "/data/adb/agh/scripts/iptables.sh" 2>/dev/null; sh /data/adb/modules/AdGuardHome/service.sh >/dev/null 2>&1 & fi'
        ],
      );
      _cachedDiag = null;
      _cachedDiagTime = null;
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> flushSystemDnsCache() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run(
        'su',
        ['-c', 'ndc resolver flushenv >/dev/null 2>&1 || true'],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cleanAppAdCaches() async {
    if (!_isAndroid) return false;
    try {
      final result = await Process.run(
        'su',
        [
          '-c',
          'rm -f /data/adb/agh/last_clean_time && rmdir /data/adb/agh/cache_clean.lock 2>/dev/null; if grep -q -- "--daemon" /data/adb/agh/scripts/NoAdsService.sh 2>/dev/null; then sh /data/adb/agh/scripts/NoAdsService.sh --once >/dev/null 2>&1; else sh /data/adb/agh/scripts/NoAdsService.sh >/dev/null 2>&1 & fi'
        ],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static const List<String> _privacyEnhancementRules = [
    r'# --- [隐私增强 1] Cookie 横幅与 GDPR 弹窗同意管理平台 (Consent / CMP) ---',
    r'||cookiebot.com^$important',
    r'||cookielaw.org^$important',
    r'||optanon.blob.core.windows.net^$important',
    r'||onetrust.com^$important',
    r'||onetrust.io^$important',
    r'||privacy-mgmt.com^$important',
    r'||consensu.org^$important',
    r'||wrapper-api.sp-prod.net^$important',
    r'||cmp.quantcast.com^$important',
    r'||trustarc.com^$important',
    r'||betrad.com^$important',
    r'||didomi.io^$important',
    r'||privacy-center.org^$important',
    r'||usercentrics.eu^$important',
    r'||rlcdn.com^$important',
    r'||privacymanager.io^$important',
    r'||consent-api.exponential.com^$important',
    r'# --- [隐私增强 2] A/B 测试与特征开关遥测 (A/B Testing & Feature Flags) ---',
    r'||optimizely.com^$important',
    r'||split.io^$important',
    r'||launchdarkly.com^$important',
    r'||vwo.com^$important',
    r'||visualwebsiteoptimizer.com^$important',
    r'||abtasty.com^$important',
    r'||abtest.ai^$important',
    r'||kameleoon.eu^$important',
    r'||kameleoon.com^$important',
    r'||kameleoon.io^$important',
    r'||statsigapi.net^$important',
    r'||featuregates.org^$important',
    r'||flagsmith.com^$important',
    r'||configcat.com^$important',
    r'# --- [隐私增强 3] 错误监控、崩溃上报与前端录屏遥测 (Error Monitoring) ---',
    r'||sentry-cdn.com^$important',
    r'||getsentry.com^$important',
    r'||ravenjs.com^$important',
    r'||bugsnag.com^$important',
    r'||d2wy8f7a9ursnm.cloudfront.net^$important',
    r'||rollbar.com^$important',
    r'||raygun.io^$important',
    r'||honeybadger.io^$important',
    r'||logrocket.io^$important',
    r'||lr-ingest.com^$important',
    r'||trackjs.com^$important',
    r'||airbrake.io^$important',
    r'||nr-data.net^$important',
    r'||js-agent.newrelic.com^$important',
    r'# --- [隐私增强 4] 邮件打开像素与营销链接追踪 (Email Tracking Pixels) ---',
    r'||mailchimp.com^$important',
    r'||list-manage.com^$important',
    r'||convertkit.com^$important',
    r'||track.customer.io^$important',
    r'||customeriomail.com^$important',
    r'||dripemail2.com^$important',
    r'||getdrip.com^$important',
    r'||sendinblue.com^$important',
    r'||sibautomation.com^$important',
    r'||mailerlite.com^$important',
    r'||aweber.com^$important',
    r'||getresponse.com^$important',
    r'||activecampaign.com^$important',
    r'||trackcmp.net^$important',
    r'||pardot.com^$important',
    r'||email.mailgun.net^$important',
    r'||track.mailgun.org^$important',
    r'||mandrillapp.com^$important',
    r'||track.constantcontact.com^$important',
    r'||hubspotemail.net^$important',
    r'||track.hubspot.com^$important',
    r'||sendgrid.net^$important',
    r'# --- [隐私增强 5] 联盟营销网络与返利追踪 (Affiliate Networks) ---',
    r'||googleadservices.com^$important',
    r'||commission-junction.com^$important',
    r'||emjcd.com^$important',
    r'||anrdoezrs.net^$important',
    r'||apmebf.com^$important',
    r'||jdoqocy.com^$important',
    r'||tkqlhce.com^$important',
    r'||lduhtrp.net^$important',
    r'||awltovhc.com^$important',
    r'||ftjcfx.com^$important',
    r'||tqlkg.com^$important',
    r'||dpbolvw.net^$important',
    r'||kqzyfj.com^$important',
    r'||qksrv.net^$important',
    r'||afcyhf.com^$important',
    r'||shareasale.com^$important',
    r'||shareasale-analytics.com^$important',
    r'||shrsl.com^$important',
    r'||impact.com^$important',
    r'||impactradius-event.com^$important',
    r'||skimresources.com^$important',
    r'||ad.admitad.com^$important',
    r'||gdeslon.ru^$important',
    r'||awin1.com^$important',
    r'||dwin1.com^$important',
    r'||linksynergy.com^$important',
    r'||amazon-adsystem.com^$important',
    r'# --- [隐私增强 6] 社交追踪器与外嵌跟踪组件 (Social Trackers) ---',
    r'||facebook.net^$important',
    r'||pixel.facebook.com^$important',
    r'||an.facebook.com^$important',
    r'||staticxx.facebook.com^$important',
    r'||platform.twitter.com^$important',
    r'||syndication.twitter.com^$important',
    r'||ads-twitter.com^$important',
    r'||ads-api.twitter.com^$important',
    r'||analytics.twitter.com^$important',
    r'||platform.linkedin.com^$important',
    r'||snap.licdn.com^$important',
    r'||px.ads.linkedin.com^$important',
    r'||analytics.pointdrive.linkedin.com^$important',
    r'||ads.linkedin.com^$important',
    r'||ads.pinterest.com^$important',
    r'||log.pinterest.com^$important',
    r'||analytics.pinterest.com^$important',
    r'||ct.pinterest.com^$important',
    r'||trk.pinterest.com^$important',
    r'||widgets.pinterest.com^$important',
    r'||events.reddit.com^$important',
    r'||redditmedia.com^$important',
    r'||d.reddit.com^$important',
    r'||ads.tiktok.com^$important',
    r'||ads-api.tiktok.com^$important',
    r'||analytics.tiktok.com^$important',
    r'||ads-sg.tiktok.com^$important',
    r'||byteoversea.com^$important',
    r'||business-api.tiktok.com^$important',
    r'||analytics-sg.tiktok.com^$important',
    r'||ads.youtube.com^$important',
    r'||plus.google.com^$important',
    r'||platform.instagram.com^$important',
    r'||badges.instagram.com^$important',
    r'||addtoany.com^$important',
    r'||addthis.com^$important',
    r'||sharethis.com^$important',
    r'||st-widget.s3.amazonaws.com^$important',
    r'# --- [隐私增强 7] 跨站追踪与归因分析 (Cross-site Tracking) ---',
    r'||bat.bing.com^$important',
    r'||clarity.ms^$important',
    r'||c.bing.com^$important',
    r'||tr.snapchat.com^$important',
    r'||adsapi.snapchat.com^$important',
    r'||adjust.com^$important',
    r'||appsflyer.com^$important',
    r'||branch.io^$important',
    r'||app.link^$important',
    r'||bnc.lt^$important',
    r'||kochava.com^$important',
    r'||singular.net^$important',
    r'||adsrvr.org^$important',
    r'||tiqcdn.com^$important',
    r'||krxd.net^$important',
    r'||advertising.com^$important',
    r'||rubiconproject.com^$important',
    r'||id5-sync.com^$important',
    r'||liadm.com^$important',
    r'||revcontent.com^$important',
    r'||lijit.com^$important',
    r'||siteimproveanalytics.com^$important',
    r'||device-metrics-us.amazon.com^$important',
    r'||unagi-na.amazon.com^$important',
    r'||media.net^$important',
    r'# --- [隐私增强 8] 行为分析与热力图遥测 (Analytics & Heatmaps) ---',
    r'||google-analytics.com^$important',
    r'||analytics.google.com^$important',
    r'||googletagmanager.com^$important',
    r'||tagmanager.google.com^$important',
    r'||mc.yandex.ru^$important',
    r'||metrika.yandex.ru^$important',
    r'||mc.yandex.com^$important',
    r'||metrika.yandex.com^$important',
    r'||informer.yandex.ru^$important',
    r'||webvisor.com^$important',
    r'||hotjar.io^$important',
    r'||mouseflow.com^$important',
    r'||luckyorange.com^$important',
    r'||luckyorange.net^$important',
    r'||segment.com^$important',
    r'||segment.io^$important',
    r'||amplitude.com^$important',
    r'||mxpnl.com^$important',
    r'||mixpanel.com^$important',
    r'||heapanalytics.com^$important',
    r'||fullstory.com^$important',
    r'||pendo.io^$important',
    r'||matomo.cloud^$important',
    r'||piwik.pro^$important',
    r'||freshmarketer.com^$important',
    r'||stats.wp.com^$important',
    r'||pixel.wp.com^$important',
    r'||chartbeat.com^$important',
    r'||alexametrics.com^$important',
    r'||quantserve.com^$important',
    r'# --- [隐私增强 9] 视频贴片广告与流媒体遥测 (Video Ads) ---',
    r'||imasdk.googleapis.com^$important',
    r'||2mdn.net^$important',
    r'||pagead2.googlevideo.com^$important',
    r'||springserve.com^$important',
    r'||spotxcdn.com^$important',
    r'||spotxchange.com^$important',
    r'||teads.tv^$important',
    r'||jwpltx.com^$important',
    r'||cdn.jwplayer.com^$important',
    r'||bcvp0rtal.com^$important',
    r'||bcovlive.io^$important',
    r'||fresnel.vimeocdn.com^$important',
    r'||f.vimeocdn.com^$important',
    r'||dm.gg^$important',
    r'||ads.dailymotion.com^$important',
    r'||connatix.com^$important',
    r'||video-ads.twitter.com^$important',
    r'# --- [隐私增强 10] 厂商与系统级遥测补充 (OEM Telemetry) ---',
    r'||iadsdk.apple.com^$important',
    r'||metrics.icloud.com^$important',
    r'||metrics.mzstatic.com^$important',
    r'||api-adservices.apple.com^$important',
    r'||books-analytics-events.apple.com^$important',
    r'||weather-analytics-events.apple.com^$important',
    r'||notes-analytics-events.apple.com^$important',
    r'||xp.apple.com^$important',
    r'||supportmetrics.apple.com^$important',
    r'||settings-win.data.microsoft.com^$important',
    r'||vortex.data.microsoft.com^$important',
    r'||telemetry.microsoft.com^$important',
    r'||survey.watson.microsoft.com^$important',
    r'||app-measurement.com^$important',
    r'||firebaselogging.googleapis.com^$important',
    r'||samsungads.com^$important',
    r'||smetrics.samsung.com^$important',
    r'||nmetrics.samsung.com^$important',
    r'||samsunghealthcn.com^$important',
    r'||samsungadhub.com^$important',
    r'||samsung-com.112.2o7.net^$important',
    r'||api.ad.xiaomi.com^$important',
    r'||data.mistat.xiaomi.com^$important',
    r'||data.mistat.india.xiaomi.com^$important',
    r'||data.mistat.rus.xiaomi.com^$important',
    r'||sdkconfig.ad.xiaomi.com^$important',
    r'||sdkconfig.ad.intl.xiaomi.com^$important',
    r'||tracking.rus.miui.com^$important',
    r'||adsfs.oppomobile.com^$important',
    r'||adx.ads.oppomobile.com^$important',
    r'||ck.ads.oppomobile.com^$important',
    r'||data.ads.oppomobile.com^$important',
    r'||iot-eu-logser.realme.com^$important',
    r'||iot-logser.realme.com^$important',
    r'||bdapi-ads.realmemobile.com^$important',
    r'||bdapi-in-ads.realmemobile.com^$important',
    r'||metrics.data.hicloud.com^$important',
    r'||metrics2.data.hicloud.com^$important',
    r'||logservice.hicloud.com^$important',
    r'||logservice1.hicloud.com^$important',
    r'||logbak.hicloud.com^$important',
    r'||click.oneplus.cn^$important',
    r'||open.oneplus.net^$important',
    r'||ads-mas-us.vivobrowser.com^$important',
    r'||ads-mas.vivobrowser.com^$important',
    r'# --- [隐私增强 11] 浏览器加密货币挖矿脚本 (Crypto Mining) ---',
    r'||coinhive.com^$important',
    r'||coin-hive.com^$important',
    r'||authedmine.com^$important',
    r'||coinhive-proxy.com^$important',
    r'||coin-hive-proxy.com^$important',
    r'||crypto-loot.com^$important',
    r'||cryptoloot.pro^$important',
    r'||cryptoloot.org^$important',
    r'||minero.cc^$important',
    r'||minero-proxy.com^$important',
    r'||webmine.cz^$important',
    r'||webminepool.com^$important',
    r'||monerominer.rocks^$important',
    r'||ppoi.org^$important',
    r'||coinimp.com^$important',
    r'||coinerra.com^$important',
    r'||coin-have.com^$important',
    r'||jsecoin.com^$important',
    r'||hashforcash.us^$important',
    r'||hashing.win^$important',
    r'||bitcoinplus.com^$important',
    r'||fastpool.xyz^$important',
    r'||xmr.omine.org^$important',
    r'||minergate.com^$important',
    r'||coinhiveproxy.com^$important',
    r'||cnhv.co^$important',
    r'||afminer.com^$important',
    r'||minemytraffic.com^$important',
    r'||cpu.js.org^$important',
    r'||webminerpool.com^$important',
    r'# --- [隐私增强 12] 国际与区域广告联盟补充 (Ads Networks) ---',
    r'||pagead2.googlesyndication.com^$important',
    r'||adservice.google.com^$important',
    r'||afs.googlesyndication.com^$important',
    r'||fundingchoicesmessages.google.com^$important',
    r'||tpc.googlesyndication.com^$important',
    r'||adtago.s3.amazonaws.com^$important',
    r'||analyticsengine.s3.amazonaws.com^$important',
    r'||advice-ads.s3.amazonaws.com^$important',
    r'||aan.amazon.com^$important',
    r'||aax-eu.amazon.com^$important',
    r'||mads.amazon.com^$important',
    r'||adcolony.com^$important',
    r'||taboola.com^$important',
    r'||outbrain.com^$important',
    r'||adnxs.com^$important',
    r'||criteo.net^$important',
    r'||criteo.com^$important',
    r'||turn.com^$important',
    r'||pubmatic.com^$important',
    r'||smartadserver.com^$important',
    r'||yadro.ru^$important',
    r'||an.yandex.ru^$important',
    r'||advertising.yandex.ru^$important',
    r'||adriver.ru^$important',
    r'||adfox.ru^$important',
    r'||openx.net^$important',
  ];

  static const Set<String> deprecatedFactoryRules = {
    r'@@||googleapis.com^$important',
    r'@@||app-measurement.com^$important',
    r'@@||crashlytics.com^$important',
    r'@@||xp.apple.com^$important',
    r'||oschina.net^$important',
  };

  Future<List<String>> readFactoryUserRules() async {
    if (!_isAndroid) return [];
    try {
      const cmd = r'''
if [ -s /data/adb/agh/bin/default_user_rules.txt ]; then
  cat /data/adb/agh/bin/default_user_rules.txt
elif [ -s /data/adb/agh/backup/AdGuardHome.yaml ]; then
  awk '/^user_rules:/{f=1;next} f&&/^[a-zA-Z_]+:/{exit} f{print}' /data/adb/agh/backup/AdGuardHome.yaml | sed "s/^[[:space:]]*-[[:space:]]*//; s/^'//; s/'$//; s/^\"//; s/\"$//"
elif [ -s /data/adb/agh/bin/AdGuardHome.yaml ]; then
  awk '/^user_rules:/{f=1;next} f&&/^[a-zA-Z_]+:/{exit} f{print}' /data/adb/agh/bin/AdGuardHome.yaml | sed "s/^[[:space:]]*-[[:space:]]*//; s/^'//; s/'$//; s/^\"//; s/\"$//"
fi
''';
      final result = await Process.run('su', ['-c', cmd]);
      if (result.exitCode != 0) return [];
      final rawLines = result.stdout
          .toString()
          .split('\n')
          .map((e) => e.trimRight())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      final List<String> cleaned = [];
      final Set<String> seen = {};
      bool hasGoogleapisAllow = false;
      for (var line in rawLines) {
        final t = line.trim();
        if (t.startsWith(r"||ad.2bulu.com^$important'")) {
          line = r'||ad.2bulu.com^$important';
        }
        if (t == r'@@||googleapis.com^$important' || t == r'@@||googleapis.com^') {
          if (!hasGoogleapisAllow) {
            hasGoogleapisAllow = true;
            cleaned.add(r'@@||googleapis.com^');
            seen.add(r'@@||googleapis.com^');
          }
          continue;
        }
        if (deprecatedFactoryRules.contains(t)) continue;
        cleaned.add(line);
        seen.add(line.trim());
      }
      for (final enh in _privacyEnhancementRules) {
        if (!seen.contains(enh.trim())) {
          cleaned.add(enh);
          seen.add(enh.trim());
        }
      }
      return cleaned;
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> readAppAllowlist() async {
    if (!_isAndroid) return [];
    try {
      final result = await Process.run(
        'su',
        ['-c', '[ -f /data/adb/agh/app-allow.txt ] && cat /data/adb/agh/app-allow.txt || true'],
      );
      if (result.exitCode != 0) return [];
      return result.stdout
          .toString()
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && !e.startsWith('#'))
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveAppAllowlist(List<String> packages) async {
    if (!_isAndroid) return false;
    try {
      final content = packages.map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n');
      final escaped = content.replaceAll("'", "'\\''");
      final cmd = '''
mkdir -p /data/adb/agh
printf '%s\n' '$escaped' > /data/adb/agh/app-allow.txt
chmod 644 /data/adb/agh/app-allow.txt
sh /data/adb/agh/scripts/iptables.sh --apply-allowlist >/dev/null 2>&1 &
''';
      final result = await Process.run('su', ['-c', cmd]);
      _cachedDiag = null;
      _cachedDiagTime = null;
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getInstalledApps({
    bool includeSystem = false,
    bool forceRefresh = false,
  }) async {
    if (!_isAndroid) return [];
    if (!forceRefresh &&
        !includeSystem &&
        _cachedApps != null &&
        _cachedAppsTime != null &&
        DateTime.now().difference(_cachedAppsTime!) <
            const Duration(seconds: 60)) {
      return _cachedApps!
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    try {
      final rawList = await _installedAppsChannel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
        {
          'includeSystem': includeSystem,
          'forceRefresh': forceRefresh,
        },
      );
      if (rawList != null && rawList.isNotEmpty) {
        final List<Map<String, dynamic>> apps = [];
        for (final item in rawList) {
          if (item is Map) {
            final pkg = (item['package'] ?? '').toString().trim();
            if (pkg.isEmpty) continue;
            final rawName = (item['name'] ?? '').toString().trim();
            final name = (rawName.isNotEmpty && rawName != pkg)
                ? rawName
                : resolveKnownAppName(pkg);
            final icon = item['icon'] is Uint8List ? item['icon'] as Uint8List : null;
            final uid = item['uid'] is int ? item['uid'] as int : null;
            apps.add({
              'package': pkg,
              'name': name,
              'uid': uid,
              'icon': icon,
            });
          }
        }
        apps.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        if (!includeSystem) {
          _cachedApps = apps;
          _cachedAppsTime = DateTime.now();
        }
        return apps.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {
      // Fallback to root pm list packages below
    }

    try {
      final result = await Process.run(
        'su',
        ['-c', 'pm list packages -3 2>/dev/null || pm list packages 2>/dev/null'],
      );
      if (result.exitCode != 0) return [];
      final lines = result.stdout.toString().split('\n');
      final List<Map<String, dynamic>> apps = [];
      for (final raw in lines) {
        var pkg = raw.trim();
        if (pkg.startsWith('package:')) {
          pkg = pkg.substring('package:'.length).trim();
        }
        if (pkg.isNotEmpty) {
          apps.add({
            'package': pkg,
            'name': resolveKnownAppName(pkg),
            'uid': null,
            'icon': null,
          });
        }
      }
      apps.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      if (!includeSystem) {
        _cachedApps = apps;
        _cachedAppsTime = DateTime.now();
      }
      return apps.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static String resolveKnownAppName(String pkg) {
    const known = {
      'com.tencent.mm': '微信',
      'com.eg.android.AlipayGphone': '支付宝',
      'com.taobao.taobao': '手机淘宝',
      'com.jingdong.app.mall': '京东',
      'tv.danmaku.bili': '哔哩哔哩',
      'com.autonavi.minimap': '高德地图',
      'com.baidu.BaiduMap': '百度地图',
      'com.sankuai.meituan': '美团',
      'com.zhihu.android': '知乎',
      'com.xingin.xhs': '小红书',
      'com.ss.android.ugc.aweme': '抖音',
      'com.kuaishou.nebula': '快手',
      'com.netease.cloudmusic': '网易云音乐',
      'com.tencent.qqmusic': 'QQ音乐',
      'com.tencent.mobileqq': 'QQ',
      'com.sina.weibo': '微博',
      'com.alibaba.android.rimet': '钉钉',
      'com.tencent.wework': '企业微信',
      'com.unionpay': '云闪付',
      'com.tmall.wireless': '手机天猫',
      'com.xunmeng.pinduoduo': '拼多多',
      'com.dragon.read': '番茄免费小说',
      'com.coolapk.market': '酷安',
      'com.android.vending': 'Google Play 商店',
      'com.google.android.gms': 'Google Play 服务',
      'com.chinamworld.main': '中国建设银行',
      'com.icbc': '中国工商银行',
      'com.bankofchina.mpassport': '中国银行',
      'com.android.bankabc': '中国农业银行',
      'cmb.pb': '招商银行',
      'com.traffic.alipay.wz': '交管12123',
    };
    return known[pkg] ?? pkg;
  }

  static String resolveFilterFileName(String pathOrFile) {
    final fileName = pathOrFile.split('/').last.trim();
    const map = {
      '1721861844.txt': 'AdGuard DNS 规则',
      '1721861846.txt': 'GOODBYEADS 规则',
      '1740000001.txt': 'AWAvenue 秋风规则',
      '1.txt': 'AdGuard DNS 规则',
      '1735560833.txt': 'URLHaus 恶意域名规则',
      '8.txt': 'NoCoin 防挖矿规则',
    };
    return map[fileName] ?? fileName;
  }

  /// 在本地规则库文件 (/data/adb/agh/bin/data/filters/*.txt) 中按关键词检索拦截规则
  Future<List<Map<String, String>>> searchFilterRules(String keyword) async {
    if (!_isAndroid) return [];
    final safeKey =
        keyword.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    if (safeKey.length < 2) return [];
    try {
      final cmd =
          'grep -i -H -m 25 "$safeKey" /data/adb/agh/bin/data/filters/*.txt 2>/dev/null | head -n 60 || true';
      final result = await Process.run('su', ['-c', cmd]);
      if (result.exitCode != 0) return [];
      final lines = result.stdout.toString().split('\n');
      final List<Map<String, String>> matches = [];
      final Set<String> seenDomains = {};

      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        final colonIdx = line.indexOf(':');
        if (colonIdx <= 0) continue;
        final filePath = line.substring(0, colonIdx);
        final ruleText = line.substring(colonIdx + 1).trim();
        if (ruleText.isEmpty ||
            ruleText.startsWith('!') ||
            ruleText.startsWith('#') ||
            ruleText.startsWith('@@')) {
          continue;
        }

        String? domain;
        if (ruleText.startsWith('||')) {
          var rest = ruleText.substring(2);
          final cutIdx = rest.indexOf(RegExp(r'[\^\$/]'));
          if (cutIdx > 0) rest = rest.substring(0, cutIdx);
          domain = rest.trim();
        } else if (ruleText.startsWith('0.0.0.0 ') ||
            ruleText.startsWith('127.0.0.1 ')) {
          final parts = ruleText.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            domain = parts[1].trim();
          }
        } else {
          final m = RegExp(r'^([a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z]{2,})')
              .firstMatch(ruleText);
          if (m != null) {
            domain = m.group(1);
          }
        }

        if (domain == null ||
            domain.isEmpty ||
            !domain.contains('.') ||
            domain.contains('*')) {
          continue;
        }
        domain = domain.toLowerCase();
        if (seenDomains.contains(domain)) continue;
        seenDomains.add(domain);

        matches.add({
          'domain': domain,
          'rule': ruleText,
          'filterName': resolveFilterFileName(filePath),
        });
        if (matches.length >= 25) break;
      }
      return matches;
    } catch (_) {
      return [];
    }
  }

  /// 抓取网页源码并提取该网页引用的所有主域名与第三方外链/静态资源域名
  Future<List<String>> extractWebpageDomains(String rawInput) async {
    var trimmed = rawInput.trim();
    if (trimmed.isEmpty) return [];

    // 支持直接粘贴带有文字的分享口令，自动提取其中的链接
    final urlMatch = RegExp(r'https?://[^\s"<>]+').firstMatch(trimmed);
    if (urlMatch != null) {
      trimmed = urlMatch.group(0)!;
    } else if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://')) {
      final hostPart = trimmed.split('/').first.split(':').first.toLowerCase();
      final scheme = _isPrivateOrLoopbackHost(hostPart) ? 'http' : 'https';
      trimmed = '$scheme://$trimmed';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return [];

    final hostLower = uri.host.toLowerCase();
    final Set<String> domains = {};
    if (!_isIpLiteral(hostLower) && !_isPrivateOrLoopbackHost(hostLower)) {
      domains.add(hostLower);
    }

    Future<String> fetchHtml(String targetUrl) async {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 6)
          ..badCertificateCallback = (_, __, ___) => true;
        final req = await client.getUrl(Uri.parse(targetUrl));
        req.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        );
        final resp = await req.close().timeout(const Duration(seconds: 6));
        final bytes = await resp.fold<List<int>>(
          <int>[],
          (prev, elem) => prev.length < 262144 ? (prev..addAll(elem)) : prev,
        );
        client.close();
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        if (!_isAndroid) return '';
        try {
          final safeUrl = targetUrl.replaceAll("'", '');
          final res = await Process.run('su', [
            '-c',
            "/system/bin/curl -sS -L -k --max-time 6 -A 'Mozilla/5.0 (Linux; Android 14) Chrome/124.0.0.0 Mobile' '$safeUrl' 2>/dev/null | head -c 262144 || true"
          ]);
          return res.stdout.toString();
        } catch (_) {
          return '';
        }
      }
    }

    var mainHtml = await fetchHtml(uri.toString());
    if (mainHtml.isEmpty && uri.scheme == 'https') {
      final httpFallback = uri.replace(scheme: 'http').toString();
      mainHtml = await fetchHtml(httpFallback);
    }
    final StringBuffer allHtml = StringBuffer(mainHtml);

    // 针对蓝奏云等使用同源 iframe 嵌套下载页的站点，自动跟进 1 层同源 iframe
    if (mainHtml.isNotEmpty) {
      final iframeRegex =
          RegExp(r'<iframe[^>]+src=["\x27](/[^"\x27>]+)["\x27]', caseSensitive: false);
      int followed = 0;
      for (final m in iframeRegex.allMatches(mainHtml)) {
        final relPath = m.group(1);
        if (relPath != null && relPath.startsWith('/') && !relPath.startsWith('//')) {
          final subUrl = '${uri.scheme}://${uri.authority}$relPath';
          final subHtml = await fetchHtml(subUrl);
          if (subHtml.isNotEmpty) {
            allHtml.write('\n');
            allHtml.write(subHtml);
          }
          followed++;
          if (followed >= 2) break;
        }
      }
    }

    final htmlText = allHtml.toString();
    if (htmlText.isNotEmpty) {
      final hostRegex = RegExp(
        r'(?:https?:)?//([a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z]{2,})(?=[/:"\x27\s?>]|$)',
      );
      for (final m in hostRegex.allMatches(htmlText)) {
        final host = (m.group(1) ?? '').toLowerCase().trim();
        if (_isValidCandidateDomain(host)) {
          domains.add(host);
        }
      }
    }

    return domains.toList();
  }

  /// 扫描指定应用私有目录 (`/data/data/<pkg>`) 中缓存或配置保存的业务与接口域名
  Future<List<String>> scanAppLocalDomains(String packageName) async {
    if (!_isAndroid) return [];
    final safePkg =
        packageName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
    if (safePkg.isEmpty) return [];

    try {
      final cmd = '''
find /data/data/$safePkg/shared_prefs /data/data/$safePkg/files /data/data/$safePkg/databases /data/data/$safePkg/cache /data/data/$safePkg/app_webview -maxdepth 3 -type f -size -512k 2>/dev/null | head -n 60 | xargs grep -aEhro 'https?://[a-zA-Z0-9][-a-zA-Z0-9.]*\\.[a-zA-Z]{2,}' 2>/dev/null | sed -E 's#^https?://##; s#/.*##' | sort -u | head -n 80 || true
''';
      final result = await Process.run('su', ['-c', cmd]);
      if (result.exitCode != 0) return [];
      final lines = result.stdout.toString().split('\n');
      final Set<String> domains = {};
      for (final raw in lines) {
        final host = raw.trim().toLowerCase();
        if (_isValidCandidateDomain(host)) {
          domains.add(host);
        }
      }
      return domains.toList();
    } catch (_) {
      return [];
    }
  }

  /// 清理 DNS 缓存并冷启动目标应用，用于排错抓包复现
  Future<bool> launchAppForCapture(
    String packageName, {
    bool forceStop = true,
  }) async {
    if (!_isAndroid) return false;
    final safePkg =
        packageName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
    if (safePkg.isEmpty) return false;
    try {
      final stopCmd = forceStop ? 'am force-stop $safePkg >/dev/null 2>&1;' : '';
      final cmd = '''
$stopCmd
ndc resolver flushenv >/dev/null 2>&1 || true
ndc resolver flushdefaultif >/dev/null 2>&1 || true
cmd netd resolver flushdefaultif >/dev/null 2>&1 || true
monkey -p $safePkg -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
''';
      final result = await Process.run('su', ['-c', cmd]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static bool _isIpLiteral(String host) {
    final clean = host.replaceAll('[', '').replaceAll(']', '');
    return InternetAddress.tryParse(clean) != null;
  }

  static bool _isPrivateOrLoopbackHost(String host) {
    final h = host.toLowerCase().replaceAll('[', '').replaceAll(']', '');
    if (h == 'localhost' ||
        h.endsWith('.local') ||
        h.endsWith('.lan') ||
        h.endsWith('.home.arpa') ||
        h.endsWith('.in-addr.arpa') ||
        h.endsWith('.ip6.arpa')) {
      return true;
    }
    final ip = InternetAddress.tryParse(h);
    if (ip == null) return false;
    if (ip.isLoopback || ip.isLinkLocal || ip.isMulticast) return true;
    final raw = ip.rawAddress;
    if (raw.length == 4) {
      final b0 = raw[0];
      final b1 = raw[1];
      // 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16
      if (b0 == 127 || b0 == 10) return true;
      if (b0 == 172 && b1 >= 16 && b1 <= 31) return true;
      if (b0 == 192 && b1 == 168) return true;
      if (b0 == 169 && b1 == 254) return true;
    } else if (raw.length == 16) {
      // fc00::/7 (Unique Local) or fe80::/10 (Link-Local)
      if ((raw[0] & 0xfe) == 0xfc || (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80)) {
        return true;
      }
    }
    return false;
  }

  static bool _isValidCandidateDomain(String host) {
    if (host.isEmpty || host.length > 120 || !host.contains('.')) return false;
    if (host.startsWith('.') || host.endsWith('.')) return false;
    if (_isIpLiteral(host) || _isPrivateOrLoopbackHost(host)) return false;
    const ignoredHosts = {
      'schemas.android.com',
      'www.w3.org',
      'ns.adobe.com',
      'xmlpull.org',
      'localhost',
      'example.com',
      'www.example.com',
    };
    if (ignoredHosts.contains(host)) return false;

    final tld = host.split('.').last;
    const invalidFileExts = {
      'js',
      'css',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'svg',
      'ico',
      'woff',
      'woff2',
      'ttf',
      'eot',
      'mp3',
      'mp4',
      'json',
      'xml',
      'html',
      'htm',
      'apk',
      'dex',
      'so',
      'zip',
      'rar',
      '7z',
      'txt',
      'log',
      'db',
      'sqlite',
    };
    if (invalidFileExts.contains(tld)) return false;
    return RegExp(r'^[a-z0-9][-a-z0-9.]*\.[a-z]{2,}$').hasMatch(host);
  }
}

