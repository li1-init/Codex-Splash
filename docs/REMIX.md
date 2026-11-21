# 二创与重新打包

在 GitHub 上 Fork 这个仓库并克隆自己的副本。在仓库根目录打开 PowerShell 运行下面的命令。

## 直接换成自己的视频

1. 导出 H.264、YUV 4:2:0 格式的 MP4。将它保存为根目录下的 `.Welcome Jay.overlay.mp4`，这是启动器读取的文件。`Welcome Jay.mp4` 可以另存一份供访客预览。
2. 在 `portal.json` 中填入与你的视频相同宽高比的 `width` 和 `height`，把 `center` 设为画布中心，把 `duration` 设为视频时长（秒）。
3. 让 `motion` 的第三列全部为 `0`，这样自制视频会连续播到结尾，再显示 ChatGPT。若视频里有扩张的图形，可将其轮廓和扩张时序写入 `outline` 和 `motion`。

## 修改原来的手写动画

| 要改的内容 | 文件和参数 |
| --- | --- |
| 手写文字、每段书写速度 | `render.py` 里的 `WRITING`。每项是该段完成的时间（秒）和三次贝塞尔路径。 |
| 彩色线条、背景 | `render.py` 的 `INK_X` 和 `INK_COLORS` 对应笔画横坐标与颜色，`CLOUD_COLORS` 控制图标轮廓的渐变。底色在 `portal.json` 的 `background`。 |
| 图标形状、揭幕速度 | `portal.json` 的 `outline` 是以图标中心为原点的闭合轮廓，`motion` 每行依次是秒数、彩线缩放倍数、开口缩放倍数。 |

重画文字时可先用矢量工具描一条连续路径，再把控制点填到 `WRITING`。第一段用 `M x,y` 设起点，后面各段用 `C x1,y1 x2,y2 x,y`，从前一段终点接着画。配套调整 `gap_start, gap_end` 所在行引用的段落索引，用于把词间连接画成细线。字迹终点要能接上 `TAIL`，尾线终点须等于图标起点加上画布中心和横向位移 `SLIDE`。修改图标曲线段数时同步调整 `CLOUD_COLORS` 的色标数量。

安装 Python 3.9 或更新版本，然后重新生成两个 MP4。时序改动需要同时重渲染视频并保留更新后的 `portal.json`，才能让窗口揭幕与视频中的图形对齐。

```powershell
python -m pip install -r requirements.txt
python render.py
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File .\Launch.ps1 -Preview
```

## 生成自己的 Windows 安装包

安装 [Inno Setup 6 或 7](https://jrsoftware.org/inno-setup/downloads)，运行以下命令。可加 `-CompilerPath` 指定 `ISCC.exe` 的完整路径。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Installer.ps1 -Version 1.0.0
```

生成的安装包位于 `dist\Codex-Splash-Setup-1.0.0.exe`。发布自己的版本前，可在 `installer\CodexSplash.iss` 中更新发布者、项目链接和快捷方式名称，并替换 `installer\CodexSplash.ico`。如果希望二创版与原版同时安装，也要更换 `AppId` 和 `DefaultDirName`，避免两个版本共用安装目录和卸载记录。
