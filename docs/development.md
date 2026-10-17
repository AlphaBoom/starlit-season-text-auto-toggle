# 实现与验证

## 对话行为

游戏原本自动推进。`/Script/imal.CommuScriptMessage` 在文字显示完和语音结束后，
使用偏移 `0x288` 的 float 作为推进等待时间；`0x270` 和 `0x298` 的 byte 分别表示打字、等待状态。
这些字段没有反射属性，因此通过 `RegisterCustomProperty` 注册。

手动模式临时把等待时间设成 `1e9`，保存游戏原值；自动模式恢复原值。
不暂停世界时间、语音或动画。游戏原生确认逻辑会把已等待时间设为当前阈值，因此原确认键仍能继续台词。
这一行为和四个启动签名都只针对已验证的 v1.61。升级游戏后必须重新检查，不能直接移植偏移。

## 输入与线程

通过 PlayerController 的 `IsInputKeyDown` 检测：

- Xbox Y：`Gamepad_FaceButton_Top` 或 DirectInput 插件键 `XIGamePad_Button_Y`。
- 键盘 A：`A`。

同一个 `LoopInGameThreadWithDelay(20, ...)` 检测按下沿、修改等待时间、更新 UI。
每 500 ms 重新查询对话对象，每 200 ms 更新提示栏。离开活动对话后不响应切换。
同时按 A 和 Y 时优先 Y；按住不重复切换。

