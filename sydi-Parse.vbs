Set oFSO = CreateObject("Scripting.FileSystemObject")
Set oConn = CreateObject("ADODB.Connection")
RunningDir = oFSO.GetFile(Wscript.ScriptFullName).ParentFolder

strConn = "DRIVER={SQLite3 ODBC Driver};Database=" & RunningDir & "\BaseConfig.s3db;"
'"LongNames=0;Timeout=1000;NoTXN=0;SyncPragma=NORMAL;StepAPI=0;"
oConn.Open(strConn)

ReplaceDate = Replace(FormatDateTime(Now(),2), "/", "-")

BaseDirectory = InputBox("Enter path to files to be processed.  " & _
	"This script is designed to process multiple files, " & _
	"so if you have only one file place it in a directory by itself", _
	"Directory Path", RunningDir)

If BaseDirectory = "" Then
	BaseDirectory = RunningDir
End If

Set TheDirectory = oFSO.GetFolder(BaseDirectory)
Set oFiles = TheDirectory.Files

'Initialize a Blank Database
TableSQL = "CREATE TABLE if not exists [Targets] ('TargetID' INTEGER PRIMARY KEY AUTOINCREMENT, " & _
			"'IPAddress' text, 'Hostname' text, 'OS' text, 'SerialNumber' text, 'Environment' text)"
oConn.Execute(TableSQL)

TableSQL = "CREATE TABLE if not exists [Platforms] ('PlatformID' INTEGER PRIMARY KEY AUTOINCREMENT, " & _
			"'SoftwareName' text, 'Vendor' text, 'Version' text)"
oConn.Execute(TableSQL)

TableSQL = "CREATE TABLE if not exists [CrossReference] ('RefID' INTEGER PRIMARY KEY AUTOINCREMENT, " & _
			"'TargetID' int, 'PlatformID' int)"
oConn.Execute(TableSQL)

' Create a helpful view to display the list of all software installed on all machines.
'ViewSQL = "CREATE VIEW if not exists [Combined] (SELECT )"
'oConn.Execute(ViewSQL)

i = 0
For Each File In oFiles
	If Lcase(Right(File.Name, 3)) = "xml" Then
		Set objXMLDoc = CreateObject("Microsoft.XMLDOM")
		objXMLDoc.async = False
		FileName = BaseDirectory & "\" & File.Name
		objXMLDoc.load(FileName)

		IPAddress = Left(File.Name, Len(File.Name)-4)

		Wscript.Echo "Processing " & IPAddress

		Set root = objXMLDoc.documentElement
		Set SystemNode = root.SelectSingleNode("/computer/system")
		ComputerName = SystemNode.getAttribute("name")
		Wscript.Echo "Computer Name: " & ComputerName

		Set OSNode = root.SelectSingleNode("/computer/operatingsystem")
		OS = OSNode.getAttribute("name")
		Wscript.Echo "OS: " & OS

		ComputerSQL = "SELECT TargetID FROM [Targets] WHERE [IPAddress] = '" & IPAddress & "'"
		Set TargetRS = oConn.Execute(ComputerSQL)

		If TargetRS.eof Then
			Wscript.echo "Target Doesn't Exist, Create it"

			InsertTargetSQL = "INSERT INTO Targets ([IPAddress], [Hostname], [OS]) " & _
				"VALUES ('" & IPAddress & "','" & ComputerName & "','" & OS & "')"
			oConn.Execute(InsertTargetSQL)
			
			Set TargetRS = oConn.Execute(ComputerSQL)
		End If
		
		TargetID = TargetRS(0)
		
		Set InstallationNode = root.SelectSingleNode("/computer/installedapplications")
		Set AppNodeList = InstallationNode.ChildNodes

		For i = 0 to AppNodeList.length -1
			PlatformID = 0
			
			SoftwareName = AppNodeList.item(i).getAttribute("productname")
			Vendor = AppNodeList.item(i).getAttribute("vendor")
			Version = AppNodeList.item(i).getAttribute("version")

			SoftwareSQL = "SELECT PlatformID FROM [Platforms] WHERE [SoftwareName] = '" & SoftwareName & "'"
			SoftwareSQL = SoftwareSQL & " AND [Version] = '" & Version & "'"
			
			If Vendor <> "" Then
				SoftwareSQL = SoftwareSQL & " AND [Vendor] = '" & Vendor & "'"
			End If
			
			Set SoftwareRS = oConn.Execute(SoftwareSQL)
			
			If SoftwareRS.Eof Then

				If Vendor <> "" Then
					InsertSQL = "INSERT INTO Platforms ([SoftwareName], [Version], [Vendor]) " & _
						"VALUES ('" & SoftwareName & "','" & Version & "','" & Vendor & "')"
				Else
					InsertSQL = "INSERT INTO Platforms ([SoftwareName], [Version]) " & _
						"VALUES ('" & SoftwareName & "','" & Version & "')"
				End If	
				
				InsertSQL = InsertSQL 

				'Do the Insert
				Set InsertRS = oConn.Execute(InsertSQL)

				'Look for the new value
				Set SoftwareRS = oConn.Execute(SoftwareSQL)
			End If
			
			PlatformID = SoftwareRS(0)
			
			xRefChkSQL = "SELECT RefID FROM [CrossReference] WHERE [PlatformID] = " & PlatformID & " AND [TargetID] = " & TargetID
			Set xRefRS = oConn.Execute(xRefChkSQL)
			
			If xRefRS.Eof Then
				SQL = "INSERT INTO CrossReference (PlatformID, TargetID) VALUES (" & PlatformID & "," & TargetID & ")"
				oConn.Execute(SQL)
			End If

		Next

		Set AppNodeList = Nothing
		Set root = Nothing
	End If

	i = i + 1
Next

Set oFSO = Nothing

Function DoReplace(ThisText)
	MyText = Replace(ThisText, "<br/>", vblf)
	MyText = Replace(MyText, Chr(10), " ")
	MyText = Replace(MyText, Chr(13), " ")
	MyText = Replace(MyText, "\n", vblf)
	MyText = Replace(MyText, "<p>", vblf)
	MyText = Replace(MyText, "</p>", vblf)
	MyText = Replace(MyText, "<b>", "")
	MyText = Replace(MyText, "</b>", "")
	MyText = Replace(MyText, "<i>", "")
	MyText = Replace(MyText, "</i>", "")

	DoReplace = MyText
End Function
