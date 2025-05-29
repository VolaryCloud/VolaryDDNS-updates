@echo off
REM VolaryDDNS Update Script for Windows - Version 2025.5.29
REM Maintainer: Phillip Rødseth <phillip@vtolvr.tech>
REM
REM Description:
REM   This script updates a DNS record via the VolaryDDNS API when your public IP changes.
REM   Designed for use with systems on dynamic IPs behind NAT or residential connections.
REM
REM Usage:
REM   Schedule with Windows Task Scheduler to run periodically.
REM   Run as: volary_ddns_update_{subdomain.name}.bat
REM
REM For subdomain: DDNS-{subdomain.name}.{CF_DOMAIN}

setlocal EnableDelayedExpansion

REM Configuration
set TOKEN={subdomain.token}
set API_URL={base_url}/api/update
set LOG_FILE=C:\temp\volary_ddns_update.log
set LAST_IP_FILE=C:\temp\volary_ddns_last_ip.txt
set TEMP_FILE=C:\temp\volary_ip_response.txt

REM Create temp directory if it doesn't exist
if not exist C:\temp mkdir C:\temp

echo [%date% %time%] Starting VolaryDDNS update process >> "%LOG_FILE%"
echo VolaryDDNS Update Script - Starting...

REM IP retrieval using PowerShell
echo [%date% %time%] Retrieving IP address >> "%LOG_FILE%"
echo Retrieving your public IP address...

REM Use PowerShell to get IP and write directly to temp file
powershell -Command "try {{ Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 15 }} catch {{ 'FAILED' }}" > "%TEMP_FILE%"

REM Check if file was created and read IP
if not exist "%TEMP_FILE%" (
    echo [%date% %time%] ERROR: Could not create temp file >> "%LOG_FILE%"
    echo ERROR: Could not create temp file
    goto :ERROR_EXIT
)

set /p CURRENT_IP=<"%TEMP_FILE%"
del "%TEMP_FILE%" >nul 2>nul

if "%CURRENT_IP%"=="FAILED" (
    echo [%date% %time%] ERROR: Failed to retrieve IP address >> "%LOG_FILE%"
    echo ERROR: Failed to retrieve IP address
    goto :ERROR_EXIT
)

if "%CURRENT_IP%"=="" (
    echo [%date% %time%] ERROR: Empty IP address received >> "%LOG_FILE%"
    echo ERROR: Empty IP address received  
    goto :ERROR_EXIT
)

echo [%date% %time%] Current IP: %CURRENT_IP% >> "%LOG_FILE%"
echo Current IP address: %CURRENT_IP%

REM Check if IP has changed
set UPDATE_NEEDED=1
if exist "%LAST_IP_FILE%" (
    set /p LAST_IP=<"%LAST_IP_FILE%"
    echo [%date% %time%] Previous IP was: %LAST_IP% >> "%LOG_FILE%"
    echo Previous IP was: %LAST_IP%
    if "%LAST_IP%"=="%CURRENT_IP%" (
        echo [%date% %time%] IP unchanged (%CURRENT_IP%), skipping DNS update >> "%LOG_FILE%"
        echo IP address unchanged (%CURRENT_IP%), skipping DNS update
        echo No update needed - exiting successfully
        goto :SUCCESS_EXIT_NO_UPDATE
echo [%date% %time%] Script completed - no update needed >> "%LOG_FILE%"
echo.
echo Script completed - no DNS update needed
echo Current IP (%CURRENT_IP%) matches previous IP
echo Log file: %LOG_FILE%
echo.
if "%1"=="" (
    echo Press any key to exit...
    pause >nul
)
exit /b 0

:SUCCESS_EXIT_NO_UPDATE
    ) else (
        echo [%date% %time%] IP changed from %LAST_IP% to %CURRENT_IP% >> "%LOG_FILE%"
        echo IP changed from %LAST_IP% to %CURRENT_IP% - updating DNS
    )
) else (
    echo [%date% %time%] No previous IP file found, will update DNS >> "%LOG_FILE%"
    echo No previous IP record found - updating DNS
)

REM Update DNS record
echo [%date% %time%] Updating DNS record >> "%LOG_FILE%"
echo Updating DNS record...

REM Create JSON request
echo {{"token":"%TOKEN%","ip":"%CURRENT_IP%"}} > C:\temp\volary_request.json

REM Make API request
echo [%date% %time%] Making API request to %API_URL% >> "%LOG_FILE%"
powershell -Command "try {{ $body = Get-Content 'C:\temp\volary_request.json' -Raw; Invoke-RestMethod -Uri '%API_URL%' -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 30 }} catch {{ 'API_FAILED: ' + $_.Exception.Message }}" > C:\temp\volary_api_response.txt

REM Clean up request file
del C:\temp\volary_request.json >nul 2>nul

REM Check API response
if not exist C:\temp\volary_api_response.txt (
    echo [%date% %time%] ERROR: No API response file created >> "%LOG_FILE%"
    echo ERROR: No API response received
    goto :ERROR_EXIT
)

set /p API_RESPONSE=<C:\temp\volary_api_response.txt
del C:\temp\volary_api_response.txt >nul 2>nul

echo [%date% %time%] API Response: %API_RESPONSE% >> "%LOG_FILE%"
echo API Response: %API_RESPONSE%

REM Check for success (simple string search)
echo %API_RESPONSE% | find "API_FAILED:" >nul
if %ERRORLEVEL%==0 (
    echo [%date% %time%] ERROR: API request failed >> "%LOG_FILE%"
    echo ERROR: API request failed
    goto :ERROR_EXIT
)

REM If we get here, assume success and save the IP
echo %CURRENT_IP%> "%LAST_IP_FILE%"
echo [%date% %time%] SUCCESS: DNS updated to %CURRENT_IP% >> "%LOG_FILE%"
echo SUCCESS: DNS record updated to %CURRENT_IP%

:SUCCESS_EXIT
echo [%date% %time%] Script completed successfully >> "%LOG_FILE%"
echo.
echo Script completed successfully
echo Log file: %LOG_FILE%
echo.
if "%1"=="" (
    echo Press any key to exit...
    pause >nul
)
exit /b 0

:ERROR_EXIT
echo [%date% %time%] Script completed with errors >> "%LOG_FILE%"
echo.
echo Script completed with errors  
echo Check log file: %LOG_FILE%
echo.
echo Press any key to exit...
pause >nul
exit /b 1
