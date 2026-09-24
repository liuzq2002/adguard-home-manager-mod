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

## 本版变更（v2.24.2）

- 修复输入框浮动标签卡在边框上的问题：统一输入框边框/标签样式，PROXY_URL 改为标题在上、输入框在下
- PROXY_URL 去掉示例占位符，空状态不再显示假链接，保存后直接显示订阅链接
- 拦截模式只保留“默认”，移除 REFUSED / NXDOMAIN / 空 IP / 自定义 IP，并精简说明文案

## 上一版变更（v2.24.1）

- 全局 MIUIX 化：Material 主题改为由 MIUIX / Monet 配色生成，AppBar、对话框、卡片、Chip、输入框、Snackbar、底部弹层等统一为 HyperOS 风格的平面化 + 大圆角
- 通用控件换成 MIUIX：开关、复选框、单选框、底部导航、主页主开关卡片
- 说明：MIUIX 是一套独立控件库，Material 组件不会自动变成 MIUIX 控件；本版的做法是全局配色/形状 MIUIX 化 + 高频交互控件原生 MIUIX 化

## 上一版变更（v2.24.0）

- 引入 MIUIX（HyperOS 风格）设计：应用级主题配色、底部导航栏、主页主开关卡片与通用开关控件
- 移除服务器版本校验：自定义核心的日期版本号（如 v2026-09-23）不再被误判为版本过低，也不会再弹出“不支持的服务器版本”
- 优化：删除版本校验相关死代码与无用页面；MIUIX 配色按种子色缓存，避免每次重建重复计算；主页图表加入 RepaintBoundary，降低滚动时的重绘开销
- 发布流程：release workflow 会校验 pubspec 版本与 tag 是否一致，并自动使用本文件作为 Release 说明

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
