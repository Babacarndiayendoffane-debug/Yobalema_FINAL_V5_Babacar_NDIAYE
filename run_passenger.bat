@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo  Lancement de Yobalema Passager (Chrome Direct)
echo ========================================================

if exist "%LOCALAPPDATA%\flutter\bin\flutter.bat" (
    set "PATH=%LOCALAPPDATA%\flutter\bin;%PATH%"
) else if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    set "PATH=%USERPROFILE%\flutter\bin;%PATH%"
) else if exist "C:\src\flutter\bin\flutter.bat" (
    set "PATH=C:\src\flutter\bin;%PATH%"
)

where flutter >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERREUR : Flutter est introuvable.
    echo Ajoutez le dossier bin de Flutter au PATH Windows,
    echo puis relancez ce fichier.
    pause
    exit /b 1
)

rem Smoke check : verify that the discovered Flutter command can run.
call flutter --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERREUR : Flutter est present dans le PATH mais ne peut pas etre execute.
    pause
    exit /b 1
)

rem Smoke check : distinguish an occupied port from a failed port check.
powershell -NoProfile -Command "$ErrorActionPreference = 'Stop'; try { $listener = Get-NetTCPConnection -LocalPort 3000 -State Listen; if ($listener) { exit 1 } else { exit 0 } catch { exit 2 }" >nul 2>&1
if errorlevel 2 goto :port_check_failed
if errorlevel 1 goto :port_occupied
goto :run_flutter
:port_check_failed
echo.
echo ERREUR : impossible de verifier la disponibilite du port 3000.
echo Verifiez que PowerShell et la commande Get-NetTCPConnection sont disponibles,
echo puis relancez ce fichier.
pause
exit /b 1
:port_occupied
echo.
echo ERREUR : le port 3000 est deja utilise.
echo Fermez l'application qui l'utilise ou choisissez un autre port,
echo puis relancez ce fichier.
pause
exit /b 1
:run_flutter
call flutter run -d chrome -t lib/main_passenger.dart --web-port=3000 --web-hostname=127.0.0.1
if errorlevel 1 (
    echo.
    echo ERREUR : le lancement de Yobalema Passager a echoue.
    pause
    exit /b 1
)

endlocal
