@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "ROOT=C:\melonDS-1.1"
set "BUILD=%ROOT%\build"
set "MAIN=%ROOT%\src\frontend\qt_sdl\main.cpp"
set "CONFIG=%ROOT%\src\frontend\qt_sdl\Config.cpp"
set "LOG=%BUILD%\build_debug.log"
set "PS1=%TEMP%\melonds_patch.ps1"
set "DBG=%TEMP%\melonds_debug.ps1"

echo ========================================
echo  melonDS custom build (auto patch + debug)
echo ========================================
echo.

if not exist "%MAIN%" (
    echo ERROR: not found
    echo   %MAIN%
    pause
    exit /b 1
)
if not exist "%CONFIG%" (
    echo ERROR: not found
    echo   %CONFIG%
    pause
    exit /b 1
)
if not exist "%BUILD%" (
    echo ERROR: build folder not found
    echo   %BUILD%
    echo Please run CMake first.
    pause
    exit /b 1
)

echo [1/3] Creating backups...
if not exist "%MAIN%.bak" copy /Y "%MAIN%" "%MAIN%.bak" >nul
if not exist "%CONFIG%.bak" copy /Y "%CONFIG%" "%CONFIG%.bak" >nul
echo       OK

echo [2/3] Patching source files...

> "%PS1%" echo $ErrorActionPreference = 'Stop'
>>"%PS1%" echo $main = '%MAIN%'
>>"%PS1%" echo $cfg  = '%CONFIG%'
>>"%PS1%" echo.
>>"%PS1%" echo # ----- main.cpp -----
>>"%PS1%" echo $c = [IO.File]::ReadAllText($main, [Text.Encoding]::UTF8)
>>"%PS1%" echo if ($c -match 'Always start in fullscreen \(custom\)') {
>>"%PS1%" echo     Write-Host '  main.cpp already patched'
>>"%PS1%" echo } else {
>>"%PS1%" echo     $target = 'win-^>preloadROMs(dsfile, gbafile, options-^>boot);'
>>"%PS1%" echo     if ($c -notlike "*$target*") {
>>"%PS1%" echo         Write-Host '  ERROR: target line not found in main.cpp'
>>"%PS1%" echo         exit 1
>>"%PS1%" echo     }
>>"%PS1%" echo     $insert = @"
>>"%PS1%" echo win-^>preloadROMs(dsfile, gbafile, options-^>boot);
>>"%PS1%" echo.
>>"%PS1%" echo         // Always start in fullscreen (custom)
>>"%PS1%" echo         if (!win-^>isFullScreen())
>>"%PS1%" echo             win-^>toggleFullscreen();
>>"%PS1%" echo "@
>>"%PS1%" echo     $c = $c.Replace($target, $insert)
>>"%PS1%" echo     [IO.File]::WriteAllText($main, $c, [Text.UTF8Encoding]::new($false))
>>"%PS1%" echo     Write-Host '  main.cpp patched'
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo # ----- Config.cpp -----
>>"%PS1%" echo $c = [IO.File]::ReadAllText($cfg, [Text.Encoding]::UTF8)
>>"%PS1%" echo if ($c -match 'HK_FullscreenToggle') {
>>"%PS1%" echo     Write-Host '  Config.cpp already patched'
>>"%PS1%" echo } else {
>>"%PS1%" echo     if ($c -notmatch '#include ^<QKeySequence^>') {
>>"%PS1%" echo         $c = $c -replace '(#include "Config\.h")', "`$1`r`n#include ^<QKeySequence^>"
>>"%PS1%" echo     }
>>"%PS1%" echo     $add = '    {"Instance*.Keyboard.HK_FullscreenToggle", Qt::Key_F11},'
>>"%PS1%" echo     if ($c -notmatch 'DefaultList^<int^> DefaultInts = \{') {
>>"%PS1%" echo         Write-Host '  ERROR: DefaultInts not found in Config.cpp'
>>"%PS1%" echo         exit 1
>>"%PS1%" echo     }
>>"%PS1%" echo     $c = $c -replace '(DefaultList^<int^> DefaultInts = \{)', ("`$1`r`n" + $add)
>>"%PS1%" echo     [IO.File]::WriteAllText($cfg, $c, [Text.UTF8Encoding]::new($false))
>>"%PS1%" echo     Write-Host '  Config.cpp patched'
>>"%PS1%" echo }

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
if errorlevel 1 (
    echo.
    echo *** Patch failed ***
    del "%PS1%" 2>nul
    pause
    exit /b 1
)
del "%PS1%" 2>nul

echo [3/3] Building...
cd /d "%BUILD%"
del "%LOG%" 2>nul
ninja -j1 > "%LOG%" 2>&1
if errorlevel 1 (
    echo.
    echo *** Build failed ***
    echo.
    echo ===== Ninja summary =====
    type "%LOG%"
    echo =========================
    echo.
    echo Capturing real compiler errors...
    echo.

    > "%DBG%" echo $log = Get-Content '%LOG%' -Raw
    >>"%DBG%" echo $cmds = [regex]::Matches($log, 'C:\\msys64\\ucrt64\\bin\\c\+\+\.exe[^\r\n]+') ^| ForEach-Object { $_.Value }
    >>"%DBG%" echo foreach ($cmd in $cmds) {
    >>"%DBG%" echo     Write-Host ('=== ' + $cmd.Substring(0,[Math]::Min(100,$cmd.Length)) + ' ===') -ForegroundColor Cyan
    >>"%DBG%" echo     cmd /c ($cmd + ' 2^>^&1')
    >>"%DBG%" echo     Write-Host ''
    >>"%DBG%" echo }

    powershell -NoProfile -ExecutionPolicy Bypass -File "%DBG%"

    echo.
    echo --- Source check ---
    findstr /n /c:"isFullScreen" /c:"preloadROMs" "%MAIN%"
    echo.
    findstr /n /c:"Qt::Key_F11" /c:"QKeySequence" /c:"DefaultInts" "%CONFIG%"
    echo.
    del "%DBG%" 2>nul
    pause
    exit /b 1
)

echo.
echo ========================================
echo  Build OK!
echo  %BUILD%\melonDS.exe
echo ========================================
pause