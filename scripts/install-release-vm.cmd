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
echo   Instalador de VM Debian A11y via GitHub Release
echo ====================================================
echo.
echo Iniciando instalacao...
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
