'**************************************************************************
'
' For Windows Boxes
' Checks all accounts to determine what needs to be disabled.
' Gives you the option to disable or simply report on them.
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

' Flag to enable the disabling and moving of unused accounts
' True - Will Disable 
' False - Will create output log only
bDisable=False

' Number of days before an account is deemed inactive
' Accounts that haven't been logged in for this amount of days are selected
iLogonDays=90

' When creating the report output all accounts or just the inactive ones.
' Helpful if you want to do the analysis of the accounts afterwards interrogation.
' True - Only Inactive Accounts
' False - All Accounts
InactiveOnlyReport = True

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

'If the log file path does not exist, create it.
If Not oFSO.FolderExists(strLogPath) Then oFSO.CreateFolder(strLogPath)

'Setup for Log files to be written to.
Set output=oFSO.CreateTextFile(strLogPath & strOutputLog & "_" & sComputer & strExt)
Set errlog=oFSO.CreateTextFile(strLogPath & strErrorLog & "_" & sComputer & strExt)

'Setup Headers in the Log Files
output.WriteLine "Account Name" & vbTab & "Last Logon Date" & vbTab & "Number of Days"
errlog.WriteLine "Account Name" & vbTab & "Problem" & vbTab & "Error"

'Open an object to look at the specified computer
Set IADsCont = GetObject("WinNT://" & sComputer)

'For what ever reason services, groups and users are all considered Groups.  
'We are only interested in users.
For Each Group in IADsCont
	If group.Class = "User" Then
		Do_Check(Group)
	End If
Next

'Clean up
Set IADsCont = Nothing
output.Close
errlog.close
Set oFSO = Nothing

'***************************************************************************
' END MAIN CODE
'***************************************************************************

'***************************************************************************
' BEGIN SUBROUTINES
'***************************************************************************

Sub Do_Check(sUser)
	On Error Resume Next
	LastLogin = Null
    
	sConnectString = "WinNT://" & sComputer & "/" & sUser.name & ",user"
	Set oUser = GetObject(sConnectString)
	
	LastLogin = CDate(oUser.LastLogin)
	If IsNull(LastLogin) Then
		LastLogin = CDate("01/01/1970 00:00:00")
	End If
	
	'If the previous throws an error, that means the account has NEVER been logged into.
	If Err.Number <> 0 Then
		DisableAccount oUser, "Never"
	Else

		'Report on every user or just the inactive ones - flagged on line 31
		If InactiveOnlyReport <> True Then
			WriteReport oUser.Name, LastLogin
		Else
			'Disable the account if it does not meet the criteria 
			'Or Write to report is disablement is not selected.
			If DateDiff("d", LastLogin, Now) > iLogonDays Then
				DisableAccount oUser, LastLogin
			End If
		End If
	
	End If
	
End Sub

'***************************************************************************
' MAIN CODE ENDS
'***************************************************************************


'***************************************************************************
' SUBROUTINES
'***************************************************************************

Sub CreateFolder( strPath )
 
    If Not oFSO.FolderExists( oFSO.GetParentFolderName(strPath) ) Then
	CreateFolder( oFSO.GetParentFolderName(strPath) )
 	oFSO.CreateFolder( strPath ) 
    End If 
End Sub 
 
Sub DisableAccount( objUser, lastLogon )

    On Error Resume Next
    If bDisable = True Then
        If objUser.accountdisabled = False Then
			objUser.accountdisabled = True
			objUser.SetInfo

			WriteError objUser, "Disable Account Failed"
		Else
			Err.Raise 1,,"Account already disabled."
			WriteError objUser, "Disable Account Failed"

		End If
    End If
	WriteReport objUser.Name, lastLogon
End Sub



Sub WriteReport(Username, LastLogonDate)
	Wscript.Echo Username & vbtab & LastLogonDate & vbtab & DateDiff("d", LastLogonDate, Now)
    output.WriteLine Username & vbTab & LastLogonDate & vbtab & DateDiff("d", LastLogonDate, Now)
End Sub



Sub WriteError( objUser, strProblem )

    If Err.Number <> 0 Then
        errlog.WriteLine objUser.Name & vbTab & strProblem & vbTab & Replace(Err.Description,vbCrlf," ")
        Err.Clear
    End If

End Sub


'*************************************************************************** 
' END SUBROUTINES
'***************************************************************************
