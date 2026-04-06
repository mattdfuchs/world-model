#!/usr/bin/env python3
"""Patch .md prompt files into the n8n workflow JSON.

Usage: python3 n8n/patch-prompts.py

Reads designer.md and prover.md, writes them into the systemMessage fields
of the 4 agent nodes in PipelineConstruction.json.
"""
import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WORKFLOW = REPO / "n8n" / "workflows" / "PipelineConstruction.json"
PROMPTS = {
    "designer": (REPO / "n8n" / "prompts" / "designer.md").read_text(),
    "prover": (REPO / "n8n" / "prompts" / "prover.md").read_text(),
}

AGENT_MAP = {
    "Designer Agent": "designer",
    "Designer Agent 2": "designer",
    "Prover Agent": "prover",
    "Prover Agent 2": "prover",
}

wf = json.loads(WORKFLOW.read_text())
patched = 0

for node in wf["nodes"]:
    name = node.get("name", "")
    if name in AGENT_MAP:
        prompt_key = AGENT_MAP[name]
        node["parameters"]["options"]["systemMessage"] = PROMPTS[prompt_key]
        patched += 1
        print(f"  patched {name} <- {prompt_key}.md ({len(PROMPTS[prompt_key])} chars)")

WORKFLOW.write_text(json.dumps(wf, indent=2, ensure_ascii=False) + "\n")
print(f"\nDone: {patched} nodes patched in {WORKFLOW.name}")
