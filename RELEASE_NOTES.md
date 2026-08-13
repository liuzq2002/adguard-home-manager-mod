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

## 本版变更

- 仅保留 Android arm64-v8a 架构，移除 iOS / macOS / Linux / Windows / Debian 平台目录
- 应用包名：com.liuzq2002.adguard_home_manager
- 移除原版中与模块场景无关的功能入口，深度集成 AdGuard Home For Android 模块

## 下载

- app-release.apk（arm64-v8a）

## 许可证与合规

本项目遵循 Apache License 2.0，基于 JGeek00/adguard-home-manager 修改而来。
原始版权归 JGeek00 所有，修改版权归 liuzq2002，详见仓库 LICENSE.md 与 NOTICE。

本项目为**非官方**客户端，与 AdGuard 官方、AdGuard Home 团队以及原始项目无任何关联。
