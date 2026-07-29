@echo off
setlocal

set "SRC=%~dp0scoreboard_settings.json"
set "TARGET1=%~dp0..\..\save_data\Atlas418.CustomScoreboard"

if not exist "%SRC%" (
	echo "ERROR: source file not found: %SRC% "
	pause
	exit /b 1
)

call :linkone "%TARGET1%"

echo.
echo Done.
pause
exit /b 0

:linkone
set "DIR=%~1"

if not exist "%DIR%" (
	echo "Creating folder: %DIR%"
	mkdir "%DIR%"
)

if exist "%DIR%\scoreboard_settings.json" (
	echo "Removing existing file: %DIR%\scoreboard_settings.json"
	del /f "%DIR%\scoreboard_settings.json"
)

echo "Linking %DIR%\scoreboard_settings.json"
mklink /H "%DIR%\scoreboard_settings.json" "%SRC%"
if errorlevel 1 (
	echo "  ^-^> FAILED. Are the source and target on the same drive?"
) else (
	echo "  ^-^> OK \n"
)

exit /b 0
