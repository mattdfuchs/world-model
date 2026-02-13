# n8n

Use n8n to orchestrate calls between the Neo4j MCP server and the Python MCP server.

## Suggested Flow
- Use an MCP-compatible node (if installed) or an HTTP Request node.
- Target Neo4j MCP at `http://mcp-neo4j:7011` from within Docker.
- Target Python MCP at `http://python-mcp:7010` from within Docker.
- For Neo4j MCP, send a Basic Auth header with your Neo4j username and password.

## Test Workflow
An example workflow is provided at `n8n/workflows/test-components.json`.

Before importing, set `NEO4J_MCP_AUTH_HEADER` in `.env` to a value like:
```
Basic BASE64_ENCODED_USER_COLON_PASSWORD
```

Ensure `N8N_ENV_ALLOWLIST` includes `NEO4J_MCP_AUTH_HEADER` so the workflow can read it.

## Claude
Configure the official Anthropic node with your API key, or use an HTTP Request node.
