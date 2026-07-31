@echo off 
rem setOauth
::  Use environment variable to update ".env" file with credentials.

if "%1"=="--set" (
 sed -i "s/<_KEYCLOAK_SERVER_ID_>/%_KEYCLOAK_ID%/" .env
 sed -i "s/<_KEYCLOAK_SERVER_SECRET_>/%_KEYCLOAK_SECRET%/" .env
) else if "%1"=="--secure" (
 sed -i "s/%_KEYCLOAK_ID%/<_KEYCLOAK_SERVER_ID_>/" .env
 sed -i "s/%_KEYCLOAK_SECRET%/<_KEYCLOAK_SERVER_SECRET_>/" .env
)
