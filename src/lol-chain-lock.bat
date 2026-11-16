@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem =====================================================================
rem  lol-chain-lock.bat   ver 2.0
rem  Part of LOL Launch Chain Guard. See README before use.
rem
rem  WHAT IT DOES (write layer, opt-in only):
rem    Locks the WeGame hijack file so the vendor shell cannot take the
rem    launch chain back after a game update.
rem
rem  DEFAULT BEHAVIOUR IS DRY-RUN. Nothing is written unless --apply.
rem
rem  USAGE:
rem    lol-chain-lock.bat                 dry-run, print plan only
rem    lol-chain-lock.bat --apply         +R  and deny-write (keeps file)
rem    lol-chain-lock.bat --apply --purge delete then place 0-byte stub
rem    lol-chain-lock.bat --restore       remove lock, restore backup
rem    lol-chain-lock.bat --apply --yes   skip interactive prompt
rem                                      (CI / automation only, use with care)
rem
rem  SAFETY DESIGN (open-source baseline, do not weaken):
rem    1. HARD PATH WHITELIST. Target must be exactly
rem       <root>\TCLS\wegame_launch.tmp and <root> must contain
rem       Game\League of Legends.exe AND TCLS\Client.exe.
rem       Any mismatch -> REFUSE, exit 40. No wildcards, no recursion,
rem       no user-supplied path argument accepted.
rem    2. Backup before the first modification:
rem       %LOCALAPPDATA%\LOLChainGuard\backup\wegame_launch.tmp.bak
rem       Existing backup is never overwritten.
rem    3. Idempotent. Re-running does not accumulate backups or loops.
rem    4. Reversible. --restore removes deny ACE, clears +R, restores
rem       the original file byte-for-byte.
rem    5. Never touches: game exes, launchers, anticheat, registry,
rem       services, other processes, network.
rem    6. Volume aware. ACL deny exists only on NTFS. On exFAT / FAT32 the
rem       script reports acl_deny=SKIPPED_UNSUPPORTED instead of claiming
rem       success - verified in the field: icacls returns 0 and changes
rem       nothing there. The read-only bit alone still denies write handles,
rem       so the lock holds, but it is a single layer.
rem
rem  EXIT CODES:
rem    0  = OK (action applied / restored)
rem    40 = REFUSED_WHITELIST
rem    41 = NOT_INSTALLED
rem    42 = DRYRUN_ONLY
rem    43 = PARTIAL (action failed on at least one step)
rem =====================================================================

set "VER=2.0"
set "MODE=dryrun"
set "PURGE=NO"
set "ROOT="
set "REG_PATH="
set "TARGET="
set "BACKUP_DIR=%LOCALAPPDATA%\LOLChainGuard\backup"
set "BACKUP_FILE=%BACKUP_DIR%\wegame_launch.tmp.bak"
set "STEP_FAIL=NO"

for %%A in (%*) do (
    if /i "%%~A"=="--apply"   set "MODE=apply"
    if /i "%%~A"=="--restore" set "MODE=restore"
    if /i "%%~A"=="--purge"   set "PURGE=YES"
    if /i "%%~A"=="--yes"     set "PRESET_YES=YES"
    if /i "%%~A"=="--help"    goto :usage
    if /i "%%~A"=="-h"        goto :usage
)

echo.
echo ========== LOL CHAIN LOCK v%VER%  mode=%MODE% purge=%PURGE% ==========
echo.

rem ---------------------------------------------------------------------
rem Locate install root: registry first, then limited fallback scan
rem ---------------------------------------------------------------------
for /f "tokens=2,*" %%a in ('reg query "HKCU\SOFTWARE\Tencent\LOL" /v InstallPath 2^>nul ^| findstr /i "InstallPath"') do set "REG_PATH=%%b"
if defined REG_PATH (
    set "REG_PATH=!REG_PATH:"=!"
    if "!REG_PATH:~-1!"=="\" set "REG_PATH=!REG_PATH:~0,-1!"
    call :probe "!REG_PATH!"
)
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

