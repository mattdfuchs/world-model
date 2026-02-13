# Neo4j MCP Server

This folder contains a Dockerfile that downloads the official Neo4j MCP release binary.

## Usage
Set `MCP_NEO4J_VERSION` in `.env` (for example, `v1.3.0`). The docker-compose service
`mcp-neo4j` will build from this directory and connect to the local Neo4j instance
over Bolt.
