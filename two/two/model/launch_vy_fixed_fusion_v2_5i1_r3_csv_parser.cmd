@echo off
setlocal
cd /d "D:\UsersData\桌面\two\model"
"D:\matlab\bin\matlab.exe" -batch "probe_vy_fixed_fusion_v2_5i1_r3_csv_parser" > "D:\UsersData\桌面\two\results\vy_fixed_fusion_v2_5i1_r3_launcher_stdout.txt" 2> "D:\UsersData\桌面\two\results\vy_fixed_fusion_v2_5i1_r3_launcher_stderr.txt"
set EC=%ERRORLEVEL%
> "D:\UsersData\桌面\two\results\vy_fixed_fusion_v2_5i1_r3_launcher_exitcode.txt" echo %EC%
exit /b %EC%
