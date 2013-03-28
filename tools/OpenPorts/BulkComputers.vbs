

'*************************************************************************** 
' BEGIN USER VARIABLES
'***************************************************************************
usrShareName = "SetFile"

strDestPath = "C:\"

SourceScriptFile = "OpenPorts.bat"

LogDirectory = "..\PortLogs"

'*************************************************************************** 
' END USER VARIABLES
'***************************************************************************

'*************************************************************************** 
' BEGIN MAIN CODE
'***************************************************************************

Const FILE_SHARE = 0
Const MAXIMUM_CONNECTIONS = 1
Const ForReading = 1, ForWriting = 2, ForAppending = 8

Set colNamedArguments = WScript.Arguments.Named
CredentialFile = colNamedArguments.Item("i")
 
'If a remote computer is not specified, look at local. 
If CredentialFile = "" Then
	Set wshShell = WScript.CreateObject("WScript.Shell")
	CredentialFile = wshShell.ExpandEnvironmentStrings( "%COMPUTERNAME%" )
End If
 
'Format date for log file.
strDate = Year(Now()) & "-" & Right("0" & Month(Now()), 2) & "-" & Right("0" & Day(Now()), 2)

Set oFSO=CreateObject("Scripting.FileSystemObject")
Set Locator = CreateObject("WbemScripting.SWbemLocator")
 
'Setup for credential file for reading.
Set oInputFile=oFSO.OpenTextFile(CredentialFile, ForReading)

'Loop through Credential file
Do While Not oInputFile.AtEndOfStream
	Dim arrCred(3)
	
	arrCred = Split(oInputFile.Readline, ",")  ' Find Credentials in the file
	strComputer = arrCred(0)
	
	Set objWMIService = Locator.ConnectServer(arrCred(0), "root\cimv2", arrCred(3) & "\" & arrCred(1), arrCred(2))

	strShareName = CheckShare(strDestPath, usrShareName) 'Look for the share, create if it doesn't exist.

	strUNCPath = "\\" & strComputer & "\" & ShareName 'build the unc path
	
	Set srcScriptFile = oFSO.OpenTextFile(SourceScriptFile, 0) 'open source script file
	Set dstScriptFile = oFSO.OpenTextFile(strUNCPath & "\" & oFSO.GetFileName(SourceScriptFile), 1, True) 'open destination script file
	
	dstScriptFile.Write(srcScriptFile.ReadAll) 'Create the script file on the remote server

	srcScriptFile.Close
	dstScriptFile.Close
	
	Set oWMIProcess = objWMIService.Get("Win32_Process") 
	intReturn = oWMIProcess.Create(strDestPath & SourceScriptFile, Null, Null, intProcessID)
	
	If intReturn <> 0 Then 'Error
		Wscript.Echo "Process could not be created." & _
			vbNewLine & "Command line: " & strCommand & _
			vbNewLine & "Return value: " & intReturn
	Else 'No Error, wait for completion
		Set colMonitoredProcesses = objWMIService.ExecNotificationQuery _
			("Select * From __InstanceDeletionEvent Within 1 Where TargetInstance ISA 'Win32_Process'")

		Do Until i = 1
			Set objLatestProcess = colMonitoredProcesses.NextEvent
			If objLatestProcess.TargetInstance.ProcessID = intProcessID Then
				i = 1
			End If
		Loop
		
		'Move back results
		retrieveFile = strUNCPath & "\" & strDate & "_OpenPorts.txt"
		
		If Not oFSO.FolderExists(LogDirectory) Then
			oFSO.CreateFolder(LogDirectory)
		End If
		
		oFSO.CopyFile(retrieveFile, LogDirectory & "\" & strDate & "_" & strComputer & "_OpenPorts.txt")
		
		'Delete/Remove Evidence
		oFSO.DeleteFile(retrieveFile)
		oFSO.DeleteFile(strUNCPath & "\" & oFSO.GetFileName(SourceScriptFile))
		
		If strShareName = usrShareName Then
			Set colShares = objWMIService.ExecQuery("SELECT * FROM Win32_Share WHERE name = '" & usrShareName & "'")  'Look for an existing share in the target directory
			
			For Each Share in colShares
				Share.Delete()
			Next
			
			Set colShares = Nothing
		End If
		
	End If
Loop

CombineResults

'*************************************************************************** 
' SUB ROUTINES
'***************************************************************************

Function CheckShare(strShareName, strDirectory)

	'Look for the specified share, create it if it doesn't exist.
	
	Set colShares = objWMIService.ExecQuery("SELECT * FROM Win32_Share WHERE path = 'C:\'")  'Look for an existing share in the target directory

	If colShares.Count > 0 Then
		For Each oShare In colShares
			ShareName = oShare.Name
		Next
	Else
		Set objNewShare = objWMIService.Get("Win32_Share")
		intResponse = objNewShare.Create(strPath, strShareName, FILE_SHARE, MAXIMUM_CONNECTIONS, "Temp share to grab set file.")
		ShareName = strShareName
		Set objNewShare = Nothing
	End If

	Set colShares = Nothing
	
	Return ShareName
End Function

Sub CombineResults()
	'Combine Results into a single file
	Set oFolder = oFSO.GetFolder(LogDirectory)

	Set masterFile = oFSO.OpenTextFile(LogDirectory & "\MasterFile.txt", 8, False) 

	'loop through the folder and get the file names
	For Each oFile In oFolder.Files
		Set resultFile = oFSO.OpenTextFile(oFile.Path, 0) 'open source file
		masterFile.Write(resultFile.ReadAll)
	Next

	masterFile.Close

End Sub