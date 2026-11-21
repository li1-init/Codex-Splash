# Codex Splash

为 Windows 版 ChatGPT 制作的「Welcome Jay」开场动画。彩色细线写下连笔字，随后收成 Codex 图标。图标向外扩张，露出实际的 ChatGPT 窗口。

![动画分镜](preview.png)

[观看 MP4 预览](Welcome%20Jay.mp4)

## 安装

1. 确认已安装 Microsoft Store 版 ChatGPT 桌面应用。
2. 克隆仓库，或解压 GitHub 下载的 ZIP。在项目目录打开 PowerShell，运行以下命令。

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Shortcut.ps1
   ```

3. 用桌面上的 **ChatGPT - Welcome Jay** 快捷方式打开应用。ChatGPT 已在运行时，快捷方式直接唤起应用。开始菜单和原有任务栏入口按 Windows 的默认方式启动。

启动快捷方式依赖项目目录内的脚本和视频。移动项目后，重新运行安装命令即可更新快捷方式。删除桌面快捷方式即可移除这一启动入口。

## 预览与重建

用独立测试窗口预览启动效果，无需退出 ChatGPT。

```powershell
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File .\Launch.ps1 -Preview
```

仓库已包含可直接使用的视频。修改动画后，可用 Python 重新生成预览 MP4 和启动器使用的 MP4。

```powershell
python -m pip install -r requirements.txt
python render.py
```

`portal.json` 定义图标轮廓和扩张时序，由视频渲染器和启动器共同使用。
