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

'*************************************************************************** 
' BEGIN USER VARIABLES
'***************************************************************************

' Log file path (include trailing \ ) 
' Use either full directory path or relational to script directory 
strLogPath=""

' Output log file name prefix (tab delimited text file).
strOutputLog="ProcessorInfo"

' Log file extension
strExt=".csv"

'*************************************************************************** 
' END USER VARIABLES 
'***************************************************************************

'***************************************************************************
' BEGIN MAIN CODE
'***************************************************************************

Set colNamedArguments = WScript.Arguments.Named
sComputer = colNamedArguments.Item("s")
inputFileName = colNamedArguments.Item("i")

Dim aCPUs, iAllCPUs, iTrueCPUs 
Dim strCPUName, iClockSpeed, message 
aCPUs = Array() 

'If a remote computer is not specified, look at local. 
If sComputer = "" Then
	Set wshShell = WScript.CreateObject("WScript.Shell")
	sComputer = wshShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
End If

Set oFSO=CreateObject("Scripting.FileSystemObject")
'If the log file path does not exist, create it.
'If Not oFSO.FolderExists(strLogPath) Then oFSO.CreateFolder(strLogPath)

'Setup for Log files to be written to.
Set output=oFSO.CreateTextFile(strLogPath & strOutputLog & strExt)

Header = "IP Address,Processor Name,Architecture,Cores,Processors,Speed,RAM"
output.Writeline Header
wscript.echo Header

If inputFileName = "" Then
	
	Wscript.Echo "Attempting to interrogate " & sComputer
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
				
				Set objWMIService = objSWbemLocator.ConnectServer(strComputer,"root\cimv2",strUserName,strPassword)
				If Err <> 0 Then
					Output.WriteLine strComputer & ",Access Denied"
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


Sub DoThing(oWMI)
	
	Set colCPUs = oWMI.ExecQuery("SELECT Name, maxClockSpeed, SocketDesignation, Architecture FROM Win32_Processor where Status > 0") 
	iAllCPUs = 0 
	
	For Each oCPU In colCPUs 
		strCPUName = quote & trim(oCPU.name) & quote 
		iClockSpeed =  oCPU.maxClockSpeed 
		strArchitecture = funArch(oCPU.Architecture)
		iAllCPUs = iAllCPUs +1 
		AddToArray aCPUs, oCPU.SocketDesignation 
	Next 
	
	iTrueCPUs = UBound(aCPUs) + 1 
	
	Dim strS, strClockSpeed 
	
	If iTrueCPUs  > 1  Then strS = "s" 
	
	If Len(iClockSpeed) > 3 Then 
		iClockSpeed =  round((iClockSpeed/1000),2) 'switch to Ghz. 
		strClockSpeed = iClockSpeed & " Ghz" 
	Else 
		strClockSpeed = iClockSpeed & " Mhz" 
	End If
	
	Set colItems = oWMI.ExecQuery("Select BankLabel, Capacity, FormFactor, MemoryType from Win32_PhysicalMemory",,48)

	TotalRam = 0
	For Each objItem In colItems
		'Wscript.Echo "Bank Label	" & objItem.BankLabel
		'Wscript.Echo "Capacity		" & objItem.Capacity
		'Wscript.Echo "FormFactor	" & objItem.FormFactor
		'Wscript.Echo "MemoryType	" & objItem.MemoryType
		TotalRam = TotalRam + objItem.Capacity
	Next

	strRam = ReturnBytes2Gigabytes(TotalRam) & " GB"
	Wscript.Echo "RAM Size:		" & ReturnBytes2Gigabytes(TotalRam) & " GB"
	
	'"IP,Processor Name,Architecture,Processors,Cores,Speed,RAM"
	outLine = strComputer & "," & strCPUName & "," & strArchitecture & "," & iAllCPUs & "," & iTrueCPUs & "," & strClockSpeed & "," & strRam
	output.Writeline outLine
	
	Wscript.Echo outLine
	
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

Function funArch(intIN)
	Select Case intIN
		Case 0
			funArch = "x86"
		Case 1
			funArch = "MIPS"
		Case 2
			funArch = "Alpha"
		Case 3
			funArch = "PowerPC"
		Case 6
			funArch = "Intel Itanium Processor Family (IPF)"
		Case 9
			funArch = "x64"
		Case Else
			funArch = "Unable to determine processor type"
	End Select
End Function

Sub AddToArray(aList, NewItem) 'check for new items 
 Dim ItemFound 
 For i = LBound(aList) to UBound(aList) 
    If aList(i) = NewItem Then 
       ItemFound = True 
       Exit For 
    End If 
 Next 
  
 If Not ItemFound Then 
    ReDim Preserve aList(Ubound(aList) + 1) 
    alist(i)=newitem 
       WScript.Echo "Added " & Newitem & " to array"
 End If 
End Sub 

'***************************************************************************
' END SUBROUTINES
'***************************************************************************
