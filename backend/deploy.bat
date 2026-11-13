@echo off
title VibeKit AI Production Deployment
echo ==========================================================
echo   VibeKit AI - Cloudflare Workers Production Deployment
echo ==========================================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0deploy.ps1"
pause
