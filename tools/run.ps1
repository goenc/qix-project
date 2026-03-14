$projectPath = Split-Path -Parent $PSScriptRoot
Set-Location $projectPath
godot_console --path .
