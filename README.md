# Starlit Season Text Auto Toggle

《偶像大师 星耀季节》Steam PC 版的对话自动 / 手动切换模组。

- 对话中按 **Xbox 手柄 Y** 或 **键盘 A** 切换。
- **AUTO ON**：使用游戏原本的自动推进节奏。
- **AUTO OFF**：台词显示完后等待；使用原本的确认键继续下一句。
- 普通对话的原生按键提示栏显示状态，并使用游戏内的 Y / A 图标、字体和间距。
- 长按按键只切换一次。模式在当前游戏会话内保留，重新启动默认开启自动。

## 兼容范围

已在 **Steam v1.61 / Unreal Engine 4.24 / Windows x64** 的普通对话页面验证。
安装脚本会核对游戏 EXE 的 SHA-256；其他版本需要重新确认字段偏移和签名。
模组不会改写游戏 EXE、PAK 或存档。

依赖 [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS)，固定使用
`3.0.1-1170-g9e7fed53`。本仓库只包含模组源码和兼容签名；加载器从官方发布下载并校验哈希。
普通对话提示栏已经验证，小说 / 电影式对话的提示栏尚未验证。

## 安装或更新

1. 关闭游戏，下载或克隆本仓库。
2. 在 PowerShell 中执行，路径替换为自己的 Steam 游戏目录：

   ```powershell
   .\scripts\Install.ps1 -GameDirectory 'D:\Program Files (x86)\Steam\steamapps\common\StarlitSeason'
   ```

3. 从 Steam 正常启动游戏，进入对话后使用 Y / A。

只检查兼容性，不修改文件：

```powershell
.\scripts\Install.ps1 -GameDirectory 'D:\Program Files (x86)\Steam\steamapps\common\StarlitSeason' -CheckOnly
```

安装脚本保留其他模组在 `mods.txt` 中的条目；遇到不同版本的 UE4SS 或不同的
`dwmapi.dll` 会停止，避免覆盖已有加载器。安装时覆盖的模组、签名和配置文件，首次原件备份到
`StarlitSeason\Binaries\Win64\.TextAutoToggleBackup`。

为了避开当前 UE4SS 的 Lua 并发和重载问题，安装脚本会关闭整个加载器的自动重载、热重载和调试窗口，
设置游戏线程定时器及关闭 UObject 数组缓存。原配置保留在备份目录。修改代码后应完整重启游戏。

官方 `experimental-latest` 发布的旧文件可能会被替换或移除。如果固定版本无法下载，请使用保存的同版本 ZIP
放到仓库的 `.cache/UE4SS_3.0.1-1170-g9e7fed53.zip`。不要用新版本 ZIP 冒充旧版本；脚本会拒绝哈希不符的文件。

## 停用与卸载

关闭游戏后运行：

```powershell
.\scripts\Disable.ps1 -GameDirectory 'D:\Program Files (x86)\Steam\steamapps\common\StarlitSeason'
```

它把 `TextAutoToggle` 设为停用，并保留共用的 UE4SS 加载器与其他模组。
下次启动会恢复游戏原本的对话行为。

如需删除本模组文件，停用后删除 `ue4ss\Mods\TextAutoToggle`。
四个 `ue4ss\UE4SS_Signatures\*.lua` 兼容签名也可能被其他星耀季节模组使用；删除前先检查备份及其他模组需求。
如果 UE4SS 仅为本模组安装，且没有其他模组依赖它，可关闭游戏后删除新增的 `dwmapi.dll` 和 `ue4ss` 目录。
这些路径均相对于 `StarlitSeason\Binaries\Win64`。保留游戏原有的 EXE 和 `XAudio2_9redist.dll`。

## 后续开发

- 主要实现：`mod/ue4ss/Mods/TextAutoToggle/Scripts/main.lua`
- 游戏兼容签名：`mod/ue4ss/UE4SS_Signatures/`
- 运行时版本与校验和：`runtime.json`
- 实现说明及复测记录：[docs/development.md](docs/development.md)

编辑仓库内源码，关闭游戏后重新执行安装脚本，再从 Steam 启动。
日志位于 `StarlitSeason\Binaries\Win64\ue4ss\UE4SS.log`，查找 `[TextAutoToggle]`。

## 致谢与许可

本模组源码采用 MIT 许可。UE4SS 由其上游维护，遵循上游许可；下载的加载器包含其 LICENSE。
图标、字体和控件在运行时直接使用游戏资源，本仓库不分发这些资源。
