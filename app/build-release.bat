@echo off
title VibeKit AI Release Builder
echo ==========================================================
echo   VibeKit AI - Release Builder (APK and Google Play AAB)
echo ==========================================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0build-release.ps1" %*
pause
