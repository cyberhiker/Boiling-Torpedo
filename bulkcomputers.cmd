@echo off

rem Read theFile.csv and get 4 tokens separated by commas
rem %1 is a command line arguments, send the csv file name.

for /F "tokens=1-4 delims=," %%a in (%1) do (
	rem Tokens read are placed in %%a, %%b, %%c and %%d replaceable parameters
	
	cscript //nologo sydi-server.vbs -t%%a -u%%d\%%b -p%%c -o%%a.xml -ex 
)