rem Generate Losty Lua file
@echo off
set SRC=\losty
set DST=\_

rem ~pnx = path name ext
rem   See https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb490909(v=technet.10)
for /R %SRC% %%V in (*.lt) do C:\app\lua\luajit.exe -e "package.path=package.path .. '\\luaty\\?.lua'" \luaty\lt.lua -t -d ngx -f1 "%%~pnxV" %DST%
for /R %DST%%SRC% %%V in (*.lua) do C:\app\lua\luajit.exe -b "%%V" "%%V"
copy stops_en.txt %DST%%SRC% /y