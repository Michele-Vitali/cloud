"""
Minimal MCP client for testing the TEDx server.
Ignores SSL verification — for use with self-signed certs only.
University lesson demo.
"""

import asyncio
import ssl
import inspect

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

# CHANGE THIS to your server URL
SERVER_URL = "https://54.146.49.184:8443/mcp"

# Build an SSL context that does NOT verify certs (demo only!)
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

# httpx (used internally by the MCP client) accepts a `verify` kwarg
# via the httpx_client_factory hook
import httpx

def insecure_httpx_client(headers=None, timeout=None, auth=None):
    return httpx.AsyncClient(
        headers=headers,
        timeout=timeout if timeout else httpx.Timeout(30.0),
        auth=auth,
        verify=False,  # <-- skip cert verification
        follow_redirects=True,
    )

async def main():
    async with streamablehttp_client(
        SERVER_URL,
        httpx_client_factory=insecure_httpx_client,
    ) as (read, write, _):
        async with ClientSession(read, write) as session:
            # 1. Initialize the connection
            await session.initialize()
            print("✓ Connected to TEDx MCP server\n")

            choice = 1
            while choice != 0:
                # 2. List available tools
                tools = await session.list_tools()
                print("Available tools:")
                for i, t in enumerate(tools.tools):
                    print(f" {i+1}) {t.name} — {t.description}")
                print(" 0) Terminate")
                print()

                # 3. Choose a tool
                chosen_tool = ""
                while True:
                    try:
                        choice = int(input("Choose a tool to call: "))
                        if choice >= 0 and choice <= len(tools.tools):
                            chosen_tool = tools.tools[choice-1]
                            break
                        else:
                            print("Invalid tool selected!")
                    except Exception as e:
                        print(f"Invalid input: {e}!")
                        continue

                if choice == 0:
                    print("Thank you for using our app!")
                    break

                schema = chosen_tool.inputSchema
                properties = schema.get("properties", {})
                required = schema.get("required", [])
                kwargs = {}

                #call_str = f"Calling {chosen_tool}("
                for name, info in properties.items():
                    param_type = info.get("type", "string")
                    default = info.get("default", None)

                    while True:
                        try:

                            if name in required:
                                val = input(f"Insert {name} ({param_type}): ")
                                if val == "":
                                    raise Exception("Required parameter, can't be empty!")
                            else:
                                val = input(f"Insert {name} (default={default}): ")
                                if val == "":
                                    kwargs[name] = default
                                    break
                            
                            if param_type == "integer":
                                val = int(val)
                            
                            kwargs[name] = val
                            #call_str += f"{name}={val}"
                            break
                    
                        except Exception as e:
                            print(f"Invalid input: {e}!")

                #print(call_str + ")")

                try:
                    result = await session.call_tool(
                        chosen_tool.name,
                        arguments=kwargs,
                    )

                    for item in result.content:
                        print(item.text)
                except Exception as e:
                    print(f"Error while calling the tool: {e}!")


if __name__ == "__main__":
    # Suppress the noisy InsecureRequestWarning
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    asyncio.run(main())