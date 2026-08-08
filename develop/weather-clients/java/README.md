# Java Weather Client

A variation of the [Spring AI MCP client
quickstart](https://github.com/spring-projects/spring-ai-examples/tree/main/model-context-protocol/web-search/brave-chatbot)
from the [develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-client#java),
focusing on usage with the GUI api server variation.

Built on Spring AI MCP auto-configuration: the `spring-ai-starter-mcp-client`
starter reads `mcp-servers-config.json`, launches the server over stdio, and
registers its tools as Spring AI tool callbacks.

## Setup Client Environment

<CodeGroup>

```bash macOS/Linux
# Uses the Spring Boot / Spring AI MCP client starter.
# The build script assembles the files below and runs `mvn clean package`.
```

```batch Windows
:: The build script assembles the files below into a Spring Boot project and
:: runs 'mvn clean package'. Java 17+ and Maven 3.6+ are required.
java -version
mvn -version
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

## Java MCP Client

### `pom.xml`
<!--START_POM-->
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.4.1</version>
        <relativePath/>
    </parent>

    <groupId>org.example</groupId>
    <artifactId>weather-client</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>weather-client</name>
    <description>MCP weather client</description>

    <properties>
        <java.version>17</java.version>
        <spring-ai.version>1.0.0</spring-ai.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.ai</groupId>
            <artifactId>spring-ai-starter-mcp-client</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.ai</groupId>
            <artifactId>spring-ai-starter-model-anthropic</artifactId>
        </dependency>
    </dependencies>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.ai</groupId>
                <artifactId>spring-ai-bom</artifactId>
                <version>${spring-ai.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```
<!--END_POM-->

### `src/main/resources/application.yml`
<!--START_APPLICATION-YML-->
```yaml
spring:
  main:
    web-application-type: none
    banner-mode: "off"
  ai:
    mcp:
      client:
        enabled: true
        name: weather-client
        version: 1.0.0
        type: SYNC
        request-timeout: 30s
        stdio:
          servers-configuration: classpath:/mcp-servers-config.json
        toolcallback:
          enabled: true
    anthropic:
      api-key: ${ANTHROPIC_API_KEY}
      chat:
        options:
          model: claude-haiku-4-5
logging:
  level:
    root: WARN
```
<!--END_APPLICATION-YML-->

### `src/main/resources/mcp-servers-config.json`
<!--START_SERVERS-CONFIG-->
```json
{
  "mcpServers": {
    "weather-server-gui": {
      "command": "java",
      "args": [
        "-Dspring.ai.mcp.server.transport=STDIO",
        "-jar",
        "../../../weather-servers/java/weather-server/target/weather-server-0.0.1-SNAPSHOT.jar"
      ]
    }
  }
}
```
<!--END_SERVERS-CONFIG-->

### `src/main/java/org/example/weatherclient/McpClientApplication.java`
<!--START_CLIENT-->
```java
package org.example.weatherclient;

import java.util.Scanner;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.tool.ToolCallbackProvider;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class McpClientApplication {

    public static void main(String[] args) {
        SpringApplication.run(McpClientApplication.class, args);
    }

    // The MCP tool callbacks are auto-registered from the stdio server, so the
    // chat client can invoke the weather tools while it answers a query.
    @Bean
    CommandLineRunner chatLoop(ChatClient.Builder chatClientBuilder, ToolCallbackProvider tools) {
        return args -> {
            var chatClient = chatClientBuilder
                    .defaultSystem("You are a useful assistant, expert in weather data.")
                    .defaultToolCallbacks(tools)
                    .build();

            System.out.println("\nMCP Client Started!");
            System.out.println("Type your queries or 'quit' to exit.");

            try (Scanner scanner = new Scanner(System.in)) {
                while (true) {
                    System.out.print("\nQuery: ");
                    if (!scanner.hasNextLine()) {
                        break;
                    }

                    String query = scanner.nextLine().trim();
                    if (query.equalsIgnoreCase("quit")) {
                        break;
                    }
                    if (query.isEmpty()) {
                        continue;
                    }

                    try {
                        String response = chatClient.prompt(query).call().content();
                        System.out.println("\n" + response);
                    } catch (Exception e) {
                        System.out.println("\nError: " + e.getMessage());
                    }
                }
            }
        };
    }
}
```
<!--END_CLIENT-->

## Exercise Command

From the client folder, the build script packages the client and runs it. The
client launches the local Java weather server over stdio using the command in
`mcp-servers-config.json`:

```batch
java -jar target\weather-client-0.0.1-SNAPSHOT.jar

MCP Client Started!
Type your queries or 'quit' to exit.

Query: What's the forecast for Boston tomorrow?
```

The client launches the server itself, so the server has to be built first. The
build script builds `develop/weather-servers/java` when its jar is missing.
