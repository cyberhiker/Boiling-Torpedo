@echo off

:: Setup a log file
Set LogFile=C:\%Date:~-4,4%-%Date:~-10,2%-%Date:~-7,2%_NetStat.txt
Set outFile=C:\%Date:~-4,4%-%Date:~-10,2%-%Date:~-7,2%_OpenPorts.txt

:: Delete Existing Files
del /q C:\*_%COMPUTERNAME%_OpenPorts.txt
del /q C:\*_%COMPUTERNAME%_NetStat.txt

:: Perform Action for TCP
netstat -anb -p tcp >> %LogFile%

:: Perform action for UDP
netstat -anb -p udp >> %LogFile%

setlocal EnableDelayedExpansion
for %%f in (%LogFile%) do (
    for /f "usebackq eol= delims=] tokens=1*" %%l in (`find /n /v "" "%%f"`) do (
        set line=%%m
        if !printnext!==1 (
            echo.%%m >> %outFile%
            set printnext=0
        ) else (
            if not [!line!]==[] if not !line!==!line:LISTEN=X! (
                <nul set /p ".=%COMPUTERNAME% %%m" >> %outFile%
                set printnext=1
            ) else (
                set printnext=0
            )
        )
    )
)

del /q C:\*_NetStat.txt