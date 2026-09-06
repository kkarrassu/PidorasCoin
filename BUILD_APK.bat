@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BUILD_APK.ps1"
echo.
if errorlevel 1 (
  echo СБОРКА НЕ УДАЛАСЬ. Скопируй мне текст ошибки из этого окна.
) else (
  echo Готово. Файл PidorasCoin.apk лежит в этой папке.
)
pause
