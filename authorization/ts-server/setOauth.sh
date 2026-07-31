#!/bin/bash
# setOauth
# Use environment variable to update ".env" file with credentials.

# Variable for this folder
_curDir="$(cd "$(dirname "$0")" && pwd)"

if [ "$1" == "--set" ]; then
 sed -i "s/<_KEYCLOAK_SERVER_ID_>/$_KEYCLOAK_ID/" "$_curDir/.env"
 sed -i "s/<_KEYCLOAK_SERVER_SECRET_>/$_KEYCLOAK_SECRET/" "$_curDir/.env"
elif [ "$1" == "--secure" ]; then
 sed -i "s/$_KEYCLOAK_ID/<_KEYCLOAK_SERVER_ID_>/" "$_curDir/.env"
 sed -i "s/$_KEYCLOAK_SECRET/<_KEYCLOAK_SERVER_SECRET_>/" "$_curDir/.env"
fi
