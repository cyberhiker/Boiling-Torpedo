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
strDestPath = "\GSIRO-Scripts"

' Share name if the destination path is not already shared
usrShareName = "GSIRO-Scripts"

' Script to be copied
SourceScriptFile = "SetAuditing.bat"

' Specify a location for the results to be stored locally.
LogDirectory = "\GSIRO-Scripts\Logs"

' Drive letter to use
DriveLetter = "V:"

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

Set oFSO = CreateObject("Scripting.FileSystemObject")
Set oLocator = CreateObject("WbemScripting.SWbemLocator")
 
'Setup for credential file for reading.
Set oInputFile=oFSO.OpenTextFile(CredentialFile, ForReading)

'Loop through Credential file
Do While Not oInputFile.AtEndOfStream
	
	ThisLine = oInputFile.Readline
	
	If Left(ThisLine, 1) <> "#" Then
		arrCred = Split(ThisLine, ",")  ' Find Credentials in the file
		strComputer = arrCred(1)
			
		' Connect to the WMI service
		'Set objWMIService = oLocator.ConnectServer(strComputer, "root\cimv2", _
		'	arrCred(4) & "\" & arrCred(2), arrCred(3))
		
		Set objWMIService=GetObject("winmgmts:{impersonationLevel=impersonate}")
		
		' If there is a problem connecting to the remote computer.
		If Err.Number <> 0 Then
			Wscript.Echo "Error connecting to " & strComputer & ".  " & Err.Description
			Err.Clear
		Else
			strShareName = CheckShare(strDestPath, usrShareName) 'Look for the share, create if it doesn't exist.

			strUNCPath = "\\" & strComputer & "\" & strShareName 'build the unc path
			
			myExecute = "net use " & DriveLetter & " " & strUNCPath & " /user:" & arrCred(4) & "\" & arrCred(2) & " " & arrCred(3)
			set WshShell = CREATEOBJECT("WScript.Shell")
			Set oExec = WshShell.Exec(myExecute)

			Do While oExec.Status = 0
				WScript.Sleep 100
			Loop 	
			
			If Not oFSO.FileExists(SourceScriptFile) Then
				Wscript.Echo "Source Script File does not exist, exiting." 
				Wscript.Quit
			End If 
			
			oFSO.CopyFile SourceScriptFile, DriveLetter
			oFSO.CopyFile "AuditPol.exe", DriveLetter
			
			Wscript.Echo strComputer
			strCommand = strDestPath & "\" & SourceScriptFile
			
			'Fire the scripts
			Set oWMIProcess = objWMIService.Get("Win32_Process") 
			intReturn = oWMIProcess.Create(strCommand, Null, Null, intProcessID)
			
			If intReturn <> 0 Then 'Error
				Wscript.Echo "Process could not be created." & _
					vbNewLine & "Command line: " & strCommand & _
					vbNewLine & "Return value: " & intReturn
					
			Else 'No Error
				Set colMonitoredProcesses = objWMIService.ExecNotificationQuery _
					("Select * From __InstanceDeletionEvent Within 1 Where TargetInstance ISA 'Win32_Process'")

				'Wait for completion
				Do Until i = 1
					Set objLatestProcess = colMonitoredProcesses.NextEvent
					If objLatestProcess.TargetInstance.ProcessID = intProcessID Then
						i = 1
					End If
				Loop
				
				'Move back results
				retrieveFile = strUNCPath & "\" & strDate & "_.txt"
				
				If Not oFSO.FolderExists(LogDirectory) Then
					oFSO.CreateFolder(LogDirectory)
				End If
				
				Do  
					WScript.Sleep 100
				Loop Until oFSO.FileExists(retrieveFile)
			
				For Each Folder in oFolders
					ReturnValue = SetAuditing(Folder)
					Wscript.Echo ReturnValue
				Next
				
				'If oFSO.FileExists(retrieveFile) Then
					oFSO.CopyFile retrieveFile, LogDirectory & "\" & strDate & "_" & strComputer & ".txt"
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


			'myExecute = "net use " & strUNCPath & " /delete /y"
			myExecute = "net use " & DriveLetter & " /delete /y"
			Set oExec = WshShell.Exec(myExecute)

			Do While oExec.Status = 0
				WScript.Sleep 100
			Loop
			
			Set objWMIService = Nothing		
		End If
	End If
Loop

'*************************************************************************** 
' SUB ROUTINES
'***************************************************************************

Function SetAuditing(strFolder)
	' Get the file security 
	' object for the GSIRO-Scripts directory 
	Set wmiFileSecSetting = objWMIService.GetObject ( _ 
		"winmgmts:{impersonationLevel=impersonate,(Security)}!Win32_LogicalFileSecuritySetting." & _ 
		"path='" & strFolder & "'") 
					
	' Obtain existing security descriptor for folder 
	RetVal = wmiFileSecSetting.GetSecurityDescriptor(wmiSecurityDescriptor) 
	If Err <> 0 Then 
		WScript.Echo "GetSecurityDescriptor failed for " & oFolder & VbCrLf & _
		 	Err.Number & VbCrLf & _
		 	Err.Description 
		Err.Clear
	End If 


	Dim oACE, oTrustee 
	set oACE = objWMIService.GetObject("winmgmts:{impersonationLevel=impersonate,(Security)}!Win32_ACE") 
	set oTrustee = objWMIService.GetObject("winmgmts:{impersonationLevel=impersonate,(Security)}!Win32_Trustee") 

	'Set Trustee Attributes 
	oTrustee.Name="Everyone" 
	
	' Set ACE Attributes 
	oACE.Trustee=oTrustee 
	oACE.AccessMask=983551 
	oACE.AceType=2 
	oACE.AceFlags=128 

	'Add ACE to Security Descriptor 
	if isarray(wmiSecurityDescriptor.SACL) then 
		wmiSecurityDescriptor.SACL(UBound(wmiSecurityDescriptor.SACL)+1)=oAce 
	else 
		wmiSecurityDescriptor.SACL=Array(oAce) 
	end if 

	'Print out Aces for test 
	for each wmiAce in wmiSecurityDescriptor.SACL 
		Set Trustee = wmiAce.Trustee 
		wscript.echo "Trustee Domain: " & Trustee.Domain 
		wscript.echo "Trustee Name: " & Trustee.Name 
		wscript.echo "Access Type " & wmiAce.AceType 
		wscript.echo "Access Flags " & wmiAce.AceFlags 
		wscript.echo "Access Mask: " & wmiAce.AccessMask 
	next 

	' Call the Win32_LogicalFileSecuritySetting. 
	' SetSecurityDescriptor method 
	' to write the new security descriptor. 
	SetAuditing = wmiFileSecSetting.SetSecurityDescriptor(wmiSecurityDescriptor) 

End Function



Function CheckShare(strShareName, strDirectory)

	'Look for the specified share, create it if it doesn't exist.
	
	Set colShares = objWMIService.ExecQuery("SELECT * FROM Win32_Share WHERE path = '" &  strDirectory & "'")  'Look for an existing share in the target directory

	If colShares.Count > 0 Then
		For Each oShare In colShares
			ShareName = oShare.Name
		Next
	Else
		Set objNewShare = objWMIService.Get("Win32_Share")
		intResponse = objNewShare.Create(strDirectory, strShareName, FILE_SHARE, MAXIMUM_CONNECTIONS, "Temp share to grab set file.")
		ShareName = strShareName
		Set objNewShare = Nothing
	End If

	Set colShares = Nothing
	
	CheckShare = ShareName
End Function