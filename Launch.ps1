param([switch]$Preview, [switch]$Diagnostics)

$ErrorActionPreference = 'Stop'
$appId = 'OpenAI.Codex_2p2nqsd0c76g0!App'
$video = Join-Path $PSScriptRoot '.Welcome Jay.overlay.mp4'
$portalFile = Join-Path $PSScriptRoot 'portal.json'

function Trace-Launch([string]$Message) {
    if ($Diagnostics) { Write-Host $Message }
}

function Open-ChatGPT {
    Start-Process "$env:WINDIR\explorer.exe" -ArgumentList "shell:AppsFolder\$appId"
}

function Get-ChatGPT {
    Get-Process -Name ChatGPT -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionId -eq $sessionId }
}

function Update-VideoLayout {
    $width = $stage.ActualWidth
    $height = $stage.ActualHeight
    if ($width -le 0 -or $height -le 0) { return }
    $widthScale = $width / $portal.width
    $heightScale = $height / $portal.height
    # Fill ordinary layouts and retain the entire signature on unusually narrow windows.
    $videoScale = [Math]::Min([Math]::Max($widthScale, $heightScale),
                              [Math]::Min($widthScale / .72, $heightScale / .78))
    $player.Width = $portal.width * $videoScale
    $player.Height = $portal.height * $videoScale
    [Windows.Controls.Canvas]::SetLeft($player, ($width - $player.Width) / 2)
    [Windows.Controls.Canvas]::SetTop($player, ($height - $player.Height) / 2)
    $aperturePosition.X = ($width - $player.Width) / 2 + $portal.center[0] * $videoScale
    $aperturePosition.Y = ($height - $player.Height) / 2 + $portal.center[1] * $videoScale
    $windowBorder.Rect = [Windows.Rect]::new(0, 0, $width, $height)
    if ($Diagnostics) { Trace-Launch ("Window fit: {0:N0} x {1:N0}." -f $width, $height) }
}

function Update-Aperture([double]$Time) {
    $opening = 0.0
    for ($i = 1; $i -lt $portal.motion.Count; $i++) {
        $previous = $portal.motion[$i - 1]
        $next = $portal.motion[$i]
        if ($Time -gt $next[0]) {
            $opening = $next[2]
        } else {
            $fraction = [Math]::Max(0, ($Time - $previous[0]) / ($next[0] - $previous[0]))
            $opening = $previous[2] + $fraction * ($next[2] - $previous[2])
            break
        }
    }
    if ($opening -le 0) { return }
    $scale = $opening * $player.Width / $portal.width
    $apertureScale.ScaleX = $scale
    $apertureScale.ScaleY = $scale
    if ($stage.Clip -ne $portalClip) {
        $stage.Clip = $portalClip
        Trace-Launch ('Portal opened at {0:N2}s.' -f $Time)
    }
}

$sessionId = [Diagnostics.Process]::GetCurrentProcess().SessionId
$mutex = New-Object Threading.Mutex($false, 'Local\WelcomeJayChatGPTLauncher')
$ownsMutex = $false
try {
    try { $ownsMutex = $mutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (!$ownsMutex) { return }

    if (!$Preview -and @(Get-ChatGPT).Count -gt 0) {
        Trace-Launch 'Warm activation; animation skipped.'
        Open-ChatGPT
        return
    }
    if (!(Test-Path -LiteralPath $video) -or !(Test-Path -LiteralPath $portalFile)) {
        if (!$Preview) { Open-ChatGPT }
        throw 'The Welcome Jay overlay video or portal geometry is missing.'
    }
    if (!$Preview) { Open-ChatGPT }
    $portal = Get-Content -LiteralPath $portalFile -Raw | ConvertFrom-Json

    Add-Type -AssemblyName PresentationFramework
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class JayWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("dwmapi.dll")]
    public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out Rect value, int size);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out Rect value);
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", EntryPoint="GetWindowLongW")]
    private static extern int GetStyle(IntPtr hwnd, int index);
    [DllImport("user32.dll", EntryPoint="SetWindowLongW")]
    private static extern int SetStyle(IntPtr hwnd, int index, int style);

    public static void ConfigureOverlay(IntPtr hwnd) {
        const int ExtendedStyle = -20, NoActivate = 0x08000000, ToolWindow = 0x80, Transparent = 0x20;
        SetStyle(hwnd, ExtendedStyle, GetStyle(hwnd, ExtendedStyle) | NoActivate | ToolWindow | Transparent);
    }

    public static void Fit(IntPtr overlay, IntPtr target) {
        Rect rect;
        if (DwmGetWindowAttribute(target, 9, out rect, 16) != 0 &&
            !GetWindowRect(target, out rect)) return;
        SetWindowPos(overlay, new IntPtr(-1), rect.Left, rect.Top,
                     rect.Right - rect.Left, rect.Bottom - rect.Top, 0x0010);
    }
}
'@

    [void][JayWindow]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $demo = $null
    if ($Preview) {
        $demo = New-Object Windows.Window -Property @{
            Title = 'Welcome Jay preview'; Width = 960; Height = 620
            WindowStartupLocation = 'CenterScreen'
            Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#dce8ff')
        }
        $demo.Show()
        [void]$demo.Activate()
        $target = (New-Object Windows.Interop.WindowInteropHelper($demo)).Handle
    } else {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $target = [IntPtr]::Zero
        while ($clock.Elapsed.TotalSeconds -lt 20) {
            $foreground = [JayWindow]::GetForegroundWindow()
            $process = Get-ChatGPT | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowHandle -eq $foreground } |
                Select-Object -First 1
            if ($process) {
                $target = $process.MainWindowHandle
                break
            }
            Start-Sleep -Milliseconds 40
        }
        if ($target -eq [IntPtr]::Zero) {
            Trace-Launch 'No foreground ChatGPT window; animation skipped.'
            return
        }
    }

    $overlay = New-Object Windows.Window -Property @{
        WindowStyle = 'None'; ResizeMode = 'NoResize'; ShowInTaskbar = $false
        AllowsTransparency = $true; ShowActivated = $false; Topmost = $true
        Background = [Windows.Media.Brushes]::Transparent
    }
    $player = New-Object Windows.Controls.MediaElement -Property @{
        LoadedBehavior = 'Manual'; UnloadedBehavior = 'Close'; IsMuted = $true
        Stretch = 'Fill'; Source = [Uri]::new($video)
    }
    $stage = New-Object Windows.Controls.Canvas -Property @{
        Background = [Windows.Media.BrushConverter]::new().ConvertFromString($portal.background)
    }
    [void]$stage.Children.Add($player)
    $windowBorder = New-Object Windows.Media.RectangleGeometry -Property @{ RadiusX = 7; RadiusY = 7 }
    $aperture = [Windows.Media.Geometry]::Parse($portal.outline + ' Z').Clone()
    $apertureScale = [Windows.Media.ScaleTransform]::new(0, 0)
    $aperturePosition = [Windows.Media.TranslateTransform]::new()
    $apertureTransform = [Windows.Media.TransformGroup]::new()
    $apertureTransform.Children.Add($apertureScale)
    $apertureTransform.Children.Add($aperturePosition)
    $aperture.Transform = $apertureTransform
    $portalClip = [Windows.Media.CombinedGeometry]::new('Exclude', $windowBorder, $aperture)
    $stage.Clip = $windowBorder
    $stage.Add_SizeChanged({ Update-VideoLayout })
    $overlay.Content = $stage
    $overlayHelper = New-Object Windows.Interop.WindowInteropHelper($overlay)
    $overlayHandle = $overlayHelper.EnsureHandle()
    [JayWindow]::ConfigureOverlay($overlayHandle)
    [JayWindow]::Fit($overlayHandle, $target)

    $lifespan = [Diagnostics.Stopwatch]::StartNew()
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(15)
    $player.Add_MediaOpened({
        Trace-Launch ('Playback opened at {0}x{1}.' -f $player.NaturalVideoWidth, $player.NaturalVideoHeight)
    })
    $player.Add_MediaEnded({
        Trace-Launch 'Playback reached the end.'
        $overlay.Close()
    })
    $player.Add_MediaFailed({
        param($sender, $eventArgs)
        Trace-Launch ('Playback failed: ' + $eventArgs.ErrorException.Message)
        $overlay.Close()
    })
    $timer.Add_Tick({
        $foreground = [JayWindow]::GetForegroundWindow()
        if (![JayWindow]::IsWindow($target) -or [JayWindow]::IsIconic($target) -or
            (!$Preview -and $foreground -ne $target -and $foreground -ne $overlayHandle) -or
            $lifespan.Elapsed.TotalSeconds -gt ($portal.duration + 5)) {
            Trace-Launch 'Overlay dismissed before media end.'
            $overlay.Close()
            return
        }
        [JayWindow]::Fit($overlayHandle, $target)
        $time = $player.Position.TotalSeconds
        Update-Aperture $time
        if ($Preview -and $Diagnostics -and $time -gt 2 -and $demo.Width -eq 960) {
            $demo.Width = 760
            $demo.Height = 660
        }
    })
    $overlay.Add_Closed({
        $timer.Stop()
        $player.Close()
        if ($demo) { $demo.Close() }
        [Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvokeShutdown('Background')
    })
    Trace-Launch 'Showing animation overlay.'
    $overlay.Show()
    [JayWindow]::Fit($overlayHandle, $target)
    $player.Play()
    $timer.Start()
    [Windows.Threading.Dispatcher]::Run()
} finally {
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