开发原型使用 `LoopAsync -> ExecuteInGameThread` 和键盘回调，反复切换后曾崩溃。
本地 minidump 配合官方 PDB 确认异常位于 UE4SS 的 `mainpositionTV / lua_rawget`，调用链来自
`process_simple_actions / engine_tick_hook`。这是 Lua 状态损坏的证据，无法仅凭堆栈证明唯一根因。
上游 [#1445](https://github.com/UE4SS-RE/RE-UE4SS/issues/1445) 描述了异步 / 按键线程排队时的相同并发风险。
当前实现取消这两条异步路径，使用一个持续的游戏线程定时器，并关闭重载。

不要为了快捷键重新引入 `RegisterKeyBind -> ExecuteInGameThread` 或 `LoopAsync`。
也不要在运行中的游戏里热更新这个版本的脚本。

## 原生 UI

普通对话使用 `_WidgetMessage._PanelGuide`。创建同类 `WidgetControlGuide`，
复制既有条目的字体、颜色和 padding，加入其 HorizontalBox。
使用 `KeyType = 0` 区分模组条目，关闭输入管理器绑定与点击命中。
行的 CanvasSlot 自动计算宽度并向左展开，保留右侧对齐。

按钮使用原生 TRIANGLE（上方按键）布局，每次刷新调用 `SetKey(5, true)` 重建原生图标缓存，
再通过 `OnChangeView(device, 2, false)` 显示对应设备。
游戏本身选择 `ImageSettingDefault` / `ImageSettingPS4`，因此默认模式不会强制覆盖手柄纹理。
键盘单独从 `ImageSettingDefault.ImalKeySettings` 取 raw EImalKey 38 的 A 纹理；
不能只用 TRIANGLE 映射键盘，因为游戏会将它画成 R。
可选 `GAMEPAD_ICONS = 'playstation' / 'xbox'` 从对应原生资产读取 raw EImalKey 142 的上方按键纹理，
用于 Steam Input 把 Sony 手柄映射成 Xbox 的情况；默认 `auto` 保留游戏选择。
没有复制或重新绘制游戏图标。提示采用 ASCII `AUTO ON / AUTO OFF`，避免原生日文字体的缺字。
图标依据最近用于切换的手柄上方按键 / 键盘 A 显示。

Sony △ 与 Xbox Y 使用相同的 `Gamepad_FaceButton_Top` 输入路径，DirectInput 插件还暴露
`XIGamePad_Button_Y`。没有新增猜测的 Sony 专用键名，也不使用后台按键回调。
DualShock / DualSense 的 USB、蓝牙和 Steam Input 真机组合尚未验证。

## 2026-10-13 复测

- 修复前：Xbox Y 能切换，键盘 A 有效，但重复切换触发 UE4SS Lua 崩溃，键盘图标错误为 R。
- 修复后：从 Steam 正常启动；加载器输出单一游戏线程定时器就绪。
- 实际游戏日志记录 30 次键盘 A / Xbox Y 切换，期间没有模组错误，游戏继续运行。
- 玩家按要求复测连续切换、A 图标、手动确认后下一句等待，反馈“目前看起来没问题”。
- 观察普通对话的原生提示栏，Y 与 AUTO OFF 和其他游戏控制提示排列一致。
- 随后多个对话控件 / 场景继续生成原生提示条，游戏未再次退出。
- 安装、停用脚本通过 PowerShell 语法检查；安装兼容性检查在真实游戏目录通过。
- 在独立临时目录实跑首次安装、重复更新、停用，验证固定 ZIP 校验、源码复制、其他模组条目和用户自定义配置保留。

## Sony 图标补充验证（2026-10-13）

- 取消默认模式强制读取 Xbox 142 纹理的做法；游戏原生控件负责选择 Xbox / PS4 图标。
- 从已加载游戏代码确认原生按钮选择 `ImageSettingPS4` 的分支，不增加后台输入回调。
- 临时验证代码在同一个游戏线程定时器中依次切换 `playstation`、`xbox`、`auto` 显示模式，然后恢复 `auto`。
- 实际游戏读取 PS4 纹理 `WT_ps4_button003`，截图确认绿色 △；玩家也反馈“有看到三角”。
- 同次运行记录到手柄上方按键成功切换 MANUAL / AUTO。
- 临时图标轮换代码未进入仓库，已用最终源码替换安装文件。
- Sony 控制器硬件、USB / 蓝牙及其 Steam Input 映射组合尚未实测；截图仅证明图标渲染。

上述是一次有限的实际回归测试，不代表覆盖所有对话场景、其他模组组合或游戏版本。
崩溃转储、个人日志、游戏 EXE、存档和资源均不上传到仓库。

## 安装与维护

运行时固定为 UE4SS `3.0.1-1170-g9e7fed53`，版本和校验和记录在 `runtime.json`。
安装脚本核对游戏 EXE、已有加载器和下载 ZIP 的 SHA-256。遇到不支持的游戏版本或不同加载器会停止。
如提示加载器冲突，先确认其他模组使用的 UE4SS 版本，不要直接覆盖其 DLL。
脚本不会改写游戏 EXE、PAK 或存档，并保留 `mods.txt` 中的其他模组条目。

首次覆盖的模组、签名和配置文件备份在游戏目录下的
`StarlitSeason\Binaries\Win64\.TextAutoToggleBackup`。
安装会关闭加载器的自动重载、热重载和调试窗口，设置游戏线程执行及关闭 UObject 数组缓存。
这些是共用加载器设置；原配置可在备份中查看。

如果固定版本无法下载，可将保存的同版本 ZIP 放到仓库的
`.cache/UE4SS_3.0.1-1170-g9e7fed53.zip` 后重新运行安装。
上游 `experimental-latest` 已移除该文件，固定版本 ZIP 镜像在 [starlit-season-mods](https://github.com/AlphaBoom/starlit-season-mods/releases/tag/deps-ue4ss-3.0.1-1170)。不要用其他版本 ZIP 替代，脚本会拒绝校验和不符的文件。

如果 Sony 手柄经过 Steam Input 后显示 Xbox 图标，可在
`mod/ue4ss/Mods/TextAutoToggle/Scripts/main.lua` 顶部将 `GAMEPAD_ICONS='auto'` 改为
`GAMEPAD_ICONS='playstation'`，关闭游戏后重新安装。`xbox` 可强制使用 Xbox 图标。
这只改变图标，不改变按键映射。

停用脚本保留共用加载器及模组源码。若要彻底删除本模组，先停用，再删除
`StarlitSeason\Binaries\Win64\ue4ss\Mods\TextAutoToggle`。
`UE4SS_Signatures` 的四个兼容签名可能被其他星耀季节模组使用，删除前检查其他模组需求。
如果加载器仅为本模组安装且没有其他模组依赖它，可关闭游戏后删除新增的
`StarlitSeason\Binaries\Win64\dwmapi.dll` 和 `ue4ss` 目录。
保留游戏原有的 EXE 和 `XAudio2_9redist.dll`。

开发时修改仓库内源码，关闭游戏后重新执行安装脚本，再从 Steam 启动。
日志位于游戏目录的 `StarlitSeason\Binaries\Win64\ue4ss\UE4SS.log`，查找 `[TextAutoToggle]`。
