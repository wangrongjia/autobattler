# Android APK 导出说明

## 当前试玩包

- 导出预设：`Android`
- 包名：`com.threekingdom.bondchess`
- 版本：`0.1.4`（versionCode 5）
- 最低系统：Android 7.0（API 24）
- 目标系统：Android API 36
- 架构：ARMv7、ARM64
- 输出位置：`outputs/ThreeKingdom-debug-v0.1.5.apk`

当前 APK 使用本机调试密钥签名，适合传到手机直接试玩，不适合提交应用商店。

## 使用 Godot 界面导出试玩 APK

1. 使用 Godot 4.7 打开项目目录。
2. 进入“项目 → 导出”。
3. 在左侧选择已经配置好的 `Android` 预设。
4. 点击“导出项目”。
5. 勾选调试导出，保存到 `outputs/ThreeKingdom-debug-v0.1.5.apk`。

本机已经配置好 JDK 17、Android SDK、Build Tools 36、Godot Android 模板和调试密钥，后续不需要重新安装。

## 使用命令行导出

```powershell
& 'C:\Users\admin\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path 'D:\github\autobattler' --export-debug 'Android' 'D:\github\autobattler\outputs\ThreeKingdom-debug-v0.1.5.apk'
```

手机通过 USB 连接并开启 USB 调试后，可以执行：

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r 'D:\github\autobattler\outputs\ThreeKingdom-debug-v0.1.5.apk'
```

也可以把 APK 发送到手机，在系统设置中允许文件管理器或浏览器“安装未知应用”，再点击 APK 安装。

## 正式发布版本

正式发布前需要创建并永久保存自己的 release keystore，不能使用 `debug.keystore`。在 Android 导出预设的发布签名区域填写 release keystore、别名和密码，然后使用“发布”模式导出。

每次发布升级时：

1. 保持包名 `com.threekingdom.bondchess` 不变。
2. 始终使用同一个 release keystore。
3. 增加 `version/code`。
4. 按需要更新 `version/name`。
5. 应用商店通常使用 AAB；手机直接安装使用 APK。

release keystore 和密码属于私密凭据，不要提交到 Git 仓库。
