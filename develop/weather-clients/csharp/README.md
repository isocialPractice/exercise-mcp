# C# Weather Client

A variation of
[QuickstartClient](https://github.com/modelcontextprotocol/csharp-sdk/tree/main/samples/QuickstartClient)
from the [develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-client#c%23),
focusing on usage with the GUI api server variation.

## Setup Client Environment

<CodeGroup>

```bash macOS/Linux
dotnet new console -n weather-client
cd weather-client

dotnet add package ModelContextProtocol --prerelease
dotnet add package Anthropic.SDK
dotnet add package Microsoft.Extensions.Hosting
dotnet add package Microsoft.Extensions.AI
```

```batch Windows
:: Create project
dotnet new console -n weather-client
cd weather-client

:: Add dependencies
dotnet add package ModelContextProtocol --prerelease
dotnet add package Anthropic.SDK
dotnet add package Microsoft.Extensions.Hosting
dotnet add package Microsoft.Extensions.AI
```

</CodeGroup>

## Set API Key

Use [Anthropic Console](https://platform.claude.com/settings/keys) to get API
key. The client reads `ANTHROPIC_API_KEY` from the environment (or user
secrets), so no `.env` file is written.

**Requires Restart**

> [!NOTE]
> Ensure [Cygwin](https://www.cygwin.com/) dependency is installed, so the build
> script can extract the files below with `sed`.

<CodeGroup>

```bash macOS/Linux
# Add to ~/.bashrc file
vi ~/.bashrc

# Will have a value like "sk-ant-...etc."
export _WEATHER_CLIENT_KEY="<client-api-key>"

# Save and run:
source ~/.bashrc
```

```batch Windows
:: Set variable for reuse
:: Will have a value like "sk-ant-...etc."
setx _WEATHER_CLIENT_KEY "<client-api-key>"
```

</CodeGroup>

## C# MCP Client

### `weather-client.csproj`
<!--START_CSPROJ-->
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <UserSecretsId>weather-client-secrets</UserSecretsId>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="ModelContextProtocol" Version="0.4.0-preview.1" />
    <PackageReference Include="Anthropic.SDK" Version="5.5.1" />
    <PackageReference Include="Microsoft.Extensions.Hosting" Version="9.0.9" />
    <PackageReference Include="Microsoft.Extensions.AI" Version="9.9.1" />
  </ItemGroup>

</Project>
```
<!--END_CSPROJ-->

### `Program.cs`
<!--START_CLIENT-->
```csharp
using Anthropic.SDK;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using ModelContextProtocol.Client;
using ModelContextProtocol.Protocol.Transport;

var builder = Host.CreateApplicationBuilder(args);

builder.Configuration
    .AddEnvironmentVariables()
    .AddUserSecrets<Program>();

// Work out how to launch the server named on the command line, then connect.
var (command, arguments) = GetCommandAndArguments(args);

var clientTransport = new StdioClientTransport(new()
{
    Name = "Weather Server",
    Command = command,
    Arguments = arguments,
});

await using var mcpClient = await McpClient.CreateAsync(clientTransport);

var tools = await mcpClient.ListToolsAsync();
foreach (var tool in tools)
{
    Console.WriteLine($"Connected to server with tools: {tool.Name}");
}

// Microsoft.Extensions.AI invokes the tools automatically as the model asks.
using var anthropicClient = new AnthropicClient(new APIAuthentication(builder.Configuration["ANTHROPIC_API_KEY"]))
    .Messages
    .AsBuilder()
    .UseFunctionInvocation()
    .Build();

var options = new ChatOptions
{
    MaxOutputTokens = 1000,
    ModelId = "claude-haiku-4-5",
    Tools = [.. tools]
};

Console.ForegroundColor = ConsoleColor.Green;
Console.WriteLine("MCP Client Started!");
Console.ResetColor();

PromptForInput();
while (Console.ReadLine() is string query && !"exit".Equals(query, StringComparison.OrdinalIgnoreCase))
{
    if (string.IsNullOrWhiteSpace(query))
    {
        PromptForInput();
        continue;
    }

    await foreach (var message in anthropicClient.GetStreamingResponseAsync(query, options))
    {
        Console.Write(message);
    }
    Console.WriteLine();

    PromptForInput();
}

static void PromptForInput()
{
    Console.WriteLine("Enter a command (or 'exit' to quit):");
    Console.ForegroundColor = ConsoleColor.Cyan;
    Console.Write("> ");
    Console.ResetColor();
}

static (string command, string[] arguments) GetCommandAndArguments(string[] args)
{
    return args switch
    {
        [var script] when script.EndsWith(".py") => ("python", args),
        [var script] when script.EndsWith(".js") => ("node", args),
        [var script] when Directory.Exists(script) || (File.Exists(script) && script.EndsWith(".csproj")) => ("dotnet", ["run", "--project", script, "--no-build"]),
        _ => throw new NotSupportedException("An unsupported server script was provided. Supported scripts are .py, .js, or .csproj")
    };
}
```
<!--END_CLIENT-->

## Exercise Command

From the client folder, the build script compiles the client and launches it
against the local C# weather server project:

```batch
dotnet run -- ..\..\..\weather-servers\csharp\weather-server

Connected to server with tools: get_alerts
Connected to server with tools: get_forecast
Connected to server with tools: render_weather
Connected to server with tools: draw_weather_svg
MCP Client Started!
Enter a command (or 'exit' to quit):
> What's the forecast for Seattle this weekend?
```

The client launches the server itself with `--no-build`, so the server has to be
built first. The build script builds `develop/weather-servers/csharp` when its
project is missing.
