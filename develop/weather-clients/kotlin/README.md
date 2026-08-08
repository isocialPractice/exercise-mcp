# Kotlin Weather Client

A variation of
[kotlin-mcp-client](https://github.com/modelcontextprotocol/kotlin-sdk/tree/main/samples/kotlin-mcp-client)
from the [develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-client#kotlin),
focusing on usage with the GUI api server variation.

## Setup Client Environment

<CodeGroup>

```bash macOS/Linux
# Create a new directory for our project
mkdir kotlin-mcp-client
cd kotlin-mcp-client

# Initialize a new kotlin project
gradle init
```

```batch Windows
:: Create project
md weather-client & cd weather-client

:: Initialize a new kotlin project
gradle init
```

</CodeGroup>

## Set API Key

Use [Anthropic Console](https://platform.claude.com/settings/keys) to get API
key. The client reads `ANTHROPIC_API_KEY` from the environment, so no `.env`
file is written.

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

## Kotlin MCP Client

### `settings.gradle.kts`
<!--START_SETTINGS-GRADLE-->
```kotlin
rootProject.name = "kotlin-mcp-client"
```
<!--END_SETTINGS-GRADLE-->

### `build.gradle.kts`
<!--START_BUILD-GRADLE-->
```kotlin
// Check latest versions at https://github.com/modelcontextprotocol/kotlin-sdk/releases
val mcpVersion = "0.9.0"
val ktorVersion = "3.2.3"
val anthropicVersion = "2.15.0"
val slf4jVersion = "2.0.17"

plugins {
    kotlin("jvm") version "2.3.20"
    id("com.gradleup.shadow") version "8.3.9"
    application
}

version = "0.1.0"

repositories {
    mavenCentral()
}

application {
    mainClass.set("MainKt")
}

dependencies {
    implementation("io.modelcontextprotocol:kotlin-sdk:$mcpVersion")
    implementation("io.ktor:ktor-client-cio:$ktorVersion")
    implementation("com.anthropic:anthropic-java:$anthropicVersion")
    implementation("org.slf4j:slf4j-simple:$slf4jVersion")
}
```
<!--END_BUILD-GRADLE-->

### `src/main/kotlin/Main.kt`
<!--START_CLIENT-->
```kotlin
import com.anthropic.client.okhttp.AnthropicOkHttpClient
import com.anthropic.core.JsonValue
import com.anthropic.models.messages.MessageCreateParams
import com.anthropic.models.messages.MessageParam
import com.anthropic.models.messages.Tool
import com.anthropic.models.messages.ToolUnion
import com.fasterxml.jackson.core.type.TypeReference
import com.fasterxml.jackson.databind.ObjectMapper
import io.modelcontextprotocol.kotlin.sdk.EmptyJsonObject
import io.modelcontextprotocol.kotlin.sdk.Implementation
import io.modelcontextprotocol.kotlin.sdk.TextContent
import io.modelcontextprotocol.kotlin.sdk.client.Client
import io.modelcontextprotocol.kotlin.sdk.client.StdioClientTransport
import kotlinx.coroutines.runBlocking
import kotlinx.io.asSink
import kotlinx.io.asSource
import kotlinx.io.buffered
import kotlinx.serialization.json.JsonObject

private const val MODEL = "claude-haiku-4-5"

class MCPClient(apiKey: String) : AutoCloseable {
    private val anthropic = AnthropicOkHttpClient.builder()
        .apiKey(apiKey)
        .build()

    private val mcp: Client = Client(
        clientInfo = Implementation(name = "mcp-client-cli", version = "1.0.0")
    )
    private var serverProcess: Process? = null
    private lateinit var tools: List<ToolUnion>

    // Launch the server named on the command line and read its tool list.
    suspend fun connectToServer(serverScriptPath: String) {
        val command = buildList {
            when (serverScriptPath.substringAfterLast(".")) {
                "js" -> add("node")
                "py" -> add(if (System.getProperty("os.name").lowercase().contains("win")) "python" else "python3")
                "jar" -> addAll(listOf("java", "-jar"))
                else -> throw IllegalArgumentException("Server script must be a .js, .py or .jar file")
            }
            add(serverScriptPath)
        }

        val process = ProcessBuilder(command).start()
        serverProcess = process

        val transport = StdioClientTransport(
            input = process.inputStream.asSource().buffered(),
            output = process.outputStream.asSink().buffered(),
        )

        mcp.connect(transport)

        val toolsResult = mcp.listTools()
        tools = toolsResult.tools.map { tool ->
            ToolUnion.ofTool(
                Tool.builder()
                    .name(tool.name)
                    .description(tool.description ?: "")
                    .inputSchema(
                        Tool.InputSchema.builder()
                            .type(JsonValue.from(tool.inputSchema.type))
                            .properties(tool.inputSchema.properties?.toJsonValue() ?: EmptyJsonObject.toJsonValue())
                            .putAdditionalProperty("required", JsonValue.from(tool.inputSchema.required))
                            .build(),
                    )
                    .build(),
            )
        }
        println("Connected to server with tools: ${tools.joinToString(", ") { it.tool().get().name() }}")
    }

    // Send one query to Claude, run any tool it asks for, and let it reply.
    suspend fun processQuery(query: String): String {
        val messages = mutableListOf(
            MessageParam.builder()
                .role(MessageParam.Role.USER)
                .content(query)
                .build(),
        )

        val response = anthropic.messages().create(
            MessageCreateParams.builder()
                .model(MODEL)
                .maxTokens(1024)
                .messages(messages)
                .tools(tools)
                .build(),
        )

        val finalText = mutableListOf<String>()
        response.content().forEach { content ->
            when {
                content.isText() -> finalText.add(content.text().get().text())

                content.isToolUse() -> {
                    val toolName = content.toolUse().get().name()
                    val toolArgs =
                        content.toolUse().get()._input().convert(object : TypeReference<Map<String, JsonValue>>() {})

                    val result = mcp.callTool(
                        name = toolName,
                        arguments = toolArgs ?: emptyMap(),
                    )
                    finalText.add("[Calling tool $toolName with args $toolArgs]")

                    messages.add(
                        MessageParam.builder()
                            .role(MessageParam.Role.USER)
                            .content(
                                result.content
                                    .filterIsInstance<TextContent>()
                                    .joinToString("\n") { it.text }
                            )
                            .build(),
                    )

                    val aiResponse = anthropic.messages().create(
                        MessageCreateParams.builder()
                            .model(MODEL)
                            .maxTokens(1024)
                            .messages(messages)
                            .build(),
                    )

                    finalText.add(aiResponse.content().first().text().get().text())
                }
            }
        }

        return finalText.joinToString("\n")
    }

    // Read a line, answer it, repeat until the person types quit.
    suspend fun chatLoop() {
        println("\nMCP Client Started!")
        println("Type your queries or 'quit' to exit.")

        while (true) {
            print("\nQuery: ")
            val message = readlnOrNull() ?: break
            if (message.trim().lowercase() == "quit") break

            try {
                val response = processQuery(message)
                println("\n$response")
            } catch (e: Exception) {
                println("\nError: ${e.message}")
            }
        }
    }

    override fun close() {
        runBlocking {
            mcp.close()
        }
        serverProcess?.destroy()
        anthropic.close()
    }
}

// Convert a kotlinx.serialization JsonObject to an Anthropic SDK JsonValue.
private fun JsonObject.toJsonValue(): JsonValue {
    val mapper = ObjectMapper()
    val node = mapper.readTree(this.toString())
    return JsonValue.fromJsonNode(node)
}

fun main(args: Array<String>) = runBlocking {
    require(args.isNotEmpty()) { "Usage: java -jar <path> <path_to_server_script>" }

    val apiKey = System.getenv("ANTHROPIC_API_KEY")
    require(!apiKey.isNullOrBlank()) { "ANTHROPIC_API_KEY environment variable is not set" }

    val client = MCPClient(apiKey)
    client.use {
        client.connectToServer(args.first())
        client.chatLoop()
    }
}
```
<!--END_CLIENT-->

## Exercise Command

From the client folder, the build script assembles the shadow jar and launches
the client against the local Kotlin weather server jar:

```batch
java -jar build\libs\kotlin-mcp-client-0.1.0-all.jar ..\..\..\weather-servers\kotlin\weather-server\build\libs\weather-server-0.1.0-all.jar

Connected to server with tools: get_alerts, get_forecast, render_weather, draw_weather_svg

MCP Client Started!
Type your queries or 'quit' to exit.

Query: What's the forecast for Denver tomorrow?
```

The client launches the server itself, so the server has to be built first. The
build script builds `develop/weather-servers/kotlin` when its jar is missing.
