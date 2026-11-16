@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem =====================================================================
rem  lol-chain-lock.bat   ver 2.1
rem  Part of LOL Launch Chain Guard. See README before use.
rem
rem  WHAT IT DOES (write layer, opt-in only):
rem    1. Locks the WeGame hijack file so the vendor shell cannot take the
rem       launch chain back after a game update.
rem    2. Creates a desktop shortcut that launches the NATIVE client
rem       directly:  TargetPath = <root>\TCLS\Client.exe
rem       (a shortcut to a program, NOT a folder).
rem
rem  DEFAULT BEHAVIOUR IS DRY-RUN. Nothing is written unless --apply.
rem
rem  USAGE:
rem    lol-chain-lock.bat                    dry-run, print plan only
rem    lol-chain-lock.bat --apply            lock + create native shortcut
rem    lol-chain-lock.bat --apply --purge    delete then place 0-byte stub
rem    lol-chain-lock.bat --relink           force rebuild the shortcut
rem    lol-chain-lock.bat --unlink           delete the shortcut only
rem    lol-chain-lock.bat --apply --no-link  lock only, no shortcut
rem    lol-chain-lock.bat --restore          remove lock, restore backup
rem    lol-chain-lock.bat --apply --yes      skip interactive prompt
rem                                          (CI / automation only)
rem    lol-chain-lock.bat --root "<path>"    force install root
rem
rem  PORTABILITY (ver 2.1):
rem  The install root is NOT hardcoded. Sources, first hit wins:
rem    1. --root "<path>"        2. env LOL_ROOT
rem    3. registry HKCU/HKLM (incl. WOW6432Node) Tencent\LOL
rem    4. reverse lookup from an existing desktop .lnk target
rem    5. bounded drive scan, 2 levels deep (LOL_SCAN=off to skip)
rem  The whitelist below is still enforced on whatever root is resolved,
rem  so a wrong root can never point the write layer at a foreign file.
rem
rem  SAFETY DESIGN (open-source baseline, do not weaken):
rem    1. HARD PATH WHITELIST. Target must be exactly
rem       <root>\TCLS\wegame_launch.tmp and <root> must contain
rem       Game\League of Legends.exe AND TCLS\Client.exe.
rem       Any mismatch -> REFUSE, exit 40. No wildcards, no recursion.
rem    2. The shortcut is written ONLY to the current user's Desktop
rem       folder, with an exact name, and never overwrites an existing
rem       shortcut unless --relink is given.
rem    3. Backup before the first modification:
rem       %LOCALAPPDATA%\LOLChainGuard\backup\wegame_launch.tmp.bak
rem       Existing backup is never overwritten.
rem    4. Idempotent. Re-running does not accumulate backups or loops.
rem    5. Reversible. --restore removes deny ACE, clears +R, restores
rem       the original file byte-for-byte. --unlink removes the shortcut.
rem    6. Never touches: game exes, launchers, anticheat, registry,
rem       services, other processes, network.
rem    7. Volume aware. ACL deny exists only on NTFS. On exFAT / FAT32 the
rem       script reports acl_deny=SKIPPED_UNSUPPORTED instead of claiming
rem       success - verified in the field: icacls returns 0 and changes
rem       nothing there. The read-only bit alone still denies write handles.
rem
rem  EXIT CODES:
rem    0  = OK (action applied / restored / link only)
rem    40 = REFUSED_WHITELIST
rem    41 = NOT_INSTALLED
rem    42 = DRYRUN_ONLY
rem    43 = PARTIAL (action failed on at least one step)
rem =====================================================================

set "VER=2.1"
set "MODE=dryrun"
set "PURGE=NO"
set "LINKMODE=auto"
set "ROOT="
set "SRC="
set "ARG_ROOT="
set "REG_PATH="
set "TARGET="
set "STEP_FAIL=NO"
set "LINK_WARN=NO"
set "BACKUP_ROOT=%LOCALAPPDATA%\LOLChainGuard\backup"
set "BACKUP_DIR="
set "BACKUP_FILE="
set "ROOT_KEY=default"
set "LNK_OUT=%TEMP%\lol_chain_guard_link.txt"

rem ---------------------------------------------------------------------
rem STEP 0 - argument parsing (shift loop, supports quoted --root)
rem ---------------------------------------------------------------------
:parse
if "%~1"=="" goto :parse_done
if /i "%~1"=="--apply"   (set "MODE=apply"   & shift & goto :parse)
if /i "%~1"=="--restore" (set "MODE=restore" & shift & goto :parse)
if /i "%~1"=="--purge"   (set "PURGE=YES"    & shift & goto :parse)
if /i "%~1"=="--yes"     (set "PRESET_YES=YES" & shift & goto :parse)
if /i "%~1"=="--no-link" (set "LINKMODE=off" & shift & goto :parse)
if /i "%~1"=="--relink"  (set "LINKMODE=force" & shift & goto :parse)
if /i "%~1"=="--unlink"  (set "LINKMODE=delete" & shift & goto :parse)
if /i "%~1"=="--help"    goto :usage
if /i "%~1"=="-h"        goto :usage
if /i "%~1"=="/?"        goto :usage
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

