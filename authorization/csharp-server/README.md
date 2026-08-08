# C# Authorization Server

A simple MCP resource server that validates OAuth tokens against a local
Keycloak authorization server via RFC 7662 token introspection, and exposes two
authenticated tools: `Add` and `Multiply`.

## Get Started

- .NET 9.0 or later
- A running client like Keycloak

### Install `.NET` on Linux

See:

- [Install .NET on Linux](https://learn.microsoft.com/en-us/dotnet/core/install/linux-scripted-manual)
- [Install .NET SDK on Ubuntu](https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu-install)

for more information.

**Install Script**

```bash
curl -L https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
chmod +x ./dotnet-install.sh
./dotnet-install.sh --version latest

# Ensure it is running
$HOME/.dotnet/dotnet --info

# Set variable
vi ~/.bashrc
# Bottom of file add:
export DOTNET_ROOT=$HOME/.dotnet
# Save and run:
source ~/.bashrc

# Test variable
$DOTNET_ROOT/dotnet --info

# If all good delete download
rm -rf dotnet-install.sh
```

**Frameworks**

```bash
sudo apt update
sudo apt install -y dotnet-sdk-10.0
```

**ASP.NET**

```bash
sudo apt update
sudo apt install -y aspnetcore-runtime-10.0
sudo apt install -y dotnet-runtime-10.0
```

**Dependencies**

```bash
sudo apt install zlib1g
```

### Set OS Variables

```bash
# Edit .bashrc file.
vi ~/.bashrc

# At end of `~/.bashrc` add line.
export DOTNET_ROOT=$HOME/.dotnet

# Save and run:
source ~/.bashrc
```

### Server Files and Folders

Since this is an exercise, the server source files are not checked in ready to
run. The project structure is generated from `build_source.data.txt` by the
`buildExercise` script.

> [!NOTE]
> The build script uses `sed`. On Windows, ensure a `sed` binary is on `PATH`
> (for example via [Cygwin](https://www.cygwin.com/)).

<CodeGroup>

```bash macOS/Linux
# Enusre to change to this folder.
cd authorization/<server-folder>
# Run the script
./buildExercise.sh --build
```

```batch Windows
:: Ensure you change to this folder.
cd authorization\<server-folder>
:: Run the script (generates files, runs `dotnet run`, starts the server)
buildExercise.bat --build
```

</CodeGroup>

Use `--reset` to remove all generated files and return `csharp-server` to its
original state:

```batch
buildExercise --reset
```

### Configuration (no `.env` file)

This server does **not** use a `.env` file. Neither does it need credentials.
Instead it leans on standard ASP.NET Core builder pattern. This allows for the
built-in ASP.NET Core capabilities for token validation, and not the use of
Keycloak introspection endpoint.

## C# MCP Authorization Server

### `ProtectedMcpServer.csproj`
<!--START_PROTECTEDMCPSERVER-->
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <!-- Identifier for the local secret store, not a secret itself. -->
    <UserSecretsId>local-authorization-mcp-server</UserSecretsId>
    <userVersion>0</userVersion>
    <NoWarn>$(NoWarn);CS8600</NoWarn>
  </PropertyGroup>

  <ItemGroup Condition="'$(userVersion)' == '2'">
    <PackageReference Include="ModelContextProtocol" Version="2.0.0" />
    <PackageReference Include="ModelContextProtocol.AspNetCore" Version="2.0.0" />
  </ItemGroup>

  <ItemGroup Condition="'$(userVersion)' == '0'">
    <PackageReference Include="ModelContextProtocol" Version="0.3.0-preview.3" />
    <PackageReference Include="ModelContextProtocol.AspNetCore" Version="0.3.0-preview.3" />
  </ItemGroup>

  <!-- ProtectedResourceMetadata exposes Resource, ResourceDocumentation and
       AuthorizationServers as Uri in the 0.x previews and as string in 2.0.
       Program.cs compiles the matching form behind MCP_URI_METADATA, so this
       target reads whichever ItemGroup above is uncommented and defines the
       symbol only for a 0.x package. -->
  <Target Name="DefineMcpMetadataShape" BeforeTargets="CoreCompile">
    <PropertyGroup>
      <McpPackageVersion>@(PackageReference->WithMetadataValue('Identity', 'ModelContextProtocol')->'%(Version)')</McpPackageVersion>
      <DefineConstants Condition="'$(McpPackageVersion)' != '' And $(McpPackageVersion.StartsWith('0.'))">$(DefineConstants);MCP_URI_METADATA</DefineConstants>
    </PropertyGroup>
  </Target>

  <!-- The JwtBearer package major has to match the target framework major.
       Windows builds net9.0 and WSL builds net10.0, so each pins the version
       it can actually restore. -->
  
  <ItemGroup Condition="'$(TargetFramework)' == 'net9.0'">
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="9.0.18" />
  </ItemGroup>

  <ItemGroup Condition="'$(TargetFramework)' == 'net10.0'">
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="10.0.10" />
  </ItemGroup>

</Project>
```
<!--END_PROTECTEDMCPSERVER-->

### `Tools/MathTools.cs`
<!--START_MATH-TOOL-->
```cs
using System.ComponentModel;
using ModelContextProtocol;
using ModelContextProtocol.Server;

namespace ProtectedMcpServer.Tools;

[McpServerToolType]
public sealed class MathTools
{
    [McpServerTool, Description("Add two numbers together.")]
    public Task<double> Add(
        [Description("First operand")] double a,
        [Description("Second operand")] double b)
    {
        return Task.FromResult(a + b);
    }

    [McpServerTool, Description("Multiply two numbers together.")]
    public Task<double> Multiply(
        [Description("First operand")] double a,
        [Description("Second operand")] double b)
    {
        return Task.FromResult(a * b);
    }
}
```
<!--END_MATH-TOOL-->

### `Program.cs`
<!--START_SERVER-->
```cs
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using ModelContextProtocol.AspNetCore.Authentication;
using ModelContextProtocol.Authentication;
using ProtectedMcpServer.Tools;
using System.Reflection;
using System.Security.Claims;

var builder = WebApplication.CreateBuilder(args);

// Public identity of this resource server. The client and the protected
// resource metadata have to agree on this exact URL, so it stays a name the
// client can actually route to.
var serverUrl = ResolveUrl("MCP_SERVER_URL", "http://localhost:3000/");

// Address Kestrel listens on, kept separate from serverUrl on purpose. A
// localhost bind only accepts connections that originate on the same host, so
// a server running inside WSL stays invisible to a client running on Windows.
// 0.0.0.0 accepts on every IPv4 interface of whichever host it runs on.
var listenUrl = ResolveUrl("MCP_LISTEN_URL", "http://0.0.0.0:3000/");

var authorizationServerUrl = ResolveUrl("MCP_AUTH_SERVER_URL", "http://localhost:8080/realms/master/");

// Human readable docs for the exposed tools, advertised to clients that read
// the protected resource metadata. Declared once so both compile time branches
// below stay in step.
const string documentationUrl = "https://docs.example.com/api/math";

// Keycloak stamps "iss" without a trailing slash and issuer validation is an
// exact string comparison, so the trailing slash has to come off here.
var tokenIssuer = authorizationServerUrl.TrimEnd('/');

var builderServices = builder.Services.AddAuthentication(options =>
{
    options.DefaultChallengeScheme = McpAuthenticationDefaults.AuthenticationScheme;
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
});

builderServices.AddJwtBearer(options =>
{
    options.Authority = authorizationServerUrl;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = false, // Always enable in production
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = tokenIssuer,
    };

    options.RequireHttpsMetadata = false; // Set to true in production

    options.Events = new JwtBearerEvents
    {
        OnTokenValidated = context =>
        {
            var name = context.Principal?.Identity?.Name ?? "unknown";
            var email = context.Principal?.FindFirstValue("preferred_username") ?? "unknown";
            Console.WriteLine($"Token validated for: {name} ({email})");
            return Task.CompletedTask;
        },
        OnAuthenticationFailed = context =>
        {
            Console.WriteLine($"Authentication failed: {context.Exception.Message}");
            return Task.CompletedTask;
        },
        OnChallenge = context =>
        {
            Console.WriteLine("Challenging client to authenticate with Keycloak");
            return Task.CompletedTask;
        }
    };
});

builderServices.AddMcp(options =>
{
    // ProtectedResourceMetadata carried Uri typed properties through the 0.x
    // previews and switched them to string in 2.0, so the same assignment
    // cannot serve both packages. The choice is a compile time one because a
    // property binds a single type, which rules out a runtime version check.
    // MCP_URI_METADATA is defined by the build whenever the active
    // ModelContextProtocol PackageReference is a 0.x version, so swapping the
    // ItemGroup in ProtectedMcpServer.csproj needs no edit here.
    options.ResourceMetadata = new()
    {
#if MCP_URI_METADATA
        Resource = new Uri(serverUrl),
        ResourceDocumentation = new Uri(documentationUrl),
        AuthorizationServers = [new Uri(authorizationServerUrl)],
#else
        Resource = serverUrl,
        ResourceDocumentation = documentationUrl,
        AuthorizationServers = [authorizationServerUrl],
#endif
        ScopesSupported = ["mcp:tools"]
    };
});

builder.Services.AddAuthorization();

builder.Services.AddHttpContextAccessor();
builder.Services.AddMcpServer()
    .WithTools<MathTools>()
    .WithHttpTransport();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapMcp().RequireAuthorization();

// Reports the ModelContextProtocol build that actually loaded rather than the
// version string in the project file, so a stale restore is visible at startup.
var mcpVersion = typeof(ProtectedResourceMetadata).Assembly
    .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
    .InformationalVersion.Split('+')[0]
    ?? typeof(ProtectedResourceMetadata).Assembly.GetName().Version?.ToString()
    ?? "unknown";

Console.WriteLine($"Starting MCP server with authorization at {serverUrl}");
Console.WriteLine($"ModelContextProtocol version: {mcpVersion}");
Console.WriteLine($"Listening on {listenUrl}");
Console.WriteLine($"Using Keycloak server at {authorizationServerUrl}");
Console.WriteLine($"Protected Resource Metadata URL: {serverUrl}.well-known/oauth-protected-resource");
Console.WriteLine("Exposed Math tools: Add, Multiply");
Console.WriteLine("Press Ctrl+C to stop the server");

app.Run(listenUrl);

// Reads an absolute http or https URL from the environment, falls back to the
// supplied default, and fails fast with a readable message when malformed.
static string ResolveUrl(string variableName, string fallback)
{
    var raw = Environment.GetEnvironmentVariable(variableName);
    var value = string.IsNullOrWhiteSpace(raw) ? fallback : raw.Trim();

    if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) ||
        (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
    {
        throw new InvalidOperationException(
            $"{variableName} must be an absolute http or https URL. Received: '{value}'.");
    }

    return uri.ToString();
}
```
<!--END_SERVER-->

## Starting the Server

The `buildExercise --build` step already starts the server. To build and run it
manually:

```bash
dotnet run
```

A healthy server answers an unauthenticated request with `401` (it is up and
asking for a token):

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/
```

### Connect to Client

Assuming the instructions from
[authorization](https://modelcontextprotocol.io/docs/tutorials/security/authorization)
have been followed, in VS Code do:

1. Press `Ctrl + Shift + P`
2. Type and select `MCP: List Server`
  - If not listed do:
    - `Ctrl + Shift + P`
    - Type and select `MCP: Add server`
    - Select `HTTP`
    - Input `http://localhost:3000`
    - Then follow steps 1-3
3. Select the MCP Server

VS Code will prompt to open the browser, allow, login, and the MCP tools will
be registered.

> [!NOTE]
> If a `.vscode` folder exists, an additional `settings.json` file may be created
> with contents like:

```json
{
 "chat.mcp.serverSampling": {
  "csharp-server/.vscode/mcp.json: my-mcp-server-f51abc5f": {
   "allowedModels": [
    "copilotcli/auto",
    "copilot/auto",
    "copilotcli/claude-haiku-4.5"
   ]
  }
 }
}
```

## Troubleshooting

- Try `Ctrl + Shift + P` then:
  - `Authentication: Remove Dynamic Authentication Providers`
  - Select the relevant `MCP Resource Server` and click **OK** to delete
- Ensure the server is running (`dotnet run --framework net <version>`), and that the
  terminal stays open.

### Trusted Hosts URIs

> [!NOTE]
> Do not prepend the URI with the `http` protocol.

After getting the computer's IP from running `ifconfig` (*Linux*) or `ipconfig`
(*Windows*), the Trusted Hosts should look like:

```
localhost:*
172.17.0.1
172.17.80.1
```