if not defined ROOT (
    echo result=NOT_INSTALLED
    echo note=no League of Legends installation detected
    goto :end_41
)
echo install_root=!ROOT!
set "TARGET=!ROOT!\TCLS\wegame_launch.tmp"

rem ---------------------------------------------------------------------
rem HARD WHITELIST - do not weaken, this is the fork-protection layer
rem ---------------------------------------------------------------------
call :validate_whitelist
if "!WL_OK!"=="NO" (
    echo result=REFUSED_WHITELIST
    echo reason=!WL_REASON!
    echo note=no file was read or written
    goto :end_40
)
echo target=!TARGET!
echo whitelist=PASS

if /i "!MODE!"=="restore" goto :do_restore

rem ---------------------------------------------------------------------
rem PLAN
rem ---------------------------------------------------------------------
echo.
echo ---- plan ----
if "!PURGE!"=="YES" (
    echo step1 = back up wegame_launch.tmp to !BACKUP_FILE!
    echo step2 = delete wegame_launch.tmp
    echo step3 = create 0-byte stub at same path
    echo step4 = set read-only attribute
    echo step5 = deny current-user write ACE via icacls
) else (
    echo step1 = back up wegame_launch.tmp to !BACKUP_FILE!
    echo step2 = set read-only attribute
    echo step3 = deny current-user write ACE via icacls
)
echo step4 = verify and report
echo note  = reverse with --restore, no data loss expected

if /i "!MODE!"=="dryrun" (
    echo.
    echo result=DRYRUN_ONLY
    echo note=nothing was written. re-run with --apply to execute
    goto :end_42
)

rem ---------------------------------------------------------------------
rem CONFIRM - mandatory single confirmation before any write
rem ---------------------------------------------------------------------
echo.
echo ================== CONFIRMATION REQUIRED ==================
echo Target : !TARGET!
echo Effect : WeGame shell will no longer be able to rewrite the launch
echo          chain file. Big game updates may need --restore first.
echo Rollback: --restore restores the original file from backup.
echo ===========================================================
set "ANS="
if "!PRESET_YES!"=="YES" (
    echo confirmation=BYPASSED_BY_--yes
    set "ANS=YES"
) else (
    set /p "ANS=Type YES to proceed, anything else to abort: "
)
if /i not "!ANS!"=="YES" (
    echo result=ABORTED_BY_USER
    echo note=nothing was changed
    goto :end_0
)

rem ---------------------------------------------------------------------
rem APPLY
rem ---------------------------------------------------------------------
echo.
echo ---- applying ----
if not exist "!BACKUP_DIR!\" mkdir "!BACKUP_DIR!" >nul 2>nul
if exist "!TARGET!" (
    if not exist "!BACKUP_FILE!" (
        copy /y "!TARGET!" "!BACKUP_FILE!" >nul 2>nul && echo backup=CREATED || (set "STEP_FAIL=YES" & echo backup=FAILED)
    ) else (
        echo backup=EXISTS ^(kept, not overwritten^)
    )
) else (
    echo backup=SKIPPED ^(target absent^)
)

if "!PURGE!"=="YES" (
    if exist "!TARGET!" (
        del /f /q "!TARGET!" >nul 2>nul
        if exist "!TARGET!" (set "STEP_FAIL=YES" & echo purge=FAILED) else (echo purge=DONE)
    )
    if not exist "!TARGET!" (
        type nul > "!TARGET!" 2>nul
        if exist "!TARGET!" (echo stub=CREATED) else (set "STEP_FAIL=YES" & echo stub=FAILED)
    )
)

if exist "!TARGET!" (
    attrib +R "!TARGET!" >nul 2>nul
    call :isro "!TARGET!"
    if "!IS_RO!"=="YES" (echo readonly=SET) else (set "STEP_FAIL=YES" & echo readonly=FAILED)
) else (
    set "STEP_FAIL=YES"
    echo readonly=SKIPPED ^(target absent^)
)