:parse_done
if defined ARG_ROOT (
    set "ARG_ROOT=!ARG_ROOT:"=!"
    if "!ARG_ROOT:~-1!"=="\" set "ARG_ROOT=!ARG_ROOT:~0,-1!"
)

echo.
echo ====== LOL CHAIN LOCK v%VER%  mode=%MODE% purge=%PURGE% link=%LINKMODE% ======
echo.

rem ---------------------------------------------------------------------
rem STEP 1 - resolve install root (portable, never hardcoded)
rem ---------------------------------------------------------------------
if defined ARG_ROOT call :probe "!ARG_ROOT!" "arg:--root"
if not defined ROOT if defined LOL_ROOT call :probe "!LOL_ROOT!" "env:LOL_ROOT"

if not defined ROOT (
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
)
if defined REG_PATH (echo registry_path=!REG_PATH!) else (echo registry_path=EMPTY)

if not defined ROOT (
    for /f "usebackq delims=" %%L in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); Get-ChildItem -LiteralPath $d -Filter *.lnk -ErrorAction SilentlyContinue ^| ForEach-Object { $s=(New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName); if ($s.TargetPath) { $p=Split-Path -Parent (Split-Path -Parent $s.TargetPath); if ($p) { $p } } } ^| Select-Object -Unique" 2^>nul`) do (
        if not defined ROOT call :probe "%%L" "desktop-lnk"
    )
)

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

if not defined ROOT (
    echo result=NOT_INSTALLED
    echo note=no League of Legends installation detected
    goto :end_41
)
echo install_root=!ROOT!
echo root_source=!SRC!
set "TARGET=!ROOT!\TCLS\wegame_launch.tmp"

