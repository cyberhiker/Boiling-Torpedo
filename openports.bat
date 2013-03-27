@echo off
:: Delete Existing File
del /q C:\*%COMPUTERNAME%_OpenPorts.txt

:: Setup a log file
Set LogFile=C:\%Date:~-4,4%-%Date:~-10,2%-%Date:~-7,2%_%COMPUTERNAME%_OpenPorts.txt
echo <Ports>
:: Perform Action for TCP
for /f "tokens=2" %%i in ('netstat -an -p tcp ^| findstr LIST') do (
        for /f "delims=: tokens=2" %%p in ("%%i") do (
                echo UDP	%%p >>%LogFile%
        )
)

:: Perform action for UDP
for /f "tokens=2" %%i in ('netstat -an -p udp') do (
        for /f "delims=: tokens=2" %%p in ("%%i") do (
                echo UDP	%%p >>%LogFile%
        )
)

setlocal disableDelayedExpansion
set searchFiles=%LogFile%
set outFile="ListOfWARNINGS"
set tempFile="%temp%\warnings%random%.txt"
set tempFile2="%temp%\warnings2_%random%.txt"
(
  for /f "tokens=1,2 delims=:" %%A in ('findstr /m WARNING %searchFiles% nul') do (
    findstr /n "^" "%%A" nul >%tempFile%
    echo(>>%tempFile%
    set "file=%%A"
    set "next=0"
    setlocal enableDelayedExpansion
    findstr /n WARNING "!file!" >%tempFile2%
    for /f "usebackq delims=:" %%N in (%tempFile2%) do (
      if %%N==!next! (set "current=") else set current=/c:"!file!:%%N:"
      set /a "next=%%N+1"
      findstr /bi !current! /c:"!file!:!next!:" %tempFile%
    )
    endlocal
  )
)>%outFile%
del %tempFile% 2>nul
del %tempFile2% 2>nul