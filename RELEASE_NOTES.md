## 简介

AdGuard Home Manager (Mod) 是基于 JGeek00/adguard-home-manager 修改的 AdGuard Home 模块管理器，
适配 AdGuard Home For Android（Magisk / KernelSU）模块，自动读取模块随机端口并连接。

## 安装要求

- Android arm64-v8a 设备（本包仅包含 arm64 架构）
- 已安装并启用 AdGuard Home For Android 模块
- 已在 KernelSU / Magisk 中授予本应用 root 权限

## 主要功能

- 一键开启 / 暂停全部保护，支持 30 秒 / 1 分钟 / 10 分钟 / 1 小时 / 24 小时定时暂停
- 自动读取 /data/adb/agh/bin/AdGuardHome.yaml 中的管理端口并自动连接
- PROXY_URL 订阅链接配置（保存后需重启设备或模块生效）
- 通知栏快捷磁贴开关
- 日志、统计、DNS、DNS 重写等核心设置

## 预发布 v2.24.1Pre（清理未使用代码）

- 修复精简核心兼容性：服务器状态不再强制请求已移除的 `/safesearch/status`，安全浏览/家长控制等可选接口失败时按默认值处理，不会再出现「无法加载服务器状态」
- 修复精简核心兼容性：`/stats` 缺少 `num_replaced_safesearch` 字段时不再解析报错
- 移除调用已删除接口的功能：客户端「安全搜索」「被拦截的服务」入口及相关页面/API
- 删除 30+ 个无引用文件：legacy HTTP API（`http_requests.dart`）、未接入的安全搜索设置页、主题弹窗、通用/高级/访问设置页、服务器更新页、管理弹窗、侧边导航栏等
- 删除 20+ 个无引用方法与工具函数（各 Provider 中的死 setter、无引用格式化/判断函数）
- 移除不再被引用的依赖：`flutter_html`、`markdown`、`flutter_reorderable_list`
- 内部版本 2.24.4+161（≥ 2.24.3，可覆盖安装）

## 正式版 v2.24.0

- 全局 MIUIX（HyperOS 风格）化：Material 主题由 MIUIX / Monet 配色生成，AppBar、对话框、卡片、Chip、输入框、Snackbar、底部弹层统一为平面化 + 大圆角；开关、复选框、单选框、底部导航、主页主开关卡片换成原生 MIUIX 控件
- 移除服务器版本校验：自定义核心的日期版本号（如 v2026-09-23）不再被误判为版本过低，也不会弹出“不支持的服务器版本”
- 输入框样式修复：浮动标签不再卡在边框上；PROXY_URL 改为标题在上、输入框在下，输入框内提示“填写代理订阅链接到此处”
- PROXY_URL 空格占位处理：配置文件里的 `PROXY_URL=" "` 不再显示到输入框（视为未设置）；保存时用订阅链接替换该占位
- 拦截模式只保留“默认”，移除 REFUSED / NXDOMAIN / 空 IP / 自定义 IP，并精简说明文案
- 优化：删除版本校验等死代码与无用页面；MIUIX 配色按种子色缓存；主页图表加入 RepaintBoundary，降低滚动时的重绘开销
- 发布策略：正式版本号以 tag 为准（本版为 v2.24.0），内部版本保持递增（当前 2.24.3+160），未测试通过前只发预发布

## 更早版本（v2.23.0）

- 升级 Flutter / Dart 依赖及 Android 构建工具链（Gradle 8.14.3、AGP 8.11.1、Kotlin 2.2.20）
- 开启 R8 混淆与资源压缩，减小 APK 体积
- 移除主页统计中的“被拦截的恶意/钓鱼网站”“被拦截的成人网站”“客户端排行”
- 移除日志过滤器中的“客户端”筛选入口
- 移除日志响应状态中的“已拦截（安全浏览 / 家长过滤 / 安全搜索）”细分选项
- 移除“过滤器”页中的“被拦截的服务”入口
- 移除上述功能对应的无用页面，并重新生成本地化字符串

## 下载

- app-release.apk（arm64-v8a）

## 许可证与合规

本项目遵循 Apache License 2.0，基于 JGeek00/adguard-home-manager 修改而来。
原始版权归 JGeek00 所有，修改版权归 liuzq2002，详见仓库 LICENSE.md 与 NOTICE。

本项目为**非官方**客户端，与 AdGuard 官方、AdGuard Home 团队以及原始项目无任何关联。
