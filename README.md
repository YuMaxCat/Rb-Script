# Rb-Script

由羽Max创建的 Roblox 云端脚本，这些脚本是开源的。

## 脚本列表

| 脚本 | 文件 | 说明 |
| --- | --- | --- |
| Yu Fly | [`scripts/FLY-v3.1.lua`](scripts/FLY-v3.1.lua) | 飞行脚本：悬停 / 摇杆加速移动 / 升降 / 速度档位 |
| Yu Perf | [`scripts/FPS.lua`](scripts/FPS.lua) | 右下角 FPS 显示，轻量独立，不依赖其他 UI 库 |
| Yu HUB | [`scripts/YuHUB.lua`](scripts/YuHUB.lua) | WindUI 多功能面板：飞行 / 移速 / 跳跃 / 传送玩家 / 音乐播放器 |
| Abysall | [`scripts/Abysall.lua`](scripts/Abysall.lua) | Abysall Continued（DOORS）汉化版，多模块，首次运行自动下载到本地缓存 |

## 使用方法

在 Delta 等 Roblox 执行器中执行对应脚本即可：

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YuMaxCat/Rb-Script/main/scripts/YuHUB.lua"))()
```

把 URL 末尾的文件名换成其他脚本名即可运行别的脚本。

- 脚本支持重复执行，会自动清理上一次的界面实例。
- `Yu HUB` 会从 WindUI 官方仓库在线加载 UI 库，需要网络可用。
- `Abysall` 的模块放在 [`scripts/abysall/`](scripts/abysall/)，加载器首次运行会把用到的模块下载到本地 `abysall/` 目录并缓存，之后走本地；raw.githubusercontent 的请求会自动改走 gh-proxy。

## 许可

MIT License，详见 [LICENSE](LICENSE)。
