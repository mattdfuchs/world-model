from __future__ import annotations

import os
from pathlib import Path
from threading import Lock
from typing import Any

from lean_interact import Command, FileCommand, LeanREPLConfig, LeanServer
from lean_interact.project import LocalProject


class LeanClient:
    """LeanInteract wrapper for the local Lean project."""

    def __init__(self, project_path: Path | None = None) -> None:
        self._project_path = project_path or self._resolve_project_path()
        self._server: LeanServer | None = None
        self._lock = Lock()

    def run_command(self, cmd: str, env: int | None = None) -> dict[str, Any]:
        server = self._ensure_server()
        result = server.run(Command(cmd=cmd, env=env))
        return result.model_dump(by_alias=True, exclude_none=True)

    def run_file(self, path: str, env: int | None = None) -> dict[str, Any]:
        server = self._ensure_server()
        rel_path = self._resolve_file_path(path)
        result = server.run(FileCommand(path=rel_path, env=env))
        return result.model_dump(by_alias=True, exclude_none=True)

    def _ensure_server(self) -> LeanServer:
        with self._lock:
            if self._server is None:
                project = LocalProject(directory=str(self._project_path))
                config = LeanREPLConfig(project=project, verbose=False)
                self._server = LeanServer(config)
        return self._server

    def _resolve_project_path(self) -> Path:
        env_path = os.getenv("LEAN_PROJECT_PATH")
        if env_path:
            return Path(env_path).expanduser().resolve()

        current = Path(__file__).resolve()
        for parent in current.parents:
            candidate = parent / "lean4"
            if candidate.is_dir():
                return candidate

        return Path.cwd()

    def _resolve_file_path(self, path: str) -> str:
        if Path(path).is_absolute():
            raise ValueError("path must be relative to the Lean project")

        target = (self._project_path / path).resolve()
        if not str(target).startswith(str(self._project_path.resolve())):
            raise ValueError("path escapes the Lean project")

        return str(target.relative_to(self._project_path))