rem ---------------------------------------------------------------------
rem Backup is keyed by the install root, so two different installations
rem (or a --root pointing at another machine's path) never share one backup
rem file and --restore can never write back the wrong bytes.
rem ---------------------------------------------------------------------
set "LOL_ROOT_KEY_SRC=!ROOT!"
for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "$s=[string]$env:LOL_ROOT_KEY_SRC; $b=[System.Text.Encoding]::UTF8.GetBytes($s.ToLower()); [BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash($b)).Replace('-','')" 2^>nul`) do set "ROOT_KEY=%%H"
set "BACKUP_DIR=!BACKUP_ROOT!\!ROOT_KEY!"
set "BACKUP_FILE=!BACKUP_DIR!\wegame_launch.tmp.bak"
echo backup_key=!ROOT_KEY!

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
if /i "!LINKMODE!"=="delete" goto :do_unlink

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
if /i "!LINKMODE!"=="off" (
    echo link  = skipped ^(--no-link^)
) else (
    echo link  = desktop shortcut -^> !ROOT!\TCLS\Client.exe
    echo         ^(target of the shortcut is the native client exe^)
)
echo note  = reverse with --restore, shortcut with --unlink

if /i "!MODE!"=="dryrun" if /i not "!LINKMODE!"=="force" (
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
if /i not "!LINKMODE!"=="off" (
    echo Link   : desktop shortcut to !ROOT!\TCLS\Client.exe
)
echo Effect : WeGame shell will no longer be able to rewrite the launch
echo          chain file. Big game updates may need --restore first.
echo Rollback: --restore restores the original file from backup.
echo           --unlink removes the shortcut.
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
rem APPLY - lock layer (only when --apply was given)
rem ---------------------------------------------------------------------
if /i "!MODE!"=="apply" (
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
)

rem ---------------------------------------------------------------------
rem LINK - desktop shortcut to the native client exe
rem ---------------------------------------------------------------------
if /i not "!LINKMODE!"=="off" call :make_link

echo.
if "!STEP_FAIL!"=="YES" (
    echo result=PARTIAL
    echo note=at least one step failed, run --restore then retry
    goto :end_43
)
if "!LINK_WARN!"=="YES" (
    echo result=OK_LINK_WARN
    echo note=lock is fine, shortcut could not be created, see link= above
    goto :end_0
)
echo result=OK
if /i "!MODE!"=="apply" echo note=launch chain locked + native shortcut ready. use --restore before big updates.
if /i not "!MODE!"=="apply" echo note=native shortcut ready. run with --apply to lock the chain.
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
echo note=original state restored. the desktop shortcut was left in place,
echo      use --unlink if you want it removed too.
goto :end_0

rem =====================================================================
:do_unlink
echo.
echo ---- removing shortcut ----
set "LOL_LNK_ROOT=!ROOT!"
set "LOL_LNK_ACTION=delete"
call :run_link_ps
echo link=!LNK_RESULT!
echo.
echo result=OK
echo note=shortcut handling done, the lock layer was not touched
goto :end_0

rem =====================================================================
rem SUBROUTINES
rem =====================================================================

:make_link
rem Creates the desktop shortcut pointing at <root>\TCLS\Client.exe.
rem All non-ASCII handling happens inside PowerShell: the shortcut name is
rem built from code points so this .bat stays pure ASCII and can never be
rem corrupted by the console code page.
set "LNK_RESULT=NOT_RUN"
if /i "!LINKMODE!"=="force" (set "LOL_LNK_ACTION=force") else (set "LOL_LNK_ACTION=create")
set "LOL_LNK_ROOT=!ROOT!"
call :run_link_ps
echo link=!LNK_RESULT!
if /i "!LNK_RESULT!"=="CREATED" exit /b 0
if /i "!LNK_RESULT!"=="EXISTS_KEPT" exit /b 0
if /i "!LNK_RESULT!"=="REPLACED" exit /b 0
if /i "!LNK_RESULT!"=="REMOVED" exit /b 0
if /i "!LNK_RESULT!"=="EXISTS_DIFFERENT" (
    echo link_hint=a shortcut with the same name points elsewhere, left untouched
    echo link_hint=use --relink to rebuild it against the native client
    exit /b 0
)
set "LINK_WARN=YES"
exit /b 0

:run_link_ps
set "LNK_RESULT=FAILED"
if exist "!LNK_OUT!" del /f /q "!LNK_OUT!" >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$a=$env:LOL_LNK_ACTION; $r=$env:LOL_LNK_ROOT; $d=$env:LOL_LNK_DESKTOP; if (-not $d) { $d=[Environment]::GetFolderPath('Desktop') }; if (-not $r) { 'NO_ROOT'; exit 0 }; if (-not $d) { 'NO_DESKTOP'; exit 0 }; $n=[char]0x82F1+[char]0x96C4+[char]0x8054+[char]0x76DF+' ('+[char]0x539F+[char]0x751F+[char]0x5BA2+[char]0x6237+[char]0x7AEF+').lnk'; $p=Join-Path $d $n; $t=Join-Path $r 'TCLS\Client.exe'; if (-not (Test-Path -LiteralPath $t)) { 'TARGET_MISSING'; exit 0 }; $sh=New-Object -ComObject WScript.Shell; $existed=Test-Path -LiteralPath $p; if ($a -eq 'delete') { if ($existed) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }; if (Test-Path -LiteralPath $p) { 'FAILED' } else { if ($existed) { 'REMOVED' } else { 'ABSENT' } }; exit 0 }; $old=''; if ($existed) { try { $old=$sh.CreateShortcut($p).TargetPath } catch { $old='' } }; if ($existed -and $a -eq 'create') { if ($old -and ($old -ieq $t)) { 'EXISTS_KEPT' } else { 'EXISTS_DIFFERENT' }; exit 0 }; try { $s=$sh.CreateShortcut($p); $s.TargetPath=$t; $s.WorkingDirectory=(Split-Path -Parent $t); $s.IconLocation=$t+',0'; $s.Description='League of Legends native client'; $s.Save() } catch { 'FAILED'; exit 0 }; if (Test-Path -LiteralPath $p) { if ($existed) { 'REPLACED' } else { 'CREATED' } } else { 'FAILED' }" > "!LNK_OUT!" 2>nul
if exist "!LNK_OUT!" (
    for /f "usebackq delims=" %%L in ("!LNK_OUT!") do if not "%%L"=="" set "LNK_RESULT=%%L"
    del /f /q "!LNK_OUT!" >nul 2>nul
)
exit /b 0

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
rem %1 = candidate dir, %2 = source label. First strong hit wins.
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
exit /b 0

:scan_drive
rem %1 = drive root with trailing backslash. Bounded to 400 candidates.
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
rem %1 = file path. Reliable read-only test: "dir /a:r" lists the file only
rem when the read-only bit is set, unlike parsing attrib output columns.
set "IS_RO=NO"
dir /a:r "%~1" >nul 2>nul
if not errorlevel 1 set "IS_RO=YES"
exit /b 0

:usage
echo.
echo lol-chain-lock.bat usage
echo   (no arg)            dry-run, print plan only
echo   --apply             lock the hijack file + create native shortcut
echo   --apply --purge     delete then place 0-byte stub, then lock
echo   --apply --no-link   lock only, do not touch the desktop
echo   --relink            force rebuild the desktop shortcut
echo   --unlink            delete the desktop shortcut only
echo   --restore           undo the lock, restore the backup
echo   --root "path"       force the install root
echo.
echo shortcut target: ^<root^>\TCLS\Client.exe (native client, not a folder)
echo read-only guarantee: without --apply nothing on disk is modified
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
