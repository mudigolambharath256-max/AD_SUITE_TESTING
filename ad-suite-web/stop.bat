@echo off
title AD Security Suite - Stop
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install\Stop-ADSuite.ps1"
pause
