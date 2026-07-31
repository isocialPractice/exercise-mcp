@echo off 
rem setOauth
::  Use environment variable to update ".env" file with credentials.

if "%1"=="--set" (
 sed -i "s/<_KEYCLOAK_SERVER_ID_>/%_KEYCLOAK_ID%/" "%~dp0.env"
 sed -i "s/<_KEYCLOAK_SERVER_SECRET_>/%_KEYCLOAK_SECRET%/" "%~dp0.env"
) else if "%1"=="--secure" (
 sed -i "s/%_KEYCLOAK_ID%/<_KEYCLOAK_SERVER_ID_>/" "%~dp0.env"
 sed -i "s/%_KEYCLOAK_SECRET%/<_KEYCLOAK_SERVER_SECRET_>/" "%~dp0.env"
)
