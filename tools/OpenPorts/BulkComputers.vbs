'*************************************************************************** 
' Bulk Computers.vbs
' Copyright (c) 2013, RedEyeTek, LLC
' All rights reserved.
'
' Redistribution and use in source and binary forms, with or without
' modification, are permitted provided that the following conditions are met:
'    * Redistributions of source code must retain the above copyright
'      notice, this list of conditions and the following disclaimer.
'    * Redistributions in binary form must reproduce the above copyright
'      notice, this list of conditions and the following disclaimer in the
'      documentation and/or other materials provided with the distribution.
'    * Neither the name of RedEyeTek, LLC nor the names of its contributors
'      may be used to endorse or promote products derived from this 
'	   software without specific prior written permission.
'
' THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
' ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
' WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
' DISCLAIMED. IN NO EVENT SHALL REDEYETEK, LLC BE LIABLE FOR ANY
' DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
' (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
' LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
' ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
' (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
' SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'
'
' The intent of this script is to push a script to a remote machine, have it run
' and then retrieve the results.
'
' It is a work in progress and there are something that don't have variables yet.
' 
' It requires that you send the script the /i:<input file>.  The format of which is:
'
' <Server Name>,<IP or DNS Name>,<Username>,<Password>,<Domain>
'
' You may use a leading # sign to comment a line.
'
'***************************************************************************

'*************************************************************************** 
' BEGIN USER VARIABLES
'***************************************************************************
' Remote Destination of the script
strDestPath = "C:\"

' Share name if the destination path is not already shared
usrShareName = "SetFile"

' Script to be copied
SourceScriptFile = "OpenPorts.bat"

' Specify a location for the results to be stored locally.
LogDirectory = "C:\PortLogs"

' Set to true if you want a master file that combines the results into a 
' single file.
DoCombinedResults = True

'*************************************************************************** 
' END USER VARIABLES
'***************************************************************************

'*************************************************************************** 
' BEGIN MAIN CODE
'***************************************************************************

On Error Resume Next

Const FILE_SHARE = 0, MAXIMUM_CONNECTIONS = 1
Const ForReading = 1, ForWriting = 2, ForAppending = 8

Set colNamedArguments = WScript.Arguments.Named
CredentialFile = colNamedArguments.Item("i")
 
'If a remote computer is not specified, look at local. 
If CredentialFile = "" Then
	Wscript.Echo "No input file specified, you should run " & SourceScriptFile & " manually."
	Wscript.Quit(0)
End If
 
'Format date for log file.
strDate = Year(Now()) & "-" & Right("0" & Month(Now()), 2) & "-" & Right("0" & Day(Now()), 2)

Set oFSO=CreateObject("Scripting.FileSystemObject")
Set Locator = CreateObject("WbemScripting.SWbemLocator")
 
'Setup for credential file for reading.
Set oInputFile=oFSO.OpenTextFile(CredentialFile, ForReading)

'Loop through Credential file
Do While Not oInputFile.AtEndOfStream
	
	ThisLine = oInputFile.Readline
	
	If Left(ThisLine, 1) <> "#" Then
		arrCred = Split(ThisLine, ",")  ' Find Credentials in the file
		strComputer = arrCred(1)
			
		' Connect to the WMI service
		Set objWMIService = Locator.ConnectServer(strComputer, "root\cimv2", _
			arrCred(4) & "\" & arrCred(2), arrCred(3))
		
		If Err.Number <> 0 Then
			Wscript.Echo "Error connecting to " & strComputer & ".  " & Err.Description
			Err.Clear
		Else
			strShareName = CheckShare(strDestPath, usrShareName) 'Look for the share, create if it doesn't exist.

			strUNCPath = "\\" & strComputer & "\" & strShareName 'build the unc path
			
			myExecute = "net use " & strUNCPath & " /user:" & arrCred(4) & "\" & arrCred(2) & " " & arrCred(3)
			set WshShell = CREATEOBJECT("WScript.Shell")
			Set oExec = WshShell.Exec(myExecute)

			Do While oExec.Status = 0
				WScript.Sleep 100
			Loop

			If Not oFSO.FileExists(SourceScriptFile) Then
				Wscript.Echo "Source Script File does not exist, exiting." 
				Wscript.Quit
			End If 
			
			Set srcScriptFile = oFSO.OpenTextFile(SourceScriptFile, ForReading) 'open source script file
			Set dstScriptFile = oFSO.OpenTextFile(strUNCPath & "\" & oFSO.GetFileName(SourceScriptFile), ForWriting, True) 'open destination script file
			
			Wscript.Echo strComputer
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
				
				'Set colMonitoredProcesses = objWMIService.ExecNotificationQuery _
				'	("Select * From __InstanceDeletionEvent Within 1 Where TargetInstance ISA 'Win32_Process'")

				'Do Until i = 1
				'	Set objLatestProcess = colMonitoredProcesses.NextEvent
				'	If objLatestProcess.TargetInstance.ProcessID = intProcessID Then
				'		i = 1
				'	End If
				'Loop
				
				'Move back results
				retrieveFile = strUNCPath & "\" & strDate & "_OpenPorts.txt"
				
				If Not oFSO.FolderExists(LogDirectory) Then
					oFSO.CreateFolder(LogDirectory)
				End If
				
				Do  
					WScript.Sleep 100
				Loop Until oFSO.FileExists(retrieveFile)
				
				'If oFSO.FileExists(retrieveFile) Then
					oFSO.CopyFile retrieveFile, LogDirectory & "\" & strDate & "_" & strComputer & "_OpenPorts.txt"
				'Else 
				'	wscript.echo retrieveFile & " does not exist."
				'End If
				
				'Delete/Remove Evidence
				oFSO.DeleteFile(retrieveFile)
				oFSO.DeleteFile(strUNCPath & "\" & oFSO.GetFileName(SourceScriptFile))
				
				' Remove the share if we created it.
				If strShareName = usrShareName Then
					Set colShares = objWMIService.ExecQuery("SELECT * FROM Win32_Share WHERE name = '" & usrShareName & "'")  'Look for an existing share in the target directory
					
					For Each Share in colShares
						Share.Delete()
					Next
					
					Set colShares = Nothing
				End If
			End If

			myExecute = "net use " & strUNCPath & " /delete /y"
			Set oExec = WshShell.Exec(myExecute)

			Do While oExec.Status = 0
				WScript.Sleep 100
			Loop
			
			Set objWMIService = Nothing		
		End If
	End If
Loop

If DoCombinedResults Then
	CombineResults
End If

'*************************************************************************** 
' SUB ROUTINES
'***************************************************************************

Function CheckShare(strShareName, strDirectory)

	'Look for the specified share, create it if it doesn't exist.
	
	Set colShares = objWMIService.ExecQuery("SELECT * FROM Win32_Share WHERE path = 'C:\\'")  'Look for an existing share in the target directory

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
	
	CheckShare = ShareName
End Function

Sub CombineResults()
	'Combine Results into a single file
	Set oFolder = oFSO.GetFolder(LogDirectory)

	Set masterFile = oFSO.OpenTextFile(LogDirectory & "\MasterFile.txt", ForAppending, True) 

	'loop through the folder and get the file names
	For Each oFile In oFolder.Files
		If not oFile.Name = "MasterFile.txt" And Right(oFile.Name, 3) = "txt" Then
			Set resultFile = oFSO.OpenTextFile(oFile.Path, ForReading) 'open source file
			masterFile.Write(resultFile.ReadAll)
		End If
	Next

	masterFile.Close

End Sub