@echo off
setlocal
set "EA11CTL_PS1=%~dp0ea11ctl.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%EA11CTL_PS1%" %*
