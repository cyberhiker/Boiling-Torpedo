@echo off

:: Setup a log file
Set outFile=C:\%Date:~-4,4%-%Date:~-10,2%-%Date:~-7,2%_%COMPUTERNAME%_SetAuditing.log
Set SourceDirectory=C:\GSIRO-Scripts
Set LogDirectory=C:\GSIRO-Scripts\Logs

:: Delete Existing Files
del /q C:\*_SetAuditing.log

:: Set Success Auditing
Auditpol /set /subcategory:"Detailed File Share" /success:enable /failure:enable
Auditpol /set /subcategory:"File System" /success:enable /failure:enable

::Note: to get event id 4656 you can also enable Handle Manipulation setting 
Auditpol /set /subcategory:"Handle Manipulation" /success:enable