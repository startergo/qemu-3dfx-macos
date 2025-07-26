@echo off
REM QEMU 3dfx Guest Inspection Script
REM Copy this to your Windows 95/98/XP guest to inspect 3dfx from inside

echo QEMU 3dfx Guest Renderer Inspection
echo ====================================

echo.
echo 1. Checking 3dfx Driver Status:
echo ==============================
if exist "C:\WINDOWS\SYSTEM\GLIDE2X.DLL" (
    echo [OK] Glide 2x driver found
) else (
    echo [WARN] Glide 2x driver not found
)

if exist "C:\WINDOWS\SYSTEM\GLIDE3X.DLL" (
    echo [OK] Glide 3x driver found  
) else (
    echo [WARN] Glide 3x driver not found
)

echo.
echo 2. DirectX/OpenGL Status:
echo =========================
dxdiag /t dxdiag_output.txt
echo DirectX info saved to dxdiag_output.txt

echo.
echo 3. Registry 3dfx Entries:
echo ========================
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\3dfx Interactive" /s 2>nul
if errorlevel 1 echo No 3dfx registry entries found

echo.
echo 4. PCI Device Detection:
echo =======================
REM This would show PCI devices including emulated Voodoo cards
echo Check Device Manager for:
echo - 3dfx Interactive Voodoo Graphics
echo - 3dfx Interactive Voodoo2 Graphics  
echo - Display adapters section

echo.
echo 5. Test Applications:
echo ====================
echo Recommended 3dfx test applications:
echo - 3dfx Demo (3dfxdemo.exe)
echo - Quake II with 3dfx support
echo - Unreal Tournament (1999) with Glide
echo - Need for Speed III: Hot Pursuit
echo - Tomb Raider (1996) with 3dfx patch

echo.
echo 6. Environment Variables:
echo ========================
echo GLIDE2X_DLL=%GLIDE2X_DLL%
echo GLIDE3X_DLL=%GLIDE3X_DLL%
echo SST_DRIVER=%SST_DRIVER%

echo.
echo 7. Memory Test (DOS):
echo ====================
echo In DOS mode, run:
echo   MEM /C /P
echo Look for 3dfx memory allocations

echo.
echo 8. Glide Test Commands:
echo ======================
echo Test Glide functionality with these commands:
echo   glidediag.exe    (if available)
echo   glidetest.exe    (3dfx test utility)
echo   test3dfx.exe     (basic 3dfx test)

echo.
echo 9. Performance Monitoring:
echo ==========================
echo Monitor performance with:
echo - Built-in FPS counters in games
echo - 3dfx Voodoo statistics
echo - Task Manager (Windows XP)

echo.
echo 10. Debug Information:
echo =====================
echo For debugging 3dfx issues:
echo - Check Windows Event Viewer
echo - Enable DirectX debug mode
echo - Use debug builds of Glide drivers
echo - Monitor system.ini for Glide settings

echo.
echo ========================================
echo 3dfx Guest Inspection Complete!
echo ========================================
pause
