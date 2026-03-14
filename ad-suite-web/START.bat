@echo off
title AD Security Suite
echo Starting AD Security Suite...
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install\Start-ADSuite.ps1"
pause
