'On Error Resume Next
'***********************
'VBScript
'***********************

'Number of days back to start deleting
daysAgo = 365

'Path to Directory to delete old files
dirPath = "C:\test"


'***********************
'Begin
'***********************

Set fs = CreateObject("Scripting.FileSystemObject")
Set w = WScript.CreateObject("WScript.Shell")

Set colNamedArguments = WScript.Arguments.Named

' Check for command argument for days old.
specDays = colNamedArguments.Item("d")

If specDays <> "" Then
	For i = 1 to Len(specDays)
		ThisChar = Mid(specDays, i, 1)
		If Asc(ThisChar) < 48 Or Asc(ThisChar) > 57 Then
			Wscript.Echo "/d was not specified as a number" 
			Wscript.Quit(1)
		End If 
	Next
	daysAgo = specDays
	Wscript.Echo "Command line switch sets days to " & daysAgo & "."
	
Else
	Wscript.Echo "Command line switch unset, using " & daysAgo & "."
End If

' Check for command argument for folder path
specDir = colNamedArguments.Item("f")

If specDir <> "" Then
	dirPath = specDir
	Wscript.Echo "Command line switch sets base folder to " & dirPath & "."
Else
	Wscript.Echo "Command line switch unset, using " & dirPath & "."
End If

' Validation complete, proceed with actual processing.

Set f = fs.GetFolder(dirPath)

dateBefore = Now() - daysAgo

GoSubFolders(f)

Sub DeleteFiles(oDir)
	For Each File in oDir.Files
		On Error Resume Next
		
		If File.DateLastModified < dateBefore Then
			Wscript.Echo "Deleting " & File.Name
			fs.DeleteFile(File.Path)
		End If
		
	Next
End Sub
	
Sub GoSubFolders(oDir)
	DeleteFiles(oDir)
	
	For Each Folder in oDir.SubFolders
		GoSubFolders(Folder)
	Next
End Sub

Set colNamedArguments = Nothing
Set w = Nothing
Set fs = Nothing