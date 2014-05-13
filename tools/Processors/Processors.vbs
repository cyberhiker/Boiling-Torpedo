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
Const strDate = Year(Now()) & "-" & Right("0" & Month(Now()), 2) & "-" & Right("0" & Day(Now()), 2)

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

'If a remote computer is not specified, look at local. 
If sComputer = "" Then
	Set wshShell = WScript.CreateObject("WScript.Shell")
	sComputer = wshShell.ExpandEnvironmentStrings( "%COMPUTERNAME%" )
End If

Set oFSO=CreateObject("Scripting.FileSystemObject")
Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")

'If the log file path does not exist, create it.
If Not oFSO.FolderExists(strLogPath) Then oFSO.CreateFolder(strLogPath)

'Setup for Log files to be written to.
Set output=oFSO.CreateTextFile(strLogPath & strOutputLog & "_" & sComputer & strExt)
Set errlog=oFSO.CreateTextFile(strLogPath & strErrorLog & "_" & sComputer & strExt)

'Interrogate Processors
Set colItems = objWMIService.ExecQuery("Select Description, ExtClock, L2CacheSize, " &_
	"Name, MaxClockSpeed, SocketDesignation from Win32_Processor",,48)

i = 0
For Each objItem in colItems
	i = i + 1
	Wscript.Echo "L2CacheSize:		" & objItem.L2CacheSize
	Wscript.Echo "ExtClock:			" & objItem.ExtClock
	Wscript.Echo "Name:				" & objItem.Name
	Wscript.Echo "Description: 		" & objItem.Description
	Wscript.Echo "Max Clock Speed:	" & objItem.MaxClockSpeed
	
	strSocketDesignation = Replace(Scrub(objItem.SocketDesignation),"'","")
	
	objDbrProcessorSockets.Filter = " SocketDesignation='" & strSocketDesignation & "'"
	
	j = 1
	If Not (objDbrProcessorSockets.Bof) Then
		j = j + 1
	End If
	
 	Wscript.Echo "SocketDesignation:	" & strSocketDesignation
	Wscript.Echo "Count:				" & j
	
Next

Err.Clear

Set colItems = objWMIService.ExecQuery("Select BankLabel, Capacity, FormFactor, MemoryType from Win32_PhysicalMemory",,48)

For Each objItem In colItems
	Wscript.Echo "Bank Label	" & objItem.BankLabel
	Wscript.Echo "Capacity		" & objItem.Capacity
	Wscript.Echo "FormFactor	" & objItem.FormFactor
	Wscript.Echo "MemoryType	" & objItem.MemoryType
Next

Set objWMIService = Nothing

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

'***************************************************************************
' END SUBROUTINES
'***************************************************************************
