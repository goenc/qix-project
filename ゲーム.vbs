Option Explicit

Dim shell
Dim fso
Dim projectDir
Dim godotExe
Dim command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
projectDir = fso.GetParentFolderName(WScript.ScriptFullName)
godotExe = "C:\Tools\Godot\godot.exe"

If Not fso.FileExists(godotExe) Then
  godotExe = "godot.exe"
End If

command = """" & godotExe & """ --path """ & projectDir & """"
shell.CurrentDirectory = projectDir
shell.Run command, 1, False
