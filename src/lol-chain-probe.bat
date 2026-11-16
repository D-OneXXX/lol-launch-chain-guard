@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem =====================================================================
rem  lol-chain-probe.bat   ver 1.0
rem  PURPOSE : Detect the current League of Legends (CN) launch chain.
rem
rem  SAFETY GUARANTEE - this script is READ-ONLY:
rem    - no file created, deleted, renamed or modified
rem    - no registry write (only "reg query")
rem    - no process kill / service change / ACL change / elevation
rem    - no network access
rem    - only "if exist", "attrib", "reg query" are used
rem  It is safe to run at any time, including while the game is running.
rem
rem  Do NOT change the console code page here: registry values may contain
rem  non-ASCII characters (install path), and switching code page would
rem  corrupt the captured path string.
rem
rem  EXIT CODES:
rem     0  = NATIVE_OK   TCLS\Client.exe present, native entry usable
rem    10  = SHELL_ONLY  native entry gone, only WeGame / Riot shell left
rem    20  = PARTIAL     install dir found but key executables missing
rem    30  = NOT_FOUND   no installation detected
rem =====================================================================

set "PROBE_VER=1.0"
set "ROOT="
set "REG_PATH="
set "ATTR_TMP="
set "IS_RO=NO"
set "CLIENT=NO"
set "GAME=NO"
set "LEAGUECLIENT=NO"
set "RIOT_SVC=NO"
set "WG_LAUNCHER=NO"
set "WG_TMP=NO"
set "WG_TMP_RO=NO"
set "WG_INI=NO"
set "WG_INST=NO"

echo.
echo ================ LOL LAUNCH CHAIN PROBE v%PROBE_VER% ================
echo.

rem ---------------------------------------------------------------------
rem STEP 1 - registry hint (read only)
rem ---------------------------------------------------------------------
for /f "tokens=2,*" %%a in ('reg query "HKCU\SOFTWARE\Tencent\LOL" /v InstallPath 2^>nul ^| findstr /i "InstallPath"') do set "REG_PATH=%%b"
if defined REG_PATH (
    set "REG_PATH=!REG_PATH:"=!"
    if "!REG_PATH:~-1!"=="\" set "REG_PATH=!REG_PATH:~0,-1!"
)
if defined REG_PATH (echo registry_path=!REG_PATH!) else (echo registry_path=EMPTY)

if defined REG_PATH call :probe "!REG_PATH!"

rem ---------------------------------------------------------------------
rem STEP 2 - fallback scan (2 levels, common roots only)
rem ---------------------------------------------------------------------
if not defined ROOT (
    for %%R in (
        "D:\LOL" "D:\WeGameApps" "D:\Games" "D:\Tencent"
        "C:\Program Files\Tencent" "C:\Program Files (x86)\Tencent"
        "D:\Program Files\Tencent" "E:\LOL" "E:\WeGameApps" "F:\LOL"
    ) do (
        if exist "%%~R\" (
            call :probe "%%~R"
            for /d %%D in ("%%~R\*") do call :probe "%%~D"
        )
    )
)

if defined ROOT (echo install_root=!ROOT!) else (echo install_root=NOT_FOUND)

rem ---------------------------------------------------------------------
rem STEP 3 - probe every link of the chain (read only)
rem ---------------------------------------------------------------------
if defined ROOT (
    if exist "!ROOT!\TCLS\Client.exe"                set "CLIENT=YES"
    if exist "!ROOT!\Game\League of Legends.exe"     set "GAME=YES"
    if exist "!ROOT!\LeagueClient\LeagueClient.exe"  set "LEAGUECLIENT=YES"
    if exist "!ROOT!\RiotClientServices.exe"         set "RIOT_SVC=YES"
    if exist "!ROOT!\WeGameLauncher\launcher.exe"    set "WG_LAUNCHER=YES"
    if exist "!ROOT!\TCLS\wegame_launch.tmp"         set "WG_TMP=YES"
    if exist "!ROOT!\TCLS\wegame_launch.ini"         set "WG_INI=YES"
)

if "!WG_TMP!"=="YES" (
    call :isro "!ROOT!\TCLS\wegame_launch.tmp"
    set "WG_TMP_RO=!IS_RO!"
)

rem WeGame itself: registry + common install paths
reg query "HKCU\SOFTWARE\Tencent\WeGame" >nul 2>nul && set "WG_INST=YES"
if exist "D:\WeGameApps\WeGame\wegame.exe"                 set "WG_INST=YES"
if exist "C:\Program Files\Tencent\WeGame\wegame.exe"      set "WG_INST=YES"
if exist "C:\Program Files (x86)\Tencent\WeGame\wegame.exe" set "WG_INST=YES"

echo.
echo ---- chain components ----
echo tcls_client_exe = !CLIENT!
echo game_exe        = !GAME!
echo league_client   = !LEAGUECLIENT!
echo riot_services   = !RIOT_SVC!
echo wegame_launcher = !WG_LAUNCHER!
echo wegame_tmp      = !WG_TMP!
echo wegame_tmp_ro   = !WG_TMP_RO!
echo wegame_ini      = !WG_INI!
echo wegame_installed= !WG_INST!

rem ---------------------------------------------------------------------
rem STEP 4 - classify (no action taken, decision only)
rem ---------------------------------------------------------------------
if not defined ROOT                goto :chain_notfound
if "!CLIENT!"=="YES"               goto :chain_native
if "!GAME!"=="YES"                 goto :chain_shell
if "!WG_LAUNCHER!"=="YES"          goto :chain_shell
if "!LEAGUECLIENT!"=="YES"         goto :chain_shell
goto :chain_partial

:chain_native
set "CHAIN=NATIVE_OK"
set "RC=0"
set "ADVICE=native entry available, TCLS\Client.exe is the launch target"
goto :report

:chain_shell
set "CHAIN=SHELL_ONLY"
set "RC=10"
set "ADVICE=native login entry gone, only vendor shell remains, no bypass path"
goto :report

:chain_partial
set "CHAIN=PARTIAL"
set "RC=20"
set "ADVICE=install dir found but key executables missing, treat as damaged"
goto :report

:chain_notfound
set "CHAIN=NOT_FOUND"
set "RC=30"
set "ADVICE=no installation detected, nothing to switch"
goto :report

:report
echo.
echo ---- verdict ----
echo chain    = !CHAIN!
echo advice   = !ADVICE!
echo exit_code= !RC!
echo ==================================================================
endlocal & exit /b %RC%

rem =====================================================================
rem SUBROUTINES
rem =====================================================================

:probe
rem %1 = candidate directory. Sets ROOT on first hit, never overwrites.
if defined ROOT exit /b 0
if not exist "%~1\" exit /b 0
if exist "%~1\TCLS\Client.exe" (
    set "ROOT=%~1"
    exit /b 0
)
if exist "%~1\Game\League of Legends.exe" (
    set "ROOT=%~1"
    exit /b 0
)
if exist "%~1\WeGameLauncher\launcher.exe" (
    set "ROOT=%~1"
    exit /b 0
)
if exist "%~1\LeagueClient\LeagueClient.exe" (
    set "ROOT=%~1"
    exit /b 0
)
exit /b 0

:isro
rem %1 = file path. Sets IS_RO to YES / NO. Read only.
set "IS_RO=NO"
set "ATTR_TMP="
for /f "delims=" %%A in ('attrib "%~1" 2^>nul') do set "ATTR_TMP=%%A"
if not defined ATTR_TMP exit /b 0
if "!ATTR_TMP:~0,1!"=="R" set "IS_RO=YES"
exit /b 0
