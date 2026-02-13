# Python MCP Service

This service is intended to expose an MCP server that talks to Lean4 via LeanInteract.

## Setup
```
python -m venv .venv
source .venv/bin/activate
pip install -e .
```

If Lean is not installed, run:
```
install-lean
```

## Run
```
uvicorn world_model.mcp_server:app --host 0.0.0.0 --port 7010
```

## Notes
- `lean-interact` expects `lake` to be available on PATH.
- Set `LEAN_PROJECT_PATH` to point at the `lean4` folder when running in Docker.
- Implement the MCP protocol in `world_model/mcp_server.py`.
