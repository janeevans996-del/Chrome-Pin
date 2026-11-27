@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo 需要管理员权限来注册本机回环地址。
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
netsh http add urlacl url=http://127.0.0.1:8765/ user=%USERDOMAIN%\%USERNAME% >nul 2>&1
echo 安装完成。现在双击 start-helper.bat 启动辅助程序。
pause
