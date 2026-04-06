from __future__ import annotations

import os
import subprocess
from pathlib import Path

import httpx
from fastapi import FastAPI, Form, Request
from pydantic import BaseModel

from .lean_client import LeanClient

app = FastAPI(title="Python MCP Server", version="0.1.0")
lean_client = LeanClient()

NEO4J_MCP_URL = os.getenv("NEO4J_MCP_URL", "http://mcp-neo4j:7011/mcp")
NEO4J_MCP_AUTH = os.getenv("NEO4J_MCP_AUTH_HEADER", "")


def _extract_mcp_result(body: dict) -> dict:
    """Strip JSON-RPC envelope, return just the result text."""
    try:
        content = body["result"]["content"]
        text = content[0]["text"] if content else ""
        is_error = body["result"].get("isError", False)
        return {"ok": not is_error, "data": text}
    except (KeyError, IndexError):
        return body


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/tools")
def tools() -> dict:
    # TODO: Replace with MCP tool discovery once the MCP SDK is integrated.
    return {
        "tools": [
            {
                "name": "lean.ping",
                "description": "Placeholder tool to verify connectivity.",
            },
            {
                "name": "lean.build",
                "description": "Run lake build for the Lean4 project.",
            },
            {
                "name": "lean.command",
                "description": "Run a Lean command via LeanInteract.",
            },
            {
                "name": "lean.file",
                "description": "Run a Lean file via LeanInteract.",
            },
        ]
    }


class LeanBuildRequest(BaseModel):
    target: str | None = None


class LeanCommandRequest(BaseModel):
    cmd: str
    env: int | None = None


class LeanFileRequest(BaseModel):
    path: str
    env: int | None = None


def _find_lean_project() -> Path:
    # Walk up from this file to locate the repo's lean4 directory.
    env_path = os.getenv("LEAN_PROJECT_PATH")
    if env_path:
        return Path(env_path).expanduser().resolve()

    current = Path(__file__).resolve()
    for parent in current.parents:
        candidate = parent / "lean4"
        if candidate.is_dir():
            return candidate

    return Path.cwd()


