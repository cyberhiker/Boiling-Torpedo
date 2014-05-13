@echo off

rem Read theFile.csv and get 4 tokens separated by commas
rem %1 is a command line arguments, send the csv file name.
rem 

for /F "tokens=1-4 delims=," %%a in (%1) do (
	rem Tokens read are placed in %%a, %%b, %%c and %%d replaceable parameters
	
	net use \\%%a\ipc$ /persistent:no /user:%%d\%%b %%c
	
	cscript //nologo StaleAccounts.vbs /s:%%a
	
	net use \\%%a\ipc$ /delete /y

)