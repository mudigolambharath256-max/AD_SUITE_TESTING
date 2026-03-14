@echo off
echo Starting AD Security Suite in Development Mode...
echo.

echo Starting backend server...
cd backend
start "AD Security Suite Backend" cmd /k "npm run dev"

echo.
echo Starting frontend dev server...
cd ../frontend
start "AD Security Suite Frontend" cmd /k "npm run dev"

echo.
echo AD Security Suite is starting in development mode...
echo Backend API: http://localhost:3001
echo Frontend Dev: http://localhost:5173
echo.
echo Both servers will start in separate windows.
echo Close this window or press any key to continue...
pause >nul
