rem Generate Losty Lua file
@echo off
set SRC=losty\
set DST=\_

rem ~pnx = path name ext
rem   See https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb490909(v=technet.10)
for /R %SRC% %%V in (*.lt) do echo %SRC%%%~pnx
rem C:\app\lua\luajit.exe -e "package.path=package.path .. '\\luaty\\?.lua'" \luaty\lt.lua -f -t -d ngx "%SRC%%%~nx" %DST%
rem for /R %DST%\%SRC% %%V in (*.lua) do C:\app\lua\luajit.exe -b "%%V" "%%V"
rem copy stops_en.txt %DST%\%SRC% /y


\app\mingw64\bin\mingw32-make.exe SHELL=cmd