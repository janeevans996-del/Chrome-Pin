# Chrome Pin local helper - Windows PowerShell
# Keeps per-window topmost state and toggles the foreground Chrome window.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Pin {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  [DllImport("user32.dll", SetLastError=true)] public static extern bool SetWindowPos(
    IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

$script:states = @{}
$TOPMOST = [IntPtr](-1)
$NOTOPMOST = [IntPtr](-2)
$FLAGS = 0x0001 -bor 0x0002 -bor 0x0010 # NOSIZE | NOMOVE | NOACTIVATE

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:8765/")
try { $listener.Start() } catch {
  Write-Host "启动失败。请先运行 install-helper.bat（需要管理员权限），再重新启动。" -ForegroundColor Red
  Read-Host "按回车退出"; exit 1
}
Write-Host "Chrome 置顶辅助程序已运行。关闭此窗口即可停止。" -ForegroundColor Green

while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $res.Headers.Add("Access-Control-Allow-Origin", "*")
    $res.Headers.Add("Access-Control-Allow-Methods", "POST, OPTIONS")
    $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
    if ($req.HttpMethod -eq "OPTIONS") {
      $res.StatusCode = 204; $res.Close(); continue
    }
    if ($req.Url.AbsolutePath -ne "/toggle" -or $req.HttpMethod -ne "POST") {
      $res.StatusCode = 404; $res.Close(); continue
    }
    $reader = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding)
    $null = $reader.ReadToEnd(); $reader.Dispose()

    $hwnd = [Win32Pin]::GetForegroundWindow()
    [uint32]$procId = 0
    [void][Win32Pin]::GetWindowThreadProcessId($hwnd, [ref]$procId)
    $proc = $null
    try { $proc = Get-Process -Id $procId -ErrorAction Stop } catch {}
    if (-not $proc -or $proc.ProcessName -ne "chrome") {
      $res.StatusCode = 409
      $bytes = [Text.Encoding]::UTF8.GetBytes('{"error":"请先点击目标 Chrome 窗口，再点图钉"}')
      $res.OutputStream.Write($bytes,0,$bytes.Length); $res.Close(); continue
    }

    $key = $hwnd.ToInt64().ToString()
    $enabled = -not ($script:states.ContainsKey($key) -and $script:states[$key])
    $after = if ($enabled) { $TOPMOST } else { $NOTOPMOST }
    $ok = [Win32Pin]::SetWindowPos($hwnd, $after, 0,0,0,0, $FLAGS)
    if (-not $ok) { throw "SetWindowPos failed" }
    $script:states[$key] = $enabled
    $json = '{"enabled":' + $enabled.ToString().ToLower() + '}'
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $res.ContentType = "application/json; charset=utf-8"
    $res.OutputStream.Write($bytes,0,$bytes.Length)
    $res.Close()
  } catch {
    try { $ctx.Response.StatusCode = 500; $ctx.Response.Close() } catch {}
  }
}
