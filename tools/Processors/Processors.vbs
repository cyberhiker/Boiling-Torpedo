'**************************************************************************
'
' For Windows Boxes
' Checks processor count and speeds on local server.
' 
' You can send it a /s:<servername> if you wanted to do a remote server.
' Simply do a net use first to the remote server.
'
' You may also use the associated cmd and csv to do multiple servers.
'
'***************************************************************************

'Format date for log file.
'Const strDate = Year(Now()) & "-" & Right("0" & Month(Now()), 2) & "-" & Right("0" & Day(Now()), 2)

'*************************************************************************** 
' BEGIN USER VARIABLES
'***************************************************************************

'

' Log file path (include trailing \ ) 
' Use either full directory path or relational to script directory 
strLogPath="C:\StaleAccountsLog\" & strDate & "\"

' Error log file name prefix (tab delimited text file).
strErrorLog="ErrDisabledAccounts_"

' Output log file name prefix (tab delimited text file).
strOutputLog="DisabledAccounts_"

' Log file extension
strExt=".tsv"

'*************************************************************************** 
' END USER VARIABLES 
'***************************************************************************

'***************************************************************************
' BEGIN MAIN CODE
'***************************************************************************

Set colNamedArguments = WScript.Arguments.Named
sComputer = colNamedArguments.Item("s")
inputFileName = colNamedArguments.Item("i")

'If a remote computer is not specified, look at local. 
If sComputer = "" Then
	Set wshShell = WScript.CreateObject("WScript.Shell")
	sComputer = wshShell.ExpandEnvironmentStrings( "%COMPUTERNAME%" )
End If

Set oFSO=CreateObject("Scripting.FileSystemObject")
'If the log file path does not exist, create it.
If Not oFSO.FolderExists(strLogPath) Then oFSO.CreateFolder(strLogPath)

'Setup for Log files to be written to.
Set output=oFSO.CreateTextFile(strLogPath & strOutputLog & "_" & sComputer & strExt)
Set errlog=oFSO.CreateTextFile(strLogPath & strErrorLog & "_" & sComputer & strExt)

If inputFileName = "" Then
	
	Set objWMIService = GetObject("winmgmts:\\" & sComputer & "\root\cimv2")
	DoThing(objWMIService)
	Set objWMIService = Nothing
	
Else
	If oFSO.FileExists(inputFileName) Then
		Set input=oFSO.OpenTextFile(inputFileName)
		
		Do While Not input.AtEndofStream
			ThisLine = Split(input.ReadLine, ",")
			If Not Left(ThisLine(0), 1) = "#" Then
				strComputer = ThisLine(1)
				strUsername = ThisLine(4) & "\" & Thisline(2)
				strPassword = ThisLine(3)
				
				Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")
				On Error Resume Next
				Wscript.Echo "Attempting to connect to " & strComputer
				
				Set objWMIService = objSWbemLocator.ConnectServer(strComputer,"root\cimv2",strUserName,strPassword)
				If Err.Number > 0 Then
					Wscript.Echo "Couldn't connect to " & strComputer
					Err.Clear
				End If
				DoThing(objWMIService)
				Set objWMIService = Nothing
				Set objSWBemLocator = Nothing
			End IF
		Loop
		
		Set input = Nothing
	Else
		Wscript.Echo "Input File Name Not Valid"
	End If
End If

Set output = Nothing
Set errlog = Nothing

Sub DoThing(oWMIService)
	
	'Interrogate Processors
	Set colItems = oWMIService.ExecQuery("Select Description, ExtClock, L2CacheSize, " &_
		"Name, MaxClockSpeed, SocketDesignation from Win32_Processor",,48)

	i = 0
	For Each objItem in colItems
		i = i + 1
		Wscript.Echo "Name:				" & objItem.Name
		Wscript.Echo "L2CacheSize:		" & objItem.L2CacheSize
		Wscript.Echo "Description: 		" & objItem.Description
		Wscript.Echo "Max Clock Speed:	" & objItem.MaxClockSpeed
		Wscript.Echo ""
	Next
	
	Err.Clear

	Set colItems = oWMIService.ExecQuery("Select BankLabel, Capacity, FormFactor, MemoryType from Win32_PhysicalMemory",,48)

	TotalRam = 0
	For Each objItem In colItems
		'Wscript.Echo "Bank Label	" & objItem.BankLabel
		'Wscript.Echo "Capacity		" & objItem.Capacity
		'Wscript.Echo "FormFactor	" & objItem.FormFactor
		'Wscript.Echo "MemoryType	" & objItem.MemoryType
		TotalRam = TotalRam + objItem.Capacity
	Next

	Wscript.Echo "RAM Size:		" & ReturnBytes2Gigabytes(TotalRam) & " GB"
	Set oWMIService = Nothing
	
End Sub
'***************************************************************************
' END MAIN CODE
'***************************************************************************

'***************************************************************************
' BEGIN SUBROUTINES
'***************************************************************************

Function Scrub(strInput)
	If (IsNull(strInput)) Then
		strInput = ""
	End If
	Scrub = strInput
End Function ' Scrub

Function ReturnBytes2Gigabytes(nBytes)
	Dim nGigabytes
	If (IsNumeric(nBytes)) Then
		nGigabytes = nbytes / (1024 * 1024 * 1024)
	Else
		nGigabytes = 0
	End If
	ReturnBytes2Gigabytes = nGigabytes
End Function ' ReturnBytes2Gigabytes

'***************************************************************************
' END SUBROUTINES
'***************************************************************************
