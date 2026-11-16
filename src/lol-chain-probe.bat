@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem =====================================================================
rem  lol-chain-probe.bat   ver 1.1
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
rem  PORTABILITY (ver 1.1):
rem  The install root is NOT hardcoded. It is resolved from several
rem  independent sources, tried in this order, first hit wins:
rem    1. command line  --root "<path>"      (explicit override)
rem    2. env var       LOL_ROOT=<path>
rem    3. registry      HKCU / HKLM / HKLM WOW6432Node  Tencent\LOL
rem    4. desktop .lnk  reverse lookup of an existing shortcut target
rem    5. drive scan    every fixed drive, 2 directory levels deep
rem  Set LOL_SCAN=off to disable source 5 (fast mode).
rem
rem  USAGE:
rem    lol-chain-probe.bat
rem    lol-chain-probe.bat --root "E:\Games\League of Legends"
rem
rem  EXIT CODES:
rem     0  = NATIVE_OK   TCLS\Client.exe present, native entry usable
rem    10  = SHELL_ONLY  native entry gone, only WeGame / Riot shell left
rem    20  = PARTIAL     install dir found but key executables missing
rem    30  = NOT_FOUND   no installation detected
rem =====================================================================

set "PROBE_VER=1.1"
set "ROOT="
set "SRC="
set "ARG_ROOT="
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

rem ---------------------------------------------------------------------
rem STEP 0 - argument parsing (read only, no side effect)
rem ---------------------------------------------------------------------
:parse
if "%~1"=="" goto :parse_done
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="-h"     goto :usage
if /i "%~1"=="/?"     goto :usage
if /i "%~1"=="--root" (
    set "ARG_ROOT=%~2"
    shift
    shift
    goto :parse
)
set "ARG_RAW=%~1"
if /i "!ARG_RAW:~0,7!"=="--root=" (
    set "ARG_ROOT=!ARG_RAW:~7!"
    shift
    goto :parse
)
shift
goto :parse

:usage
echo.
echo USAGE: lol-chain-probe.bat [--root "<install root>"]
echo.
echo   --root   force the install root, skips auto discovery
echo   LOL_ROOT env var works the same way
echo   LOL_SCAN=off  disables the full drive scan (fast mode)
echo.
endlocal & exit /b 0

:parse_done
if defined ARG_ROOT (
    set "ARG_ROOT=!ARG_ROOT:"=!"
    if "!ARG_ROOT:~-1!"=="\" set "ARG_ROOT=!ARG_ROOT:~0,-1!"
)

echo.
echo ================ LOL LAUNCH CHAIN PROBE v%PROBE_VER% ================
echo.

rem ---------------------------------------------------------------------
rem STEP 1a - explicit override: --root then LOL_ROOT
rem ---------------------------------------------------------------------
if defined ARG_ROOT call :probe "!ARG_ROOT!" "arg:--root"
if not defined ROOT if defined LOL_ROOT call :probe "!LOL_ROOT!" "env:LOL_ROOT"

rem ---------------------------------------------------------------------
rem STEP 1b - registry hints (read only, three hives)
rem ---------------------------------------------------------------------
for %%K in (
    "HKCU\SOFTWARE\Tencent\LOL"
    "HKLM\SOFTWARE\Tencent\LOL"
    "HKLM\SOFTWARE\WOW6432Node\Tencent\LOL"
    "HKCU\SOFTWARE\Tencent\LOL\InstallPath"
    "HKLM\SOFTWARE\WOW6432Node\Tencent\LOL\InstallPath"
) do (
    if not defined ROOT (
        for /f "tokens=2,*" %%a in ('reg query %%K /v InstallPath 2^>nul ^| findstr /i "InstallPath"') do (
            set "REG_PATH=%%b"
            if defined REG_PATH (
                set "REG_PATH=!REG_PATH:"=!"
                if "!REG_PATH:~-1!"=="\" set "REG_PATH=!REG_PATH:~0,-1!"
                call :probe "!REG_PATH!" "registry:%%~K"
            )
        )
    )
)
if defined REG_PATH (echo registry_path=!REG_PATH!) else (echo registry_path=EMPTY)

rem ---------------------------------------------------------------------
rem STEP 1c - reverse lookup from an existing desktop shortcut
rem  A .lnk pointing at ...\TCLS\Client.exe reveals the root even when
rem  the registry entry is missing. Best effort: if PowerShell is not
rem  available the step silently degrades to nothing.
rem ---------------------------------------------------------------------
if not defined ROOT (
    for /f "usebackq delims=" %%L in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); Get-ChildItem -LiteralPath $d -Filter *.lnk -ErrorAction SilentlyContinue ^| ForEach-Object { $s=(New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName); if ($s.TargetPath) { $p=Split-Path -Parent (Split-Path -Parent $s.TargetPath); if ($p) { $p } } } ^| Select-Object -Unique" 2^>nul`) do (
        if not defined ROOT call :probe "%%L" "desktop-lnk"
    )
)

rem ---------------------------------------------------------------------
rem STEP 1d - bounded drive scan (2 levels, common roots first)
rem ---------------------------------------------------------------------
if not defined ROOT if /i not "!LOL_SCAN!"=="off" (
    for %%R in (
        "D:\LOL" "D:\WeGameApps" "D:\Games" "D:\Tencent"
        "C:\Program Files\Tencent" "C:\Program Files (x86)\Tencent"
        "D:\Program Files\Tencent" "E:\LOL" "E:\WeGameApps" "F:\LOL"
    ) do (
        if defined ROOT goto :scan_done
        if exist "%%~R\" (
            call :probe "%%~R" "scan:preset"
            for /d %%D in ("%%~R\*") do if not defined ROOT call :probe "%%~D" "scan:preset"
        )
    )
    for %%V in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if defined ROOT goto :scan_done
        if exist "%%V:\" call :scan_drive "%%V:\"
    )
)
:scan_done

if defined ROOT (echo install_root=!ROOT!) else (echo install_root=NOT_FOUND)
if defined SRC  (echo root_source=!SRC!)  else (echo root_source=NONE)

rem ---------------------------------------------------------------------
rem STEP 2 - probe every link of the chain (read only)
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
rem STEP 3 - classify (no action taken, decision only)
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
rem %1 = candidate directory, %2 = source label.
rem Sets ROOT + SRC on the first strong hit, never overwrites.
if defined ROOT exit /b 0
if "%~1"=="" exit /b 0
if not exist "%~1\" exit /b 0
if exist "%~1\TCLS\Client.exe" (
    set "ROOT=%~1"
    set "SRC=%~2"
    exit /b 0
)
if exist "%~1\Game\League of Legends.exe" (
    set "ROOT=%~1"
    set "SRC=%~2"
    exit /b 0
)
if exist "%~1\WeGameLauncher\launcher.exe" (
    set "ROOT=%~1"
    set "SRC=%~2"
    exit /b 0
)
if exist "%~1\LeagueClient\LeagueClient.exe" (
    set "ROOT=%~1"
    set "SRC=%~2"
    exit /b 0
)
exit /b 0

:scan_drive
rem %1 = drive root with trailing backslash. Bounded to SCAN_MAX hits.
set /a SCAN_N=0
for /d %%A in ("%~1*") do (
    if !SCAN_N! LSS 400 if not defined ROOT (
        set /a SCAN_N+=1
        call :probe "%%~A" "scan:%%~1"
        if not defined ROOT (
            for /d %%B in ("%%~A\*") do (
                if !SCAN_N! LSS 400 if not defined ROOT (
                    set /a SCAN_N+=1
                    call :probe "%%~B" "scan:%%~1"
                )
            )
        )
    )
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
