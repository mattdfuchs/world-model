from __future__ import annotations

import os
import subprocess
from pathlib import Path

from fastapi import FastAPI
from pydantic import BaseModel

from .lean_client import LeanClient

app = FastAPI(title="Python MCP Server", version="0.1.0")
lean_client = LeanClient()


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
        result = lean_client.run_command(request.cmd, env=request.env)
    except (RuntimeError, ValueError) as exc:
        return {"ok": False, "error": str(exc)}
    return {"ok": True, "result": result}


@app.post("/lean/file")
def lean_file(request: LeanFileRequest) -> dict:
    try:
        result = lean_client.run_file(request.path, env=request.env)
    except (RuntimeError, ValueError) as exc:
        return {"ok": False, "error": str(exc)}
    return {"ok": True, "result": result}


def main() -> None:
    port = int(os.getenv("PY_MCP_PORT", "7010"))
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=port)


if __name__ == "__main__":
    main()
