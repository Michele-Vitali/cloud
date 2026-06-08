"""
Ollama + TEDx MCP client.
Connects a local Ollama model to the TEDx MCP server,
letting the LLM call MCP tools to answer questions.

University lesson demo - ignores self-signed cert.
"""

import asyncio
import json

import httpx
import ollama
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

# --- Config ---
SERVER_URL = "https://54.146.49.184:8443/mcp"
OLLAMA_MODEL = "mistral:7b" 


def insecure_httpx_client(headers=None, timeout=None, auth=None):
    """httpx client factory that skips TLS verification (demo only!)."""
    return httpx.AsyncClient(
        headers=headers,
        timeout=timeout if timeout else httpx.Timeout(30.0),
        auth=auth,
        verify=False,
        follow_redirects=True,
    )


def mcp_tools_to_ollama(mcp_tools):
    """Convert MCP tool definitions into Ollama's expected format."""
    return [
        {
            "type": "function",
            "function": {
                "name": t.name,
                "description": t.description or "",
                "parameters": t.inputSchema,
            },
        }
        for t in mcp_tools
    ]


async def chat(session: ClientSession, user_message: str):
    # 1. List tools and convert them for Ollama
    mcp_tools = (await session.list_tools()).tools
    ollama_tools = mcp_tools_to_ollama(mcp_tools)

    messages = [{"role": "user", "content": user_message}]

    # Loop: ask Ollama, run any tools it requests, feed results back
    for _ in range(5):  # cap iterations to avoid infinite loops
        response = ollama.chat(
            model=OLLAMA_MODEL,
            messages=messages,
            tools=ollama_tools,
        )

        msg = response["message"]
        messages.append(msg)

        tool_calls = msg.get("tool_calls", [])
        if not tool_calls:
            print(f"\n🤖 {msg['content']}")
            return

        # Execute each tool call against the MCP server
        for call in tool_calls:
            name = call["function"]["name"]
            args = call["function"]["arguments"]
            print(f"\n🔧 Calling MCP tool: {name}({args})")

            result = await session.call_tool(name, arguments=args)
            text = "\n".join(c.text for c in result.content if hasattr(c, "text"))

            messages.append({"role": "tool", "content": text, "name": name})

    print("⚠️  Reached max iterations.")


async def main():
    print(f"Connecting to {SERVER_URL}...")
    async with streamablehttp_client(
        SERVER_URL,
        httpx_client_factory=insecure_httpx_client,
    ) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print(f"✓ Connected. Using Ollama model: {OLLAMA_MODEL}\n")

            user_msg = ""
            while user_msg != "q":
                user_msg = input("What's your question? (Type 'q' to terminate).\n")
                await chat(session, user_msg)
                # Try a few questions
                #await chat(session, "Find me 3 TEDx talks about feminism.")
                #await chat(session, "What are the most common tags in the dataset?")
            
            print("Thank you for using our app!")


if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    asyncio.run(main())