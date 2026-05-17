@echo off
setlocal
chcp 65001 > nul
set "A11YCTL_PS1=%~dp0a11yctl.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%A11YCTL_PS1%" %*
