# 项目交接说明（AdGuard Home Manager Mod）

> 给下一个对话/下一个协作者看的上下文文档。改动前请先读完「约定与坑」一节。

## 1. 项目概览

- 本地路径：`C:\H11111\adguard-home-manager`
- 远端仓库：https://github.com/liuzq2002/adguard-home-manager-mod
- 类型：Flutter Android 应用（AdGuard Home 客户端，魔改 fork，适配 Magisk/KernelSU 上的 AdGuard Home 模块）
- 只出 Android **arm64-v8a** 单架构包，桌面/iOS 目录已移除

工具链（CI 固定，本地保持一致）：

| 项 | 版本 |
|---|---|
| Flutter | 3.44.4（stable） |
| Dart | 3.12.2 |
| Gradle | 8.14.3 |
| AGP | 8.11.1 |
| Kotlin | 2.2.20 |
| compileSdk / targetSdk | 36 |
| minSdk | 26 |

## 2. 版本号与命名规则（重要）

- **正式版版本号以 git tag 为准**，当前正式版为 `v2.24.0`。
- 预发布 tag 形如 `v2.24.1-pre.1`、`v2.24.1-rc.1`、`v2.24.1-beta.1`；稳定版无后缀。
- `pubspec.yaml` 里的 `version:` = **内部版本**：
  - 版本名跟随当前预发布 tag（例如 `2.24.1`）；
  - `+build` 必须**单调递增、只增不减**（当前 `+163`）。即使版本名回退，`+build` 也不能变小，否则 Android 无法覆盖安装。
- 发布产物命名：`adguard-home-manager-mod-{tag}.apk`
  - 正式版：`adguard-home-manager-mod-v2.24.0.apk`
  - 预发布：`adguard-home-manager-mod-v2.24.1-pre.2.apk`
  - 不带 ABI 后缀（只出 arm64）。

## 3. 发版流程

工作流（`.github/workflows/`）：

| 文件 | 触发 | 作用 |
|---|---|---|
| `ci.yml` | main push / PR | `flutter analyze` + debug 构建 |
| `prerelease.yml` | tag `v*-pre.*` / `v*-rc.*` / `v*-beta.*` | 预发布（`--prerelease`） |
| `release.yml` | tag `v*`（**不带** `-`） | 正式版 |
| `_build-and-release.yml` | 被上面两个调用 | 共享：签名校验 → 构建 → 上传（重试 5 次 + 上传后校验） → 符号 artifact |

发一个预发布：

```bash
# 1) 改 pubspec.yaml：version 名对齐 tag，+build 递增
#    例：version: 2.24.1+164
# 2) 更新 RELEASE_NOTES.md
# 3) 提交并推送 main
git add -A && git commit -m "..." && git push origin main
# 4) 打 tag（类型用 pre / rc / beta）
git tag -a v2.24.1-pre.3 -m "AdGuard Home Manager Mod v2.24.1-pre.3"
git push origin v2.24.1-pre.3
```

转正式版：测试没问题后，在 GitHub Release 页面取消勾选 “Set as a pre-release”；或另打不带后缀的 tag 走 `release.yml`。

签名 secrets（仓库 Settings → Secrets）：`SIGNING_KEYSTORE_B64`、`SIGNING_PROPERTIES_B64`。

## 4. 约定与坑（务必遵守）

1. **不要本地跑构建**（用户明确要求），一律交给 CI 验证；本地清理用 `flutter clean`。
2. **不要执行 `dart format lib`**：会把约 170 个无关文件重排，diff 爆炸。只对本次改动文件执行 `dart format <files>`。
3. 本机 PowerShell 的 `Remove-Item` 被环境策略拦截；删代码文件用 `apply_patch`，删/挪构建产物用 `Move-Item` 到 `%TEMP%\aghm_cleanup_*`。
4. **签名文件不要动**：
   - 原始：`C:\H11111\key.properties`、`C:\H11111\aghm-release.keystore`
   - 仓库内副本：`android/key.properties`、`android/app/aghm-release.keystore`（gitignore，仅本地构建用）
5. `pubspec.lock` 记录的是国内镜像 `pub.flutter-io.cn`；CI 走 `pub.dev`，所以 CI 日志会有 `Changed 97 dependencies!` 并解析出略新的传递依赖。曾尝试在 CI 固定镜像，被要求回退，**现保持 CI 用 pub.dev**。要彻底消除，需用 pub.dev 重新生成一次 lock 并提交。
6. DWARF 警告 `The generated ELF library contains unobfuscated DWARF debugging information` 是**上游误报**（flutter/flutter#190267）：警告由 `gen_snapshot` 发出，符号实际由 AGP 在打包阶段剥离，最终 APK 已确认无 `.debug_info`。**不要**加 `--extra-gen-snapshot-options=--strip`，会导致构建失败。
7. `applies the Kotlin Gradle Plugin ... will cause build failures in future versions of Flutter`：等 Flutter/AGP 9 的 built-in Kotlin 再迁移，现在不动。
8. Git 跟踪：`build/`、`.dart_tool/`、`android/app/build/` 等均已在 `.gitignore`，不存在构建产物被跟踪的情况。阶段性改动建议先推分支再合 main。

## 5. 精简核心（自定义 AGH）相关

模块侧的核心删掉了一批接口，管理器已相应移除对应功能，**不要再加回来**：

- `/safesearch/*`（安全搜索）、`/blocked_services/*`（被拦截的服务）
- `/clients`、`/access/list`、`/access/set`、`/clients/add|update|delete`（客户端列表/访问设置）
- `/dhcp/*`（DHCP 页面）
- 服务器版本校验（日期版本号如 `v2026-09-23` 曾被判为过低）已整体移除

首页状态现在只强依赖：`/stats`、`/status`、`/filtering/status`；`/safebrowsing/status`、`/parental/status` 为可选（失败按默认值处理）。

## 6. 已完成的优化

- 体积：R8 + 资源收缩、`--obfuscate --split-debug-info`、图标字体 tree-shaking、只出 arm64、资源语言裁剪（en/zh）、关闭 v1 签名、移除未使用依赖（`flutter_html`、`markdown`、`flutter_reorderable_list`、`async`、`timezone`）
- 构建：`nonTransitiveRClass=true`、关闭 jetifier、Gradle parallel/caching
- 运行：MIUIX（HyperOS 风格）主题 + 原生控件、MIUIX 配色缓存、主页图表 `RepaintBoundary`
- 发布：正式版/预发布拆分、上传重试 + 上传后校验资源、混淆符号作为 CI artifact 上传

## 7. 当前状态

- main 最新提交：`5a48176`（产物命名 + 构建优化）
- 内部版本：`2.24.1+163`
- 已完成并通过 CI：
  - CI #42：analyze + debug 构建 ✅
  - Pre-release #2（tag `v2.24.1-pre.2`）：发布 ✅，资产 `adguard-home-manager-mod-v2.24.1-pre.2.apk`
- 历史遗留：`v2.24.0` 的资产名仍是旧的 `app-release.apk`；`v2.24.1-pre.1` / 之前的 `v2.24.1Pre` 是失败或旧的记录，可在 Releases 页面手动删除

## 8. 待办 / 待决

- **UI 优化方向待选**：(a) 继续把对话框/底部弹层/列表项/Tab 换成原生 MIUIX；(b) 视觉细节规范（图标、间距、圆角、对比度）；(c) 指定页面重做（首页 / 日志 / 过滤器 / 设置）
- 是否删除 `android/gradle.properties` 里的 `android.nonFinalResIds=false`（删掉即回到 AGP 默认 `true`，增量构建更快；我们代码不依赖 final R）
- 可选：用 pub.dev 重新生成 `pubspec.lock` 以消除 CI 的 97 条依赖重写
- 可选：清理 `%TEMP%\aghm_cleanup_2026092*`（之前挪走的构建缓存与 uiautomator dump）
