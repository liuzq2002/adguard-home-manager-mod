<h1 align="center">
  <img src="assets/other/banner.png" />
</h1>

<h5 align="center">
  <b>
    AdGuard Home Manager (Mod) —— 面向 AdGuard Home For Android 模块的管理器
  </b>
</h5>

<p align="center">
  <a href="https://github.com/liuzq2002/adguard-home-manager-mod" target="_blank" rel="noopener noreferrer">
    GitHub 仓库
  </a>
  ·
  <a href="https://github.com/liuzq2002/adguard-home-manager-mod/releases" target="_blank" rel="noopener noreferrer">
    Releases
  </a>
</p>

<br>

## 简介

本项目是 [JGeek00/adguard-home-manager](https://github.com/JGeek00/adguard-home-manager) 的修改版，针对
[AdGuard Home For Android](https://github.com/liuzq2002/Adguard-Home-For-Magisk-Mod)（Magisk / KernelSU 模块）做了精简与深度集成。

模块开机时会随机化 AdGuard Home 的管理端口，本应用会自动读取
`/data/adb/agh/bin/AdGuardHome.yaml` 中的 `http.address` 并自动连接，无需手动配置服务器。

## 与原版的差异

### 移除

- 首次连接引导页（自动读取模块随机端口后自动接入）
- 客户端（Clients）页面
- 首页服务器状态卡片与悬浮按钮
- 设置中的：安全搜索、访问设置、DHCP、加密、服务器信息、服务器、常规、高级、更新

### 新增 / 修改

- 应用包名改为 `com.liuzq2002.adguard_home_manager`
- 自动读取并保存模块管理端口，自动创建 `root/root` 连接
- 首页仅保留“全部保护”开关与暂停时间选择（30 秒 / 1 分钟 / 10 分钟 / 1 小时 / 24 小时）
- 设置内可直接写入 `/data/adb/agh/scripts/config.prop` 的 `PROXY_URL` 订阅链接（保存后需重启生效）
- 通知栏快捷磁贴开关（需在 KernelSU / Magisk 中授予本应用 root 权限）

### 保留

- 首页图表与 Top Items
- 日志、统计、DNS、DNS 重写、个性化、关于等设置

## 主要功能

- 一键开启 / 暂停全部保护，并支持定时暂停
- 自动连接 AdGuard Home 模块（HTTP/HTTPS）
- 查询日志与统计
- DNS 与 DNS 重写配置
- 订阅链接（PROXY_URL）配置
- 通知栏快捷开关

## 构建

### 环境要求

- Flutter 3.x（本项目使用 3.44 验证）
- Android SDK / JDK（仅需要 Android，其他平台目录已移除）

本项目只构建 **Android arm64-v8a** 架构的 APK，其他系统/架构均不支持。

### 步骤

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
```

APK 输出位置：`build/app/outputs/flutter-apk/app-release.apk`（仅含 arm64-v8a）

### 签名

首次发布前需要生成签名，参考 `android/key.properties.sample`：

```bash
keytool -genkeypair -v -keystore app/aghm-release.keystore \
  -alias aghm -keyalg RSA -keysize 2048 -validity 10000
```

然后在 `android/key.properties` 中填写 `storePassword`、`keyPassword`、`keyAlias`、`storeFile`。

## 免责声明

本项目是**非官方**客户端 与 AdGuard 官方 、AdGuard Home 团队以及 JGeek00 原始项目没有任何关联。
请勿用于任何违反法律法规的用途。

## 许可证与合规

本项目基于 [JGeek00/adguard-home-manager](https://github.com/JGeek00/adguard-home-manager) 修改而来，
遵循原作者采用的 **Apache License 2.0** 开源许可证。

- 原始版权：Copyright 2022 JGeek00
- 修改版权：Copyright 2026 liuzq2002
- 完整许可证文本见 [LICENSE.md](LICENSE.md)
- 修改声明见 [NOTICE](NOTICE)

本项目不设捐赠，永久开源免费。
