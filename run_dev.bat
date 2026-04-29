@echo off
chcp 65001 >nul
echo ========================================
echo    个人记账APP - Flutter开发环境
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] 检查Flutter环境...
C:\flutter\bin\flutter --version
echo.

echo [2/3] 获取依赖...
C:\flutter\bin\flutter pub get
echo.

echo [3/3] 启动开发服务器...
echo.
echo ====== 启动成功！======
echo.
echo 按 Ctrl+C 停止开发服务器
echo.
C:\flutter\bin\flutter run
