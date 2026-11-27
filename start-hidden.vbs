
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

folder = fso.GetParentFolderName(WScript.ScriptFullName)
bat = Chr(34) & folder & "\start-helper.bat" & Chr(34)

shell.CurrentDirectory = folder
shell.Run bat, 0, False
