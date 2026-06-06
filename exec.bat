@echo off
cd /d %~dp0

REM ===================== CONVERSION MODE =====================
REM You can pass the mode as an argument (exec.bat 1/2/3) or pick it from the menu.
set "MODE=%~1"
set "INTERACTIVE=1"
if not "%MODE%"=="" (
    set "INTERACTIVE=0"
    goto :setmode
)

echo Choose a mode to convert:
echo   1 - Best Quality
echo   2 - Balanced
echo   3 - Lower Quality
echo.
set /p "MODE=Option [1/2/3]: "

:setmode
if "%MODE%"=="1" (
    set "WEBM_CRF=18"
    set "WEBM_AUDIO=192k"
    set "WEBM_CPU=0"
    set "WEBP_LOSSLESS=1"
    set "WEBP_QUALITY=100"
    set "WEBP_METHOD=6"
) else if "%MODE%"=="3" (
    set "WEBM_CRF=40"
    set "WEBM_AUDIO=96k"
    set "WEBM_CPU=4"
    set "WEBP_LOSSLESS=0"
    set "WEBP_QUALITY=60"
    set "WEBP_METHOD=6"
) else (
    set "MODE=2"
    set "WEBM_CRF=30"
    set "WEBM_AUDIO=128k"
    set "WEBM_CPU=2"
    set "WEBP_LOSSLESS=0"
    set "WEBP_QUALITY=80"
    set "WEBP_METHOD=6"
)
echo Mode selected: %MODE%
REM ==========================================================

if not exist "input" (
    echo Input folder not found.
    goto :fail
)

if not exist "output" mkdir "output"

REM ===================== FFMPEG ======================
REM Use ffmpeg from PATH; otherwise download a local copy automatically.
set "FFMPEG=ffmpeg"
where ffmpeg >nul 2>&1
if not errorlevel 1 goto :run
set "FFMPEG=%~dp0ffmpeg\bin\ffmpeg.exe"
if not exist "%FFMPEG%" (
    echo ffmpeg not found - downloading a local copy, one time ~80 MB...
    call :get_ffmpeg
)
if not exist "%FFMPEG%" (
    echo Could not obtain ffmpeg. Install it or check your internet connection.
    goto :fail
)
REM ==================================================

:run
for %%F in ("input\*.*") do call :process "%%F"

echo.
echo Done.
goto :end

:process
set "infile=%~1"
set "name=%~n1"
set "ext=%~x1"
set "short=%name:~0,10%%ext%"
if not "%name:~10,1%"=="" set "short=%name:~0,10%...%ext%"

set "action=ignore"
if /i "%ext%"==".jpg"  set "action=webp"
if /i "%ext%"==".jpeg" set "action=webp"
if /i "%ext%"==".png"  set "action=webp"
if /i "%ext%"==".mp4"  set "action=webm"
if /i "%ext%"==".gif"  set "action=move"
if /i "%ext%"==".webp" set "action=move"

if "%action%"=="webp"   call :webp
if "%action%"=="webm"   call :webm
if "%action%"=="move"   call :movefile
if "%action%"=="ignore" echo Skipped: %short%

goto :eof

:webp
echo %short%
if "%WEBP_LOSSLESS%"=="1" (
    "%FFMPEG%" -hide_banner -loglevel error -y -i "%infile%" -c:v libwebp -lossless 1 -method %WEBP_METHOD% "output\%name%.webp"
) else (
    "%FFMPEG%" -hide_banner -loglevel error -y -i "%infile%" -c:v libwebp -quality %WEBP_QUALITY% -method %WEBP_METHOD% "output\%name%.webp"
)
if errorlevel 1 (echo   Error processing %short%)
goto :eof

:webm
echo %short%
"%FFMPEG%" -hide_banner -loglevel error -y -i "%infile%" -c:v libvpx-vp9 -crf %WEBM_CRF% -b:v 0 -deadline good -cpu-used %WEBM_CPU% -c:a libopus -b:a %WEBM_AUDIO% "output\%name%.webm"
if errorlevel 1 (echo   Error processing %short%)
goto :eof

:movefile
echo %short%
copy /y "%infile%" "output\" >nul
if errorlevel 1 (echo   Error copying %short%)
goto :eof

:get_ffmpeg
set "ZIP=%TEMP%\ffmpeg_dl.zip"
set "EXDIR=%TEMP%\ffmpeg_dl"
if exist "%EXDIR%" rmdir /s /q "%EXDIR%"
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%ZIP%' } catch { exit 1 }"
if errorlevel 1 goto :eof
powershell -NoProfile -Command "try { Expand-Archive -Path '%ZIP%' -DestinationPath '%EXDIR%' -Force } catch { exit 1 }"
if errorlevel 1 goto :eof
if not exist "%~dp0ffmpeg\bin" mkdir "%~dp0ffmpeg\bin"
for /r "%EXDIR%" %%f in (ffmpeg.exe) do copy /y "%%f" "%~dp0ffmpeg\bin\ffmpeg.exe" >nul
del /q "%ZIP%" >nul 2>&1
rmdir /s /q "%EXDIR%" >nul 2>&1
goto :eof

:end
if "%INTERACTIVE%"=="1" pause
exit /b 0

:fail
if "%INTERACTIVE%"=="1" pause
exit /b 1