rem ACL deny is meaningful only on NTFS. exFAT and FAT32 accept the icacls
rem call, return success, and change nothing - so the outcome is verified by
rem re-reading the ACL instead of trusted from the exit code.
set "FS=UNKNOWN"
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "try{(Get-Volume -DriveLetter '!TARGET:~0,1!').FileSystem}catch{''}" 2^>nul`) do set "FS=%%V"
echo filesystem=!FS!
if /i "!FS!"=="NTFS" (
    icacls "!TARGET!" /deny "%USERNAME%:(W)" >nul 2>nul
    set "ACL_STATE=FAILED"
    for /f "delims=" %%L in ('icacls "!TARGET!" 2^>nul ^| findstr /i "DENY"') do set "ACL_STATE=APPLIED"
    echo acl_deny=!ACL_STATE!
) else (
    echo acl_deny=SKIPPED_UNSUPPORTED
    echo acl_hint=volume !FS! has no ACL support, read-only flag is the only lock
)

echo.
if "!STEP_FAIL!"=="YES" (
    echo result=PARTIAL
    echo note=at least one step failed, run --restore then retry
    goto :end_43
)
echo result=OK
echo note=launch chain locked. use --restore before big updates.
goto :end_0

rem =====================================================================
:do_restore
echo.
echo ---- restoring ----
icacls "!TARGET!" /remove:d "%USERNAME%" >nul 2>nul && echo acl_deny=REMOVED || echo acl_deny=NOT_PRESENT
if exist "!TARGET!" (
    attrib -R "!TARGET!" >nul 2>nul
    echo readonly=CLEARED
)
if exist "!BACKUP_FILE!" (
    copy /y "!BACKUP_FILE!" "!TARGET!" >nul 2>nul && echo restore=FROM_BACKUP || (set "STEP_FAIL=YES" & echo restore=FAILED)
) else (
    echo restore=NO_BACKUP ^(nothing to restore, lock cleared only^)
)
echo.
if "!STEP_FAIL!"=="YES" (
    echo result=PARTIAL
    goto :end_43
)
echo result=OK
echo note=original state restored
goto :end_0

rem =====================================================================
rem SUBROUTINES
rem =====================================================================

:validate_whitelist
set "WL_OK=NO"
set "WL_REASON="
if not defined ROOT set "WL_REASON=root not resolved" & exit /b 0
if not exist "!ROOT!\Game\League of Legends.exe" set "WL_REASON=game executable missing, not a valid LoL root" & exit /b 0
if not exist "!ROOT!\TCLS\Client.exe" set "WL_REASON=native launcher missing, not a valid LoL root" & exit /b 0
if not exist "!ROOT!\TCLS\" set "WL_REASON=TCLS directory missing" & exit /b 0
set "EXPECT=!ROOT!\TCLS\wegame_launch.tmp"
if /i not "!TARGET!"=="!EXPECT!" set "WL_REASON=target path mismatch, refusing" & exit /b 0
echo !TARGET! | findstr /i /c:".." >nul && (set "WL_REASON=path traversal detected, refusing" & exit /b 0)
set "WL_OK=YES"
exit /b 0

:probe
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
exit /b 0

:isro
rem %1 = file path. Reliable read-only test: "dir /a:r" lists the file only
rem when the read-only bit is set, unlike parsing attrib output columns.
set "IS_RO=NO"
dir /a:r "%~1" >nul 2>nul
if not errorlevel 1 set "IS_RO=YES"
exit /b 0

:usage
echo.
echo lol-chain-lock.bat [-^|--] usage
echo   (no arg)          dry-run
echo   --apply           lock the hijack file
echo   --apply --purge   delete then place 0-byte stub, then lock
echo   --restore         undo everything
echo.
echo read-only guarantee: without --apply nothing is written.
goto :end_0

rem =====================================================================
:end_0
endlocal & exit /b 0
:end_40
endlocal & exit /b 40
:end_41
endlocal & exit /b 41
:end_42
endlocal & exit /b 42
:end_43
endlocal & exit /b 43
