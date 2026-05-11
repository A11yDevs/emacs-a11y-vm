@echo off
REM ==============================================================================
REM install-release-vm.cmd — Wrapper para executar install-release-vm.ps1
REM
REM Este arquivo .cmd facilita a execução no Windows, contornando problemas
REM de política de execução do PowerShell.
REM
REM Uso:
REM   Clique duas vezes neste arquivo, ou execute pelo cmd:
REM   .\scripts\install-release-vm.cmd
REM ==============================================================================

echo.
echo ====================================================
echo   [DEPRECATED] Instalador legado VirtualBox/VDI
echo ====================================================
echo.
echo Use o fluxo QEMU-only com ea11ctl:
echo   1) instale a CLI: cli\install.ps1
echo   2) execute: ea11ctl vm install
echo   3) execute: ea11ctl vm start
echo.

REM Define o diretório do script
set SCRIPT_DIR=%~dp0

REM Executa o script PowerShell com bypass da política de execução
PowerShell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install-release-vm.ps1" %*

REM Pausa no final para ver mensagens (se executado clicando duas vezes)
if "%1"=="" (
    echo.
    pause
)
