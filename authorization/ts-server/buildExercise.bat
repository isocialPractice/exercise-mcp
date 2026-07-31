@echo off 
rem buildExercise
::  Script for exercise, making a simple MCP server as hard as possible for learning purposes.

:; Global variables.
set "_parOneBuildExercise=%~1"
set "_checkParOneBuildExercise=-%_parOneBuildExercise%-"

cd /D "%~dp0"
call :_runBuildExercise 0
goto:eof

:_package
 if "%1"=="1" (
  echo {
  echo {> "%~dp0package.json"
  echo  "name": "authorization-ts-server",
  echo  "name": "authorization-ts-server",>> "%~dp0package.json"
  echo  "version": "0.0.0-alpha",
  echo  "version": "0.0.0-alpha",>> "%~dp0package.json"
  echo  "type": "module",
  echo  "type": "module",>> "%~dp0package.json"
  echo  "main": "dist/main.js",
  echo  "main": "dist/main.js",>> "%~dp0package.json"
  echo  "scripts": {
  echo  "scripts": {>> "%~dp0package.json"
  echo   "build": "tsc -p tsconfig.json",
  echo   "build": "tsc -p tsconfig.json",>> "%~dp0package.json"
  echo   "start": "node dist/main.js",
  echo   "start": "node dist/main.js",>> "%~dp0package.json"
  echo   "dev":   "tsx src/main.ts",
  echo   "dev":   "tsx src/main.ts",>> "%~dp0package.json"
  echo   "watch": "tsc -w -p tsconfig.json"
  echo   "watch": "tsc -w -p tsconfig.json">> "%~dp0package.json"
  echo  },
  echo  },>> "%~dp0package.json"
  echo  "dependencies": {
  echo  "dependencies": {>> "%~dp0package.json"
  echo   "@modelcontextprotocol/sdk": "^1.17.2",
  echo   "@modelcontextprotocol/sdk": "^1.17.2",>> "%~dp0package.json"
  echo   "cors": "^2.8.5",
  echo   "cors": "^2.8.5",>> "%~dp0package.json"
  echo   "express": "^5.1.0",
  echo   "express": "^5.1.0",>> "%~dp0package.json"
  echo   "dotenv": "^16.4.5",
  echo   "dotenv": "^16.4.5",>> "%~dp0package.json"
  echo   "zod": "^4.4.3"
  echo   "zod": "^4.4.3">> "%~dp0package.json"
  echo  },
  echo  },>> "%~dp0package.json"
  echo  "devDependencies": {
  echo  "devDependencies": {>> "%~dp0package.json"
  echo   "@types/cors": "^2.8.19",
  echo   "@types/cors": "^2.8.19",>> "%~dp0package.json"
  echo   "@types/express": "^5.0.3",
  echo   "@types/express": "^5.0.3",>> "%~dp0package.json"
  echo   "@types/node": "^20.0.0",
  echo   "@types/node": "^20.0.0",>> "%~dp0package.json"
  echo   "tsx": "^4.0.0",
  echo   "tsx": "^4.0.0",>> "%~dp0package.json"
  echo   "typescript": "^5.0.0"
  echo   "typescript": "^5.0.0">> "%~dp0package.json"
  echo  }
  echo  }>> "%~dp0package.json"
  echo }
  echo }>> "%~dp0package.json"
 )
goto:eof

:_tsconfig
 if "%1"=="1" (
  if "%2"=="--root" (
   set "_tsconfigFile=%~dp0tsconfig.json"
  ) else (
   if NOT EXIST "src" mkdir src
   set "_tsconfigFile=%~dp0src\tsconfig.json"
  )
  call :_tsconfig 2 %2
 )
 if "%1"=="2" (
  echo:
  echo Making `"%_tsconfigFile%"`
  echo {
  echo {>"%_tsconfigFile%"
  echo  "compilerOptions": {
  echo  "compilerOptions": {>>"%_tsconfigFile%"
  echo   "target": "ES2022",
  echo   "target": "ES2022",>>"%_tsconfigFile%"
  echo   "module": "ES2022",
  echo   "module": "ES2022",>>"%_tsconfigFile%"
  echo   "moduleResolution": "node",
  echo   "moduleResolution": "node",>>"%_tsconfigFile%"
  echo   "allowSyntheticDefaultImports": true,
  echo   "allowSyntheticDefaultImports": true,>>"%_tsconfigFile%"
  echo   "esModuleInterop": true,
  echo   "esModuleInterop": true,>>"%_tsconfigFile%"
  if "%2"=="--src" echo   "allowJs": true,
  if "%2"=="--src" echo   "allowJs": true,>>"%_tsconfigFile%"
  echo   "outDir": "./dist",
  echo   "outDir": "./dist",>>"%_tsconfigFile%"
  if "%2"=="--root" echo   "rootDir": "./src",
  if "%2"=="--root" echo   "rootDir": "./src",>>"%_tsconfigFile%"
  if "%2"=="--src"  echo   "rootDir": "./",
  if "%2"=="--src"  echo   "rootDir": "./",>>"%_tsconfigFile%"
  echo   "strict": true,
  echo   "strict": true,>>"%_tsconfigFile%"
  if "%2"=="--root" echo   "declaration": false,
  if "%2"=="--root" echo   "declaration": false,>>"%_tsconfigFile%"
  if "%2"=="--src"  echo   "declaration": true,
  if "%2"=="--src"  echo   "declaration": true,>>"%_tsconfigFile%"
  echo   "skipLibCheck": true,
  echo   "skipLibCheck": true,>>"%_tsconfigFile%"
  echo   "forceConsistentCasingInFileNames": true
  echo   "forceConsistentCasingInFileNames": true>>"%_tsconfigFile%"
  echo  },
  echo  },>>"%_tsconfigFile%"
  echo  "include": ^[
  echo  "include": ^[>>"%_tsconfigFile%"
  if "%2"=="--root" echo   "src/**/*.ts"
  if "%2"=="--root" echo   "src/**/*.ts">>"%_tsconfigFile%"
  if "%2"=="--src"  echo   "*.ts"
  if "%2"=="--src"  echo   "*.ts">>"%_tsconfigFile%"
  echo  ^],
  echo  ^],>>"%_tsconfigFile%"
  echo  "exclude": ^[
  echo  "exclude": ^[>>"%_tsconfigFile%"
  echo   "node_modules",
  echo   "node_modules",>>"%_tsconfigFile%"
  echo   "dist"
  echo   "dist">>"%_tsconfigFile%"
  echo  ^]
  echo  ^]>>"%_tsconfigFile%"
  echo }
  echo }>>"%_tsconfigFile%"
 )