@app.post("/lean/build")
def lean_build(request: LeanBuildRequest) -> dict:
    lean_path = _find_lean_project()
    cmd = ["lake", "build"]
    if request.target:
        cmd.append(request.target)

    try:
        result = subprocess.run(
            cmd,
            cwd=lean_path,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return {
            "ok": False,
            "error": "lake not found on PATH",
            "cwd": str(lean_path),
        }

    return {
        "ok": result.returncode == 0,
        "returncode": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "cwd": str(lean_path),
    }


@app.post("/lean/command")
def lean_command(request: LeanCommandRequest) -> dict:
    try:
        cmd = request.cmd
        env = request.env

        # Split import lines from the rest so the REPL processes them
        # as separate commands with chained environments.
        lines = cmd.split("\n")
        import_lines: list[str] = []
        rest_lines: list[str] = []
        past_imports = False
        for line in lines:
            if not past_imports and (line.startswith("import ") or line.strip() == ""):
                import_lines.append(line)
            else:
                past_imports = True
                rest_lines.append(line)

        import_cmd = "\n".join(import_lines).strip()
        rest_cmd = "\n".join(rest_lines).strip()

        if import_cmd and rest_cmd:
            # Run import first to set up the environment
            import_result = lean_client.run_command(import_cmd, env=env)
            env = import_result.get("env", env)
            # Run the rest in that environment
            result = lean_client.run_command(rest_cmd, env=env)
        else:
            result = lean_client.run_command(cmd, env=env)
    except (RuntimeError, ValueError) as exc:
        return {"ok": False, "error": str(exc)}
    return {"ok": True, "result": result}


@app.post("/lean/command/form")
def lean_command_form(cmd: str = Form(...), env: int | None = Form(None)) -> dict:
    """Same as /lean/command but accepts form data (for n8n tool compatibility)."""
    return lean_command(LeanCommandRequest(cmd=cmd, env=env))


@app.post("/lean/command/raw")
async def lean_command_raw(request: Request) -> dict:
    """Accept Lean code as raw text body — avoids JSON escaping issues."""
    cmd = (await request.body()).decode()
    return lean_command(LeanCommandRequest(cmd=cmd))


@app.post("/lean/file")
def lean_file(request: LeanFileRequest) -> dict:
    try:
        result = lean_client.run_file(request.path, env=request.env)
    except (RuntimeError, ValueError) as exc:
        return {"ok": False, "error": str(exc)}
    return {"ok": True, "result": result}


# Files to serve, with optional line ranges.
# (path, line_ranges | None)
# None = full file; list of (start, end) tuples = specific lines only (1-indexed, inclusive).
DOMAIN_TYPE_FILES: list[tuple[str, list[tuple[int, int]] | None]] = [
    ("WorldModel/KB/Types.lean",          [(1, 35), (44, 56)]),   # skip Role (38-42)
    ("WorldModel/KB/Relations.lean",      [(1, 6), (10, 21)]),    # skip hasRole (7-9)
    ("WorldModel/KB/Arrow/Clinical.lean", [(21, 65), (107, 140)]),# domain + evidence types
    ("WorldModel/KB/Arrow/Scope.lean",    None),                  # all essential (56 lines)
    ("WorldModel/KB/Arrow/Compile.lean",  [(22, 118), (156, 219), (285, 357)]),
        # scope infra (22-118), drug phase (156-219), full assembly (285-357)
        # skips: screening helpers, checkup (identical to drug), #eval
]


@app.get("/lean/domain-types")
def lean_domain_types() -> dict:
    """Return domain type definitions and a reference implementation.

    Serves curated line ranges per file to minimize token count
    while keeping everything the Prover needs.
    """
    lean_path = _find_lean_project()
    sections: list[str] = []
    for rel, ranges in DOMAIN_TYPE_FILES:
        fp = lean_path / rel
        if fp.exists():
            text = fp.read_text()
            if ranges is not None:
                all_lines = text.split("\n")
                selected: list[str] = []
                for start, end in ranges:
                    selected.extend(all_lines[start - 1 : end])
                    selected.append("")
                text = "\n".join(selected)
            sections.append(f"-- ═══ {rel} ═══\n{text}")
        else:
            sections.append(f"-- ═══ {rel} ═══\n-- FILE NOT FOUND")
    return {"ok": True, "source": "\n\n".join(sections)}


class CypherRequest(BaseModel):
    query: str


@app.post("/neo4j/read")
async def neo4j_read(request: CypherRequest) -> dict:
    """Proxy a read-only Cypher query to the Neo4j MCP server (JSON body)."""
    return await _neo4j_read(request.query)


@app.post("/neo4j/read/form")
async def neo4j_read_form(query: str = Form(...)) -> dict:
    """Same as /neo4j/read but accepts form data (for n8n tool compatibility)."""
    return await _neo4j_read(query)


async def _neo4j_read(query: str) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(
            NEO4J_MCP_URL,
            json={
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "read-cypher", "arguments": {"query": query}},
                "id": 50,
            },
            headers={"Authorization": NEO4J_MCP_AUTH, "Content-Type": "application/json"},
        )
        return _extract_mcp_result(resp.json())


@app.post("/neo4j/schema")
async def neo4j_schema() -> dict:
    """Proxy a get-schema call to the Neo4j MCP server."""
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(
            NEO4J_MCP_URL,
            json={
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {"name": "get-schema", "arguments": {}},
                "id": 51,
            },
            headers={"Authorization": NEO4J_MCP_AUTH, "Content-Type": "application/json"},
        )
        return _extract_mcp_result(resp.json())


def main() -> None:
    port = int(os.getenv("PY_MCP_PORT", "7010"))
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=port)


if __name__ == "__main__":
    main()
