"""
Ollama + TEDx MCP client.
Connects a local Ollama model to the TEDx MCP server,
letting the LLM call MCP tools to answer questions.
"""

import asyncio
import json

import httpx
import ollama
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

# --- Config ---
SERVER_URL = "https://100.48.34.103:8443/mcp"
OLLAMA_MODEL = "mistral:7b" 


def insecure_httpx_client(headers=None, timeout=None, auth=None):
    """httpx client factory that skips TLS verification (demo only!)."""
    return httpx.AsyncClient(
        headers=headers,
        timeout=timeout if timeout else httpx.Timeout(60.0),
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


def format_tool_results(tool_name: str, tool_result: str) -> str:
    """Formatta i risultati del tool per renderli più chiari all'LLM."""
    try:
        # Prova a parsare come JSON
        data = json.loads(tool_result)
        if isinstance(data, list):
            if len(data) == 0:
                return "NESSUN RISULTATO TROVATO"
            
            # Formatta i risultati in modo leggibile
            formatted = f"Ho trovato {len(data)} video:\n\n"
            for i, video in enumerate(data, 1):
                title = video.get('title', video.get('talk_title', 'Titolo non disponibile'))
                speakers = video.get('speakers', 'Speaker sconosciuto')
                url = video.get('url', '#')
                formatted += f"{i}. **{title}**\n   Speaker: {speakers}\n   URL: {url}\n\n"
            return formatted
        else:
            return tool_result
    except:
        return tool_result


async def chat(session: ClientSession, user_message: str):
    # 1. List tools
    mcp_tools = (await session.list_tools()).tools
    ollama_tools = mcp_tools_to_ollama(mcp_tools)

    messages = [{"role": "user", "content": user_message}]
    
    # System prompt migliorato
    system_prompt = """Sei un assistente che DEVE usare i tools per cercare video.

REGOLE IMPORTANTI:
1. Quando l'utente chiede video, usa SEMPRE il tool appropriato (search_by_tag o search_by_keyword)
2. Dopo aver ricevuto i risultati, MOSTRA TUTTI i video che il tool ha restituito
3. Per ogni video, includi: titolo, speaker e URL
4. Se il tool restituisce 5 video, devi mostrare 5 video
5. NON limitarti a mostrare solo il primo risultato
6. NON inventare mai video che non esistono

Esempio di risposta corretta:
"Ho trovato 3 video:
1. Titolo1 - Speaker1 - URL1
2. Titolo2 - Speaker2 - URL2
3. Titolo3 - Speaker3 - URL3"

Formatta SEMPRE la risposta come una lista numerata con titolo, speaker e URL."""
    
    messages.insert(0, {"role": "system", "content": system_prompt})

    for iteration in range(5):
        response = ollama.chat(
            model=OLLAMA_MODEL,
            messages=messages,
            tools=ollama_tools,
        )
        
        msg = response["message"]
        messages.append(msg)
        
        tool_calls = msg.get("tool_calls", [])
        if not tool_calls:
            # Nessun tool da chiamare → risposta finale
            print(f"\n🤖 {msg['content']}")
            return
        
        # Esegue i tool
        for call in tool_calls:
            name = call["function"]["name"]
            args = call["function"]["arguments"]
            print(f"\n🔧 Calling MCP tool: {name}({args})")
            
            # CHIAMATA SINCRONA - aspetta il risultato
            result = await session.call_tool(name, arguments=args)
            
            # Estrai il testo dalla risposta
            if result.content and hasattr(result.content[0], "text"):
                raw_result = result.content[0].text
            else:
                raw_result = "NESSUN RISULTATO"
            
            # Formatta i risultati in modo chiaro
            tool_result = format_tool_results(name, raw_result)
            print(f"📊 Tool ha restituito: {len(raw_result)} caratteri")
            
            # Aggiunge il risultato alla conversazione in modo strutturato
            messages.append({
                "role": "tool", 
                "content": tool_result, 
                "name": name
            })
        
        # Forza un'ultima chiamata a Ollama per elaborare tutti i risultati
        # Questo garantisce che Ollama veda i risultati prima di rispondere
        
    # Dopo il loop, assicuriamoci che Ollama abbia prodotto una risposta
    final_response = ollama.chat(
        model=OLLAMA_MODEL,
        messages=messages,
    )
    print(f"\n🤖 {final_response['message']['content']}")


async def main():
    print(f"Connecting to {SERVER_URL}...")
    async with streamablehttp_client(
        SERVER_URL,
        httpx_client_factory=insecure_httpx_client,
    ) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print(f"✓ Connected. Using Ollama model: {OLLAMA_MODEL}\n")

            while True:
                user_msg = input("\nWhat's your question? (Type 'q' to terminate)\n")
                if user_msg == "q":
                    print("Thank you for using our app!")
                    break
                await chat(session, user_msg)


if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    asyncio.run(main())