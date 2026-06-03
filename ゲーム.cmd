@echo off
setlocal
cd /d "%~dp0"
set "GODOT_EXE=C:\Tools\Godot\godot.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=godot.exe"
start "" /D "%~dp0" "%GODOT_EXE%" --path "%~dp0"
if errorlevel 1 (
	echo Godot could not be started.
	pause
)