goto:eof

:_main
 if "%1"=="1" (
  echo: & echo Import libraries:
  echo *************************************************************************
  echo import "dotenv/config";
  echo import "dotenv/config";> "%~dp0main.ts"
  echo import express from "express";
  echo import express from "express";>> "%~dp0main.ts"
  echo import { randomUUID } from "node:crypto";
  echo import { randomUUID } from "node:crypto";>> "%~dp0main.ts"
  echo import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
  echo import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";>> "%~dp0main.ts"
  echo import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
  echo import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";>> "%~dp0main.ts"
  echo import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";
  echo import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";>> "%~dp0main.ts"
  echo import { z } from "zod";
  echo import { z } from "zod";>> "%~dp0main.ts"
  echo import cors from "cors";
  echo import cors from "cors";>> "%~dp0main.ts"
  echo import {
  echo import {>> "%~dp0main.ts"
  echo   mcpAuthMetadataRouter,
  echo   mcpAuthMetadataRouter,>> "%~dp0main.ts"
  echo   getOAuthProtectedResourceMetadataUrl,
  echo   getOAuthProtectedResourceMetadataUrl,>> "%~dp0main.ts"
  echo } from "@modelcontextprotocol/sdk/server/auth/router.js";
  echo } from "@modelcontextprotocol/sdk/server/auth/router.js";>> "%~dp0main.ts"
  echo import { requireBearerAuth } from "@modelcontextprotocol/sdk/server/auth/middleware/bearerAuth.js";
  echo import { requireBearerAuth } from "@modelcontextprotocol/sdk/server/auth/middleware/bearerAuth.js";>> "%~dp0main.ts"
  echo import { OAuthMetadata } from "@modelcontextprotocol/sdk/shared/auth.js";
  echo import { OAuthMetadata } from "@modelcontextprotocol/sdk/shared/auth.js";>> "%~dp0main.ts"
  echo import { checkResourceAllowed } from "@modelcontextprotocol/sdk/shared/auth-utils.js";
  echo import { checkResourceAllowed } from "@modelcontextprotocol/sdk/shared/auth-utils.js";>> "%~dp0main.ts"
  echo: & echo Setting Constant CONFIG variable
  echo *************************************************************************
  echo const CONFIG ^= {
  echo const CONFIG ^= {>> "%~dp0main.ts"
  echo   host: process.env.HOST ^|^| "localhost",
  echo   host: process.env.HOST ^|^| "localhost",>> "%~dp0main.ts"
  echo   port: Number^(process.env.PORT^) ^|^| 3000,
  echo   port: Number^(process.env.PORT^) ^|^| 3000,>> "%~dp0main.ts"
  echo   auth: {
  echo   auth: {>> "%~dp0main.ts"
  echo     host: process.env.AUTH_HOST ^|^| process.env.HOST ^|^| "localhost",
  echo     host: process.env.AUTH_HOST ^|^| process.env.HOST ^|^| "localhost",>> "%~dp0main.ts"
  echo     port: Number(process.env.AUTH_PORT^) ^|^| 8080,
  echo     port: Number(process.env.AUTH_PORT^) ^|^| 8080,>> "%~dp0main.ts"
  echo     realm: process.env.AUTH_REALM ^|^| "master",
  echo     realm: process.env.AUTH_REALM ^|^| "master",>> "%~dp0main.ts"
  echo     clientId: process.env.OAUTH_CLIENT_ID ^|^| "mcp-server",
  echo     clientId: process.env.OAUTH_CLIENT_ID ^|^| "mcp-server",>> "%~dp0main.ts"
  echo     clientSecret: process.env.OAUTH_CLIENT_SECRET ^|^| "",
  echo     clientSecret: process.env.OAUTH_CLIENT_SECRET ^|^| "",>> "%~dp0main.ts"
  echo   },
  echo   },>> "%~dp0main.ts"
  echo };
  echo };>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo: & echo Make Support Functions:
  echo *************************************************************************
  echo function createOAuthUrls^(^) {
  echo function createOAuthUrls^(^) {>> "%~dp0main.ts"
  echo   const authBaseUrl = new URL^(
  echo   const authBaseUrl = new URL^(>> "%~dp0main.ts"
  echo     `http://${CONFIG.auth.host}:${CONFIG.auth.port}/realms/${CONFIG.auth.realm}/`,
  echo     `http://${CONFIG.auth.host}:${CONFIG.auth.port}/realms/${CONFIG.auth.realm}/`,>> "%~dp0main.ts"
  echo   ^);
  echo   ^);>> "%~dp0main.ts"
  echo   return {
  echo   return {>> "%~dp0main.ts"
  echo     issuer: authBaseUrl.toString^(^),
  echo     issuer: authBaseUrl.toString^(^),>> "%~dp0main.ts"
  echo     introspection_endpoint: new URL^(
  echo     introspection_endpoint: new URL^(>> "%~dp0main.ts"
  echo       "protocol/openid-connect/token/introspect",
  echo       "protocol/openid-connect/token/introspect",>> "%~dp0main.ts"
  echo       authBaseUrl,
  echo       authBaseUrl,>> "%~dp0main.ts"
  echo     ^).toString^(^),
  echo     ^).toString^(^),>> "%~dp0main.ts"
  echo     authorization_endpoint: new URL^(
  echo     authorization_endpoint: new URL^(>> "%~dp0main.ts"
  echo       "protocol/openid-connect/auth",
  echo       "protocol/openid-connect/auth",>> "%~dp0main.ts"
  echo       authBaseUrl,
  echo       authBaseUrl,>> "%~dp0main.ts"
  echo     ^).toString^(^),
  echo     ^).toString^(^),>> "%~dp0main.ts"
  echo     token_endpoint: new URL^(
  echo     token_endpoint: new URL^(>> "%~dp0main.ts"
  echo       "protocol/openid-connect/token",
  echo       "protocol/openid-connect/token",>> "%~dp0main.ts"
  echo       authBaseUrl,
  echo       authBaseUrl,>> "%~dp0main.ts"
  echo     ^).toString^(^),
  echo     ^).toString^(^),>> "%~dp0main.ts"
  echo   };
  echo   };>> "%~dp0main.ts"
  echo }
  echo }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo function createRequestLogger^(^) {
  echo function createRequestLogger^(^) {>> "%~dp0main.ts"
  echo   return ^(req: any, res: any, next: any^) ^=^> {
  echo   return ^(req: any, res: any, next: any^) ^=^> {>> "%~dp0main.ts"
  echo     const start ^= Date.now^(^);
  echo     const start ^= Date.now^(^);>> "%~dp0main.ts"
  echo     res.on^("finish", ^(^) ^=^> {
  echo     res.on^("finish", ^(^) ^=^> {>> "%~dp0main.ts"
  echo       const ms ^= Date.now^(^) - start;
  echo       const ms ^= Date.now^(^) - start;>> "%~dp0main.ts"
  echo       console.log^(
  echo       console.log^(>> "%~dp0main.ts"
  echo         `${req.method} ${req.originalUrl} -^> ${res.statusCode} ${ms}ms`,
  echo         `${req.method} ${req.originalUrl} -^> ${res.statusCode} ${ms}ms`,>> "%~dp0main.ts"
  echo       ^);
  echo       ^);>> "%~dp0main.ts"
  echo     }^);
  echo     }^);>> "%~dp0main.ts"
  echo     next^(^);
  echo     next^(^);>> "%~dp0main.ts"
  echo   };
  echo   };>> "%~dp0main.ts"
  echo }
  echo }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo: & echo Define express^(^) in app constant:
  echo *************************************************************************
  echo const app = express^(^);
  echo const app = express^(^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo app.use^(
  echo app.use^(>> "%~dp0main.ts"
  echo   express.json^({
  echo   express.json^({>> "%~dp0main.ts"
  echo     verify: ^(req: any, _res, buf^) ^=^> {
  echo     verify: ^(req: any, _res, buf^) ^=^> {>> "%~dp0main.ts"
  echo       req.rawBody ^= buf?.toString^(^) ?? "";
  echo       req.rawBody ^= buf?.toString^(^) ?? "";>> "%~dp0main.ts"
  echo     },
  echo     },>> "%~dp0main.ts"
  echo   }^),
  echo   }^),>> "%~dp0main.ts"
  echo ^);
  echo ^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo app.use^(
  echo app.use^(>> "%~dp0main.ts"
  echo   cors^({
  echo   cors^({>> "%~dp0main.ts"
  echo     origin: "*",
  echo     origin: "*",>> "%~dp0main.ts"
  echo     exposedHeaders: ["Mcp-Session-Id"],
  echo     exposedHeaders: ["Mcp-Session-Id"],>> "%~dp0main.ts"
  echo   }^),
  echo   }^),>> "%~dp0main.ts"
  echo ^);
  echo ^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo app.use^(createRequestLogger^(^)^);
  echo app.use^(createRequestLogger^(^)^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo const mcpServerUrl ^= new URL^(`http://${CONFIG.host}:${CONFIG.port}`^);
  echo const mcpServerUrl ^= new URL^(`http://${CONFIG.host}:${CONFIG.port}`^);>> "%~dp0main.ts"
  echo const oauthUrls ^= createOAuthUrls^(^);
  echo const oauthUrls ^= createOAuthUrls^(^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo const oauthMetadata: OAuthMetadata = {
  echo const oauthMetadata: OAuthMetadata = {>> "%~dp0main.ts"
  echo   ...oauthUrls,
  echo   ...oauthUrls,>> "%~dp0main.ts"
  echo   response_types_supported: ["code"],
  echo   response_types_supported: ["code"],>> "%~dp0main.ts"
  echo };
  echo };>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo const tokenVerifier = {
  echo const tokenVerifier = {>> "%~dp0main.ts"
  echo   verifyAccessToken: async ^(token: string^) ^=^> {
  echo   verifyAccessToken: async ^(token: string^) ^=^> {>> "%~dp0main.ts"
  echo     const endpoint = oauthMetadata.introspection_endpoint;
  echo     const endpoint = oauthMetadata.introspection_endpoint;>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     if ^(^!endpoint^) {
  echo     if ^(^!endpoint^) {>> "%~dp0main.ts"
  echo       console.error^("[auth] no introspection endpoint in metadata"^);
  echo       console.error^("[auth] no introspection endpoint in metadata"^);>> "%~dp0main.ts"
  echo       throw new Error^("No token verification endpoint available in metadata"^);
  echo       throw new Error^("No token verification endpoint available in metadata"^);>> "%~dp0main.ts"
  echo     }
  echo     }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     const params = new URLSearchParams^({
  echo     const params = new URLSearchParams^({>> "%~dp0main.ts"
  echo       token: token,
  echo       token: token,>> "%~dp0main.ts"
  echo       client_id: CONFIG.auth.clientId,
  echo       client_id: CONFIG.auth.clientId,>> "%~dp0main.ts"
  echo     }^);
  echo     }^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     if ^(CONFIG.auth.clientSecret^) {
  echo     if ^(CONFIG.auth.clientSecret^) {>> "%~dp0main.ts"
  echo       params.set^("client_secret", CONFIG.auth.clientSecret^);
  echo       params.set^("client_secret", CONFIG.auth.clientSecret^);>> "%~dp0main.ts"
  echo     }
  echo     }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     let response: Response;
  echo     let response: Response;>> "%~dp0main.ts"
  echo     try {
  echo     try {>> "%~dp0main.ts"
  echo       response = await fetch^(endpoint, {
  echo       response = await fetch^(endpoint, {>> "%~dp0main.ts"
  echo         method: "POST",
  echo         method: "POST",>> "%~dp0main.ts"
  echo         headers: {
  echo         headers: {>> "%~dp0main.ts"
  echo           "Content-Type": "application/x-www-form-urlencoded",
  echo           "Content-Type": "application/x-www-form-urlencoded",>> "%~dp0main.ts"
  echo         },
  echo         },>> "%~dp0main.ts"
  echo         body: params.toString^(^),
  echo         body: params.toString^(^),>> "%~dp0main.ts"
  echo       }^);
  echo       }^);>> "%~dp0main.ts"
  echo     } catch ^(e^) {
  echo     } catch ^(e^) {>> "%~dp0main.ts"
  echo       console.error^("[auth] introspection fetch threw", e^);
  echo       console.error^("[auth] introspection fetch threw", e^);>> "%~dp0main.ts"
  echo       throw e;
  echo       throw e;>> "%~dp0main.ts"
  echo     }
  echo     }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     if ^(^!response.ok^) {
  echo     if ^(^!response.ok^) {>> "%~dp0main.ts"
  echo       const txt = await response.text^(^);
  echo       const txt = await response.text^(^);>> "%~dp0main.ts"
  echo       console.error^("[auth] introspection non-OK", { status: response.status }^);
  echo       console.error^("[auth] introspection non-OK", { status: response.status }^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo       try {
  echo       try {>> "%~dp0main.ts"
  echo         const obj = JSON.parse^(txt^);
  echo         const obj = JSON.parse^(txt^);>> "%~dp0main.ts"
  echo         console.log^(JSON.stringify^(obj, null, 2^)^);
  echo         console.log^(JSON.stringify^(obj, null, 2^)^);>> "%~dp0main.ts"
  echo       } catch {
  echo       } catch {>> "%~dp0main.ts"
  echo         console.error^(txt^);
  echo         console.error^(txt^);>> "%~dp0main.ts"
  echo       }
  echo       }>> "%~dp0main.ts"
  echo       throw new Error^(`Invalid or expired token: ${txt}`^);
  echo       throw new Error^(`Invalid or expired token: ${txt}`^);>> "%~dp0main.ts"
  echo     }
  echo     }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     let data: any;
  echo     let data: any;>> "%~dp0main.ts"
  echo     try {
  echo     try {>> "%~dp0main.ts"
  echo       data = await response.json^(^);
  echo       data = await response.json^(^);>> "%~dp0main.ts"
  echo     } catch ^(e^) {
  echo     } catch ^(e^) {>> "%~dp0main.ts"
  echo       const txt = await response.text^(^);
  echo       const txt = await response.text^(^);>> "%~dp0main.ts"
  echo       console.error^("[auth] failed to parse introspection JSON", {
  echo       console.error^("[auth] failed to parse introspection JSON", {>> "%~dp0main.ts"
  echo         error: String^(e^),
  echo         error: String^(e^),>> "%~dp0main.ts"
  echo         body: txt,
  echo         body: txt,>> "%~dp0main.ts"
  echo       }^);
  echo       }^);>> "%~dp0main.ts"
  echo       throw e;
  echo       throw e;>> "%~dp0main.ts"
  echo     }
  echo     }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     if ^(data.active ^=^=^= false^) {
  echo     if ^(data.active ^=^=^= false^) {>> "%~dp0main.ts"
  echo       throw new Error^("Inactive token"^);
  echo       throw new Error^("Inactive token"^);>> "%~dp0main.ts"
  echo     }
  echo     }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     if ^(^!data.aud^) {
  echo     if ^(^!data.aud^) {>> "%~dp0main.ts"
  echo       throw new Error^("Resource indicator (aud) missing"^);
  echo       throw new Error^("Resource indicator (aud) missing"^);>> "%~dp0main.ts"
  echo     }
  echo     }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     const audiences: string[] ^= Array.isArray^(data.aud^) ? data.aud : [data.aud];
  echo     const audiences: string[] ^= Array.isArray^(data.aud^) ? data.aud : [data.aud];>> "%~dp0main.ts"
  echo     const allowed ^= audiences.some^(^(a^) ^=^> {
  echo     const allowed ^= audiences.some^(^(a^) ^=^> {>> "%~dp0main.ts"
  echo       try {
  echo       try {>> "%~dp0main.ts"
  echo         return checkResourceAllowed^({
  echo         return checkResourceAllowed^({>> "%~dp0main.ts"
  echo           requestedResource: a,
  echo           requestedResource: a,>> "%~dp0main.ts"
  echo           configuredResource: mcpServerUrl,
  echo           configuredResource: mcpServerUrl,>> "%~dp0main.ts"
  echo         }^);
  echo         }^);>> "%~dp0main.ts"
  echo       } catch {
  echo       } catch {>> "%~dp0main.ts"
  echo         return false;
  echo         return false;>> "%~dp0main.ts"
  echo       }
  echo       }>> "%~dp0main.ts"
  echo     }^);
  echo     }^);>> "%~dp0main.ts"
  echo     if ^(^!allowed^) {
  echo     if ^(^!allowed^) {>> "%~dp0main.ts"
  echo       throw new Error^(
  echo       throw new Error^(>> "%~dp0main.ts"
  echo         `None of the provided audiences are allowed. Expected ${mcpServerUrl}, got: ${audiences.join^(", "^)}`,
  echo         `None of the provided audiences are allowed. Expected ${mcpServerUrl}, got: ${audiences.join^(", "^)}`,>> "%~dp0main.ts"
  echo       ^);
  echo       ^);>> "%~dp0main.ts"
  echo     }
  echo     }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     return {
  echo     return {>> "%~dp0main.ts"
  echo       token,
  echo       token,>> "%~dp0main.ts"
  echo       clientId: data.client_id,
  echo       clientId: data.client_id,>> "%~dp0main.ts"
  echo       scopes: data.scope ? data.scope.split^(" "^) : [],
  echo       scopes: data.scope ? data.scope.split^(" "^) : [],>> "%~dp0main.ts"
  echo       expiresAt: data.exp,
  echo       expiresAt: data.exp,>> "%~dp0main.ts"
  echo     };
  echo     };>> "%~dp0main.ts"
  echo   },
  echo   },>> "%~dp0main.ts"
  echo };
  echo };>> "%~dp0main.ts"
  echo app.use^(
  echo app.use^(>> "%~dp0main.ts"
  echo   mcpAuthMetadataRouter^({
  echo   mcpAuthMetadataRouter^({>> "%~dp0main.ts"
  echo     oauthMetadata,
  echo     oauthMetadata,>> "%~dp0main.ts"
  echo     resourceServerUrl: mcpServerUrl,
  echo     resourceServerUrl: mcpServerUrl,>> "%~dp0main.ts"
  echo     scopesSupported: ["mcp:tools"],
  echo     scopesSupported: ["mcp:tools"],>> "%~dp0main.ts"
  echo     resourceName: "MCP Demo Server",
  echo     resourceName: "MCP Demo Server",>> "%~dp0main.ts"
  echo   }^),
  echo   }^),>> "%~dp0main.ts"
  echo ^);
  echo ^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo const authMiddleware ^= requireBearerAuth^({
  echo const authMiddleware ^= requireBearerAuth^({>> "%~dp0main.ts"
  echo   verifier: tokenVerifier,
  echo   verifier: tokenVerifier,>> "%~dp0main.ts"
  echo   requiredScopes: [],
  echo   requiredScopes: [],>> "%~dp0main.ts"
  echo   resourceMetadataUrl: getOAuthProtectedResourceMetadataUrl^(mcpServerUrl^),
  echo   resourceMetadataUrl: getOAuthProtectedResourceMetadataUrl^(mcpServerUrl^),>> "%~dp0main.ts"
  echo }^);
  echo }^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo const transports: { [sessionId: string]: StreamableHTTPServerTransport } ^= {};
  echo const transports: { [sessionId: string]: StreamableHTTPServerTransport } ^= {};>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo function createMcpServer^(^) {
  echo function createMcpServer^(^) {>> "%~dp0main.ts"
  echo   const server = new McpServer^({
  echo   const server = new McpServer^({>> "%~dp0main.ts"
  echo     name: "authorization-ts-server",
  echo     name: "authorization-ts-server",>> "%~dp0main.ts"
  echo     version: "0.0.0-alpha",
  echo     version: "0.0.0-alpha",>> "%~dp0main.ts"
  echo   }^);
  echo   }^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo   server.registerTool^(
  echo   server.registerTool^(>> "%~dp0main.ts"
  echo     "add",
  echo     "add",>> "%~dp0main.ts"
  echo     {
  echo     {>> "%~dp0main.ts"
  echo       title: "Addition Tool",
  echo       title: "Addition Tool",>> "%~dp0main.ts"
  echo       description: "Add two numbers together",
  echo       description: "Add two numbers together",>> "%~dp0main.ts"
  echo       inputSchema: {
  echo       inputSchema: {>> "%~dp0main.ts"
  echo         a: z.number^(^).describe^("First number to add"^),
  echo         a: z.number^(^).describe^("First number to add"^),>> "%~dp0main.ts"
  echo         b: z.number^(^).describe^("Second number to add"^),
  echo         b: z.number^(^).describe^("Second number to add"^),>> "%~dp0main.ts"
  echo       },
  echo       },>> "%~dp0main.ts"
  echo     },
  echo     },>> "%~dp0main.ts"
  echo     async ^({ a, b }^) ^=^> ^({
  echo     async ^({ a, b }^) ^=^> ^({>> "%~dp0main.ts"
  echo       content: [{ type: "text", text: `${a} + ${b} ^= ${a + b}` }],
  echo       content: [{ type: "text", text: `${a} + ${b} ^= ${a + b}` }],>> "%~dp0main.ts"
  echo     }^),
  echo     }^),>> "%~dp0main.ts"
  echo   ^);
  echo   ^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo   server.registerTool^(
  echo   server.registerTool^(>> "%~dp0main.ts"
  echo     "multiply",
  echo     "multiply",>> "%~dp0main.ts"
  echo     {
  echo     {>> "%~dp0main.ts"
  echo       title: "Multiplication Tool",
  echo       title: "Multiplication Tool",>> "%~dp0main.ts"
  echo       description: "Multiply two numbers together",
  echo       description: "Multiply two numbers together",>> "%~dp0main.ts"
  echo       inputSchema: {
  echo       inputSchema: {>> "%~dp0main.ts"
  echo         x: z.number^(^).describe^("First number to multiply"^),
  echo         x: z.number^(^).describe^("First number to multiply"^),>> "%~dp0main.ts"
  echo         y: z.number^(^).describe^("Second number to multiply"^),
  echo         y: z.number^(^).describe^("Second number to multiply"^),>> "%~dp0main.ts"
  echo       },
  echo       },>> "%~dp0main.ts"
  echo     },
  echo     },>> "%~dp0main.ts"
  echo     async ^({ x, y }^) ^=^> ^({
  echo     async ^({ x, y }^) ^=^> ^({>> "%~dp0main.ts"
  echo       content: [{ type: "text", text: `${x} x ${y} ^= ${x * y}` }],
  echo       content: [{ type: "text", text: `${x} x ${y} ^= ${x * y}` }],>> "%~dp0main.ts"
  echo     }^),
  echo     }^),>> "%~dp0main.ts"
  echo   ^);
  echo   ^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo   return server;
  echo   return server;>> "%~dp0main.ts"
  echo }
  echo }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo const mcpPostHandler ^= async ^(req: express.Request, res: express.Response^) ^=^> {
  echo const mcpPostHandler ^= async ^(req: express.Request, res: express.Response^) ^=^> {>> "%~dp0main.ts"
  echo   const sessionId = req.headers["mcp-session-id"] as string ^| undefined;
  echo   const sessionId = req.headers["mcp-session-id"] as string ^| undefined;>> "%~dp0main.ts"
  echo   let transport: StreamableHTTPServerTransport;
  echo   let transport: StreamableHTTPServerTransport;>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo   if ^(sessionId ^&^& transports[sessionId]^) {
  echo   if ^(sessionId ^&^& transports[sessionId]^) {>> "%~dp0main.ts"
  echo     transport ^= transports[sessionId];
  echo     transport ^= transports[sessionId];>> "%~dp0main.ts"
  echo   } else if ^(^!sessionId ^&^& isInitializeRequest^(req.body^)^) {
  echo   } else if ^(^!sessionId ^&^& isInitializeRequest^(req.body^)^) {>> "%~dp0main.ts"
  echo     transport = new StreamableHTTPServerTransport^({
  echo     transport = new StreamableHTTPServerTransport^({>> "%~dp0main.ts"
  echo       sessionIdGenerator: ^(^) ^=^> randomUUID^(^),
  echo       sessionIdGenerator: ^(^) ^=^> randomUUID^(^),>> "%~dp0main.ts"
  echo       onsessioninitialized: ^(sessionId^) ^=^> {
  echo       onsessioninitialized: ^(sessionId^) ^=^> {>> "%~dp0main.ts"
  echo         transports[sessionId] = transport;
  echo         transports[sessionId] = transport;>> "%~dp0main.ts"
  echo       },
  echo       },>> "%~dp0main.ts"
  echo     }^);
  echo     }^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     transport.onclose ^= ^(^) ^=^> {
  echo     transport.onclose ^= ^(^) ^=^> {>> "%~dp0main.ts"
  echo       if ^(transport.sessionId^) {
  echo       if ^(transport.sessionId^) {>> "%~dp0main.ts"
  echo         delete transports[transport.sessionId];
  echo         delete transports[transport.sessionId];>> "%~dp0main.ts"
  echo       }
  echo       }>> "%~dp0main.ts"
  echo     };
  echo     };>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo     const server ^= createMcpServer^(^);
  echo     const server ^= createMcpServer^(^);>> "%~dp0main.ts"
  echo     await server.connect^(transport^);
  echo     await server.connect^(transport^);>> "%~dp0main.ts"
  echo   } else {
  echo   } else {>> "%~dp0main.ts"
  echo     res.status^(400^).json^({
  echo     res.status^(400^).json^({>> "%~dp0main.ts"
  echo       jsonrpc: "2.0",
  echo       jsonrpc: "2.0",>> "%~dp0main.ts"
  echo       error: {
  echo       error: {>> "%~dp0main.ts"
  echo         code: -32000,
  echo         code: -32000,>> "%~dp0main.ts"
  echo         message: "Bad Request: No valid session ID provided",
  echo         message: "Bad Request: No valid session ID provided",>> "%~dp0main.ts"
  echo       },
  echo       },>> "%~dp0main.ts"
  echo       id: null,
  echo       id: null,>> "%~dp0main.ts"
  echo     }^);
  echo     }^);>> "%~dp0main.ts"
  echo     return;
  echo     return;>> "%~dp0main.ts"
  echo   }
  echo   }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo   await transport.handleRequest^(req, res, req.body^);
  echo   await transport.handleRequest^(req, res, req.body^);>> "%~dp0main.ts"
  echo };
  echo };>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo const handleSessionRequest ^= async ^(
  echo const handleSessionRequest ^= async ^(>> "%~dp0main.ts"
  echo   req: express.Request,
  echo   req: express.Request,>> "%~dp0main.ts"
  echo   res: express.Response,
  echo   res: express.Response,>> "%~dp0main.ts"
  echo ^) ^=^> {
  echo ^) ^=^> {>> "%~dp0main.ts"
  echo   const sessionId ^= req.headers["mcp-session-id"] as string ^| undefined;
  echo   const sessionId ^= req.headers["mcp-session-id"] as string ^| undefined;>> "%~dp0main.ts"
  echo   if ^(^!sessionId ^|^| ^!transports[sessionId]^) {
  echo   if ^(^!sessionId ^|^| ^!transports[sessionId]^) {>> "%~dp0main.ts"
  echo     res.status^(400^).send^("Invalid or missing session ID"^);
  echo     res.status^(400^).send^("Invalid or missing session ID"^);>> "%~dp0main.ts"
  echo     return;
  echo     return;>> "%~dp0main.ts"
  echo   }
  echo   }>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo   const transport ^= transports[sessionId];
  echo   const transport ^= transports[sessionId];>> "%~dp0main.ts"
  echo   await transport.handleRequest^(req, res^);
  echo   await transport.handleRequest^(req, res^);>> "%~dp0main.ts"
  echo };
  echo };>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo app.post^("/", authMiddleware, mcpPostHandler^);
  echo app.post^("/", authMiddleware, mcpPostHandler^);>> "%~dp0main.ts"
  echo app.get^("/", authMiddleware, handleSessionRequest^);
  echo app.get^("/", authMiddleware, handleSessionRequest^);>> "%~dp0main.ts"
  echo app.delete^("/", authMiddleware, handleSessionRequest^);
  echo app.delete^("/", authMiddleware, handleSessionRequest^);>> "%~dp0main.ts"
  echo:
  echo:>> "%~dp0main.ts"
  echo app.listen^(CONFIG.port, CONFIG.host, ^(^) ^=^> {
  echo app.listen^(CONFIG.port, CONFIG.host, ^(^) ^=^> {>> "%~dp0main.ts"
  echo   console.log^(`MCP Server running on ${mcpServerUrl.origin}`^);
  echo   console.log^(`MCP Server running on ${mcpServerUrl.origin}`^);>> "%~dp0main.ts"
  echo   console.log^(`MCP endpoint available at ${mcpServerUrl.origin}`^);
  echo   console.log^(`MCP endpoint available at ${mcpServerUrl.origin}`^);>> "%~dp0main.ts"
  echo   console.log^(
  echo   console.log^(>> "%~dp0main.ts"
  echo     `OAuth metadata available at ${getOAuthProtectedResourceMetadataUrl^(mcpServerUrl^)}`,
  echo     `OAuth metadata available at ${getOAuthProtectedResourceMetadataUrl^(mcpServerUrl^)}`,>> "%~dp0main.ts"
  echo   ^);
  echo   ^);>> "%~dp0main.ts"
  echo }^);
  echo }^);>> "%~dp0main.ts"
 )
goto:eof

:_readyServer
 if "%1"=="1" (
  if NOT EXIST "%~dp0src" mkdir "%~dp0src" >nul 2>nul
  move /Y "%~dp0main.ts" "%~dp0src\" >nul 2>nul
 )
goto:eof

:_setEnv
 if "%1"=="1" (
  set "_runInstall=0"
  if "%2"=="--set" (
   call :_setEnv 2 %2 & goto:eof
  ) else if "%2"=="--secure" (
   call :_setEnv 2 %2 & goto:eof
  ) else (
   set "_runInstall=2"
   echo Set the _KEYCLOAK_ID and _KEYCLOAK_SECRET variables, then run `setOauth.sh --set`
   echo Then run
   echo npm run build
   echo npm run start
  )
 )
 if "%1"=="2" (
  if DEFINED _KEYCLOAK_ID (
   if DEFINED _KEYCLOAK_SECRET (
    if "%2"=="--set" (
     set "_runInstall=1"
     sed -i "s/<_KEYCLOAK_SERVER_ID_>/%_KEYCLOAK_ID%/" "%~dp0.env"
     sed -i "s/<_KEYCLOAK_SERVER_SECRET_>/%_KEYCLOAK_SECRET%/" "%~dp0.env"
     echo File '.env' has set.
    ) else if "%2"=="--secure" (
     echo Resetting '.env' file for Server:
     sed -i "s/%_KEYCLOAK_ID%/<_KEYCLOAK_SERVER_ID_>/" "%~dp0.env"
     sed -i "s/%_KEYCLOAK_SECRET%/<_KEYCLOAK_SERVER_SECRET_>/" "%~dp0.env"
     echo File '.env' has been reset.
    )
   )
  )
 )
goto:eof

:_install
 if "%1"=="1" (
  echo Installing Dependencies:
  npm install
  echo Building Files to Start Server:
  npm run build
  echo Starting Server:
  npm run start
 )
goto:eof

:_runBuildExercise
 if "%1"=="0" (
  if NOT "%_checkParOneBuildExercise%"=="--" (
   if "%_parOneBuildExercise%"=="--build" (
    echo Creating project, typing with skills like it is the 1980's.
    echo:
    call :_runBuildExercise 1 & goto:eof
   ) else if "%_parOneBuildExercise%"=="--reset" (
    echo Resetting Server:
    if EXIST "%~dp0src" rmdir /S/Q "%~dp0src" >nul 2>nul
    if EXIST "%~dp0dist" rmdir /S/Q "%~dp0dist" >nul 2>nul
    if EXIST "%~dp0node_modules" rmdir /S/Q "%~dp0node_modules" >nul 2>nul
    if EXIST "%~dp0package.json" del /Q "%~dp0package.json" >nul 2>nul
    if EXIST "%~dp0package-lock.json" del /Q "%~dp0package-lock.json" >nul 2>nul
    if EXIST "%~dp0tsconfig.json" del /Q "%~dp0tsconfig.json" >nul 2>nul
    if EXIST "%~dp0..\..\exercise-mcp.code-workspace" (
     if EXIST "%~dp0..\%~n0.bat" (
      call "%~dp0..\%~n0.bat" --reset-workspace
     )
    )
    call :_setEnv 1 --secure
    goto _closeOut
   ) else if "%_parOneBuildExercise%"=="--secure" (
    call :_setEnv 1 --secure
    goto _closeOut
   ) else (
    set "_optOut=1"
    echo Something unexpected happened
    echo Script only accepts the options:
    goto _closeOut
   )
  ) else (
   set "_optOut=1"
   echo Something unexpected happened
   echo Script requires at least one option:
   goto _closeOut
  )
 )
 if "%1"=="1" (
  echo Making `package.json` File: & echo:
  call :_package 1
  echo Creating `tsconfig.json` File: & echo:
  call :_tsconfig 1 --root
  call :_tsconfig 1 --src
  echo echo Preparing `main.ts` File: & echo:
  call :_main 1
  echo Moving Created Productin file to Server & echo:
  call :_readyServer 1
  echo Setting '.env' file for Server:
  call :_setEnv 1 --set
  call :_runBuildExercise 2 & goto:eof
 )
 if "%1"=="2" (
  echo Checking Status of '.env' configuration:
  if "%_runInstall%"=="1" (
   call :_install 1
  ) else if "%_runInstall%"=="0" (
   call :_setEnv 1 --next
  )
  echo buildExercise Script Complete:
  goto _closeOut
 )
goto:eof

:_closeOut
 set _parOneBuildExercise=
 set _checkParOneBuildExercise=
 set _runInstall=
 set _tsconfigFile=
 rem IMPORTANT - leave last
 if "%_optOut%"=="1" (
  echo   --build
  echo   --reset
  echo   --secure
 )
 set _optOut=
 rem change back to root of exercise-mcp
 cd ..\..
goto:eof