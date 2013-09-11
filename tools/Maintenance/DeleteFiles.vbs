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
		If Chr(Mid(specDays, i, 1)) < 48 Or Chr(Mid(specDays, i, 1)) > 57 Then
			Wscript.Echo "/d was not specified as a number" 
			Wscript.Quit(1)
		End If 
	Next
	
	Wscript.Echo "Command line switch sets days to " & specDays & "."
	daysAgo = specDays
Else
	Wscript.Echo "Command line switch unset, using " & specDays & "."
End If

' Check for command argument for folder path
specDir = colNamedArguments.Item("f")

If specDir <> "" Then
	Wscript.Echo "Command line switch sets base folder to " & specDir & "."
	dirPath = specDir
Else
	Wscript.Echo "Command line switch unset, using " & specDir & "."
End If

' Validation complete, proceed with actual processing.

Set f = fs.GetFolder(dirPath)
Set fc = f.Files

dateBefore = Now() - daysAgo

For Each ff in fc
	fileName = ff.Name
	fileDate = ff.DateLastModified

	If fileDate < dateBefore Then
		Wscript.Echo "Deleting " & fileName
		fs.DeleteFile(dirPath & "\" & fileName)
	End If
Next

Set fc = Nothing
Set f = Nothing
Set colNamedArguments = Nothing
Set w = Nothing
Set fs = Nothing