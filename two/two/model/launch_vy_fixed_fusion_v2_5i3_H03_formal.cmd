@echo off
setlocal
cd /d "%~dp0"
set "H03_STDOUT=%~dp0..\results\vy_fixed_fusion_v2_5i3_H03_stdout.txt"
set "H03_STDERR=%~dp0..\results\vy_fixed_fusion_v2_5i3_H03_stderr.txt"
set "H03_EXITCODE=%~dp0..\results\vy_fixed_fusion_v2_5i3_H03_exitcode.txt"
set "H03_STATUS=%~dp0..\results\vy_fixed_fusion_v2_5i3_H03_launcher_status.txt"
if exist "%H03_STDOUT%" exit /b 91
if exist "%H03_STDERR%" exit /b 92
if exist "%H03_EXITCODE%" exit /b 93
if exist "%H03_STATUS%" exit /b 94
"D:\matlab\bin\matlab.exe" -batch "run('D:\UsersData\桌面\two\model\run_vy_fixed_fusion_v2_5i3_H03_formal_bootstrap.m')" 1>"%H03_STDOUT%" 2>"%H03_STDERR%"
set "H03_RC=%ERRORLEVEL%"
>"%H03_EXITCODE%" echo %H03_RC%
>"%H03_STATUS%" echo FORMAL_LAUNCH_COMPLETED,exit_code=%H03_RC%
exit /b %H03_RC%
