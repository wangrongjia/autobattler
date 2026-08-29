# TapTap 登录与防沉迷接入

项目使用 TapSDK Android `4.10.7`，通过 Godot Android v2 插件接入：

- `tap-core`
- `tap-login`
- `tap-compliance`

## 开发者中心配置

1. 在 TapTap 开发者中心开启“TapTap 登录”和“合规认证”。
2. 本项目已开通“暂无版号”合规方案。
3. 正式包 `com.threekingdom.bondchess` 已登记 release 证书，MD5 为 `CA50A92308948D167DFE124CFE244F95`。
4. 自用测试包 `com.threekingdom.bondchess.dev` 已登记调试证书，MD5 为 `7D51353397B536D9101EA91B0A4C6637`，不得上传为 TapTap 正式包。
5. TapTap 要求填写签名证书的 32 位 MD5（去掉冒号），不是 SHA-1 或 SHA-256。同一个包名只能登记一套签名，因此正式包与测试包必须保持不同包名。
6. 将开发者中心的 Client ID 和 Client Token 填入本地 `taptap.local.cfg`。该文件已被 Git 忽略，但会随 Android 包导出。

```ini
[taptap]

client_id="开发者中心的 Client ID"
client_token="开发者中心的 Client Token"
enable_log=false
```

正式发布时应关闭 SDK 日志。切勿填写 Server Secret；客户端只需要 Client Token。仓库仅提供空值作为兜底配置，真实值不要提交到 Git。

## 正式包与测试包

- TapTap 正式包使用 `Android` 预设，以 Release 方式导出到 `outputs/ThreeKingdom-TapTap-release.apk`。不要勾选 “Export With Debug”。
- 自用测试包使用 `Android 测试` 预设，包名带 `.dev`。调试选项由 `OS.is_debug_build()` 或 `debug_tools` Feature 控制；正式预设未启用 `debug_tools`，Release 构建不会显示这些选项。

## 游戏放行规则

Android 首次启动会先显示不可绕过的隐私政策弹窗。用户点击“同意并继续”后才会保存版本化的本地授权记录并调用 `TapTapSdk.init`；点击“不同意并退出”不会初始化 TapSDK。隐私政策发生重大变化时，递增 `PRIVACY_CONSENT_VERSION` 以重新征得同意。

隐私授权后会显示登录/认证遮罩。只有合规认证返回代码 `500` 时遮罩才会移除。退出认证、切换账号、时段限制、时长限制、适龄限制、配置或网络错误均不会进入游戏。

登录只申请 `basic_info`，用于获得当前游戏下唯一的 `openId` 并启动合规认证。

原生桥接层的 `initialize` 还会校验 `privacyConsentGranted`，避免未授权时误初始化 SDK。公开隐私政策必须如实披露 TapSDK、Android ID、GAID、设备/系统与网络信息、OpenID 和认证结果；项目对应页面为 `docs/privacy.html`。

## 构建插件

首次构建前，先在 Godot 中执行“项目 > 安装 Android 构建模板”。然后在项目根目录执行：

```powershell
& .\android\build\gradlew.bat -p .\addons\taptap_compliance\android clean assembleDebug assembleRelease
```

把生成的两个 AAR 分别复制为：

- `addons/taptap_compliance/bin/taptap-compliance-debug.aar`
- `addons/taptap_compliance/bin/taptap-compliance-release.aar`

仓库中已包含构建好的 AAR，只有修改原生 Java 接入层后才需要重新构建。
