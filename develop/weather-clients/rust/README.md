# Rust Weather Client

A variation of
[mcp-client-rust](https://github.com/modelcontextprotocol/quickstart-resources/tree/main/mcp-client-rust)
from the [develop/tutorial](https://modelcontextprotocol.io/docs/2026-07-28/develop/build-client#rust),
focusing on usage with the GUI api server variation.

## Setup Client Environment

<CodeGroup>

```bash macOS/Linux
cargo new weather-client
cd weather-client
```

```batch Windows
:: Create project
cargo new weather-client
cd weather-client
```

</CodeGroup>

## Set API Key

Use [Anthropic Console](https://platform.claude.com/settings/keys) to get API
key.

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

## Rust MCP Client

### `Cargo.toml`
<!--START_CARGO-->
```toml
[package]
name = "weather-client"
version = "0.1.0"
edition = "2024"

[dependencies]
anyhow = "1.0.100"
genai = "0.4.2"
rmcp = { version = "0.8.0", features = ["server", "client", "transport-io", "transport-child-process"] }
tokio = { version = "1.47.1", features = ["full"] }
tracing = "0.1.41"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
serde_json = "1.0.128"
dotenvy = "0.15.7"
reqwest = "0.12.23"
```
<!--END_CARGO-->

### `src/main.rs`
<!--START_CLIENT-->
```rust
use anyhow::{Context, Result, bail};
use genai::Client;
use genai::chat::{
    ChatMessage, ChatRequest, ChatResponse, ContentPart, Tool as GenaiTool, ToolResponse,
};
use rmcp::model::{CallToolRequestParam, Tool as McpTool};
use rmcp::service::{RoleClient, RunningService, ServiceExt};
use rmcp::transport::TokioChildProcess;
use serde_json::Value;
use tokio::io::{self, AsyncBufReadExt, BufReader};
use tokio::process::Command;

const MODEL_ANTHROPIC: &str = "claude-haiku-4-5";

struct MCPClient {
    anthropic: Client,
    session: Option<RunningService<RoleClient, ()>>,
    tools: Vec<GenaiTool>,
}

impl MCPClient {
    fn new() -> Result<Self> {
        Ok(MCPClient {
            // genai::Client reads ANTHROPIC_API_KEY from the environment when it sends.
            anthropic: Client::default(),
            session: None,
            tools: Vec::new(),
        })
    }

    // Launch the server named on the command line and read its tool list.
    async fn connect_to_server(&mut self, server_args: &[String]) -> Result<()> {
        if self.session.is_some() {
            bail!("Client is already connected to a server");
        }

        let mut command = Command::new(&server_args[0]);
        command.args(&server_args[1..]);

        let process = TokioChildProcess::new(command)
            .with_context(|| format!("Failed to spawn server process for {:?}", server_args))?;

        let session = ().serve(process).await?;

        let rmcp_tools = session
            .list_all_tools()
            .await
            .context("Unable to list tools from server")?;

        let tool_names: Vec<String> = rmcp_tools
            .iter()
            .map(|tool| tool.name.to_string())
            .collect();

        println!("Connected to server with tools: {tool_names:?}");

        self.tools = convert_tools(&rmcp_tools);
        self.session = Some(session);
        Ok(())
    }

    async fn request_model(&self, chat_req: &ChatRequest) -> Result<ChatResponse> {
        let response = self
            .anthropic
            .exec_chat(MODEL_ANTHROPIC, chat_req.clone(), None)
            .await
            .context("Anthropic chat request failed")?;

        Ok(response)
    }

    // Send one query to Claude, run any tool it asks for, and let it reply.
    async fn process_query(&mut self, query: &str) -> Result<String> {
        let session = self
            .session
            .as_ref()
            .context("Client is not connected to any server")?;

        let mut messages = vec![ChatMessage::user(query)];
        let mut final_text = Vec::new();

        // Initial Claude API call with tools
        let mut chat_req = ChatRequest::new(messages.clone()).with_tools(self.tools.clone());
        let mut chat_rsp = self.request_model(&chat_req).await?;

        // Process response content - collect text and handle tool calls
        for text in chat_rsp.texts() {
            final_text.push(text.to_string());
        }

        let tool_calls = chat_rsp.tool_calls();
        if !tool_calls.is_empty() {
            // Append assistant's response to message history
            messages.push(ChatMessage::assistant(chat_rsp.content.clone()));

            // Execute each tool call and collect responses
            let mut tool_results = Vec::new();
            for tool_call in tool_calls {
                let tool_args_str = serde_json::to_string(&tool_call.fn_arguments)
                    .unwrap_or_else(|_| "{}".to_string());

                final_text.push(format!(
                    "[Calling tool {} with args {}]",
                    tool_call.fn_name, tool_args_str
                ));

                // Query the MCP server
                let tool_result = session
                    .call_tool(CallToolRequestParam {
                        name: tool_call.fn_name.clone().into(),
                        arguments: tool_call.fn_arguments.as_object().cloned(),
                    })
                    .await
                    .with_context(|| format!("Tool call {} failed", tool_call.fn_name))?;

                let payload = serde_json::to_string(&tool_result)
                    .context("Failed to serialize tool result")?;

                tool_results.push(ContentPart::ToolResponse(ToolResponse::new(
                    tool_call.call_id.clone(),
                    payload,
                )));
            }

            // Append tool responses to message history
            messages.push(ChatMessage::user(tool_results));

            // Build the next request and query model
            chat_req = ChatRequest::new(messages.clone());
            chat_rsp = self.request_model(&chat_req).await?;

            for text in chat_rsp.texts() {
                final_text.push(text.to_string());
            }
        }

        Ok(final_text.join("\n"))
    }

    // Read a line, answer it, repeat until the person types quit.
    async fn chat_loop(&mut self) -> Result<()> {
        println!("\nMCP Client Started!");
        println!("Type your queries or 'quit' to exit.");

        let mut stdin = BufReader::new(io::stdin());
        let mut input = String::new();

        loop {
            print!("\nQuery: ");
            std::io::Write::flush(&mut std::io::stdout())?;

            input.clear();
            if stdin.read_line(&mut input).await? == 0 {
                break; // EOF
            }

            let query = input.trim();
            if query.eq_ignore_ascii_case("quit") {
                break;
            }
            if query.is_empty() {
                continue;
            }

            match self.process_query(query).await {
                Ok(response) => println!("\n{}", response),
                Err(err) => println!("\nError: {}", err),
            }
        }

        Ok(())
    }

    async fn cleanup(&mut self) -> Result<()> {
        if let Some(session) = self.session.take() {
            let _ = session.cancel().await;
        }
        Ok(())
    }
}

fn convert_tools(tools: &[McpTool]) -> Vec<GenaiTool> {
    tools
        .iter()
        .map(|tool| GenaiTool {
            name: tool.name.to_string(),
            description: tool.description.as_deref().map(str::to_string),
            schema: Some(Value::Object(tool.input_schema.as_ref().clone())),
            config: None,
        })
        .collect()
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenvy::dotenv().context("Failed to load env file")?;

    let mut args = std::env::args();
    let _ = args.next();
    let server_args: Vec<String> = args.collect();

    if server_args.is_empty() {
        eprintln!("Usage: cargo run -- <server_script_or_binary> [args...]");
        std::process::exit(1);
    }

    let mut client = MCPClient::new()?;

    let result = async {
        client.connect_to_server(&server_args).await?;
        client.chat_loop().await
    }
    .await;

    let cleanup_result = client.cleanup().await;

    result?;
    cleanup_result?;

    Ok(())
}
```
<!--END_CLIENT-->

## Exercise Command

From the client folder, the build script compiles the client and launches it
against the local Rust weather server binary:

```batch
cargo run -- ..\..\..\weather-servers\rust\weather-server\target\release\weather-server.exe

Connected to server with tools: ["get_alerts", "get_forecast", "render_weather", "draw_weather_svg"]

MCP Client Started!
Type your queries or 'quit' to exit.

Query: Any severe weather warnings for Texas right now?
```

The client launches the server itself, so the server has to be built first. The
build script builds `develop/weather-servers/rust` when its release binary is
missing.
