from __future__ import annotations

from queue import SimpleQueue
from typing import Any

from fastapi import Body, FastAPI, HTTPException

app = FastAPI()
QUEUE: SimpleQueue[Any] = SimpleQueue()


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


@app.get("/next")
def next_commands() -> dict[str, list[Any]]:
    commands: list[Any] = []
    while not QUEUE.empty():
        commands.append(QUEUE.get())
    return {"commands": commands}


@app.post("/enqueue")
def enqueue(payload: Any = Body(...)) -> dict[str, int]:
    if payload is None:
        raise HTTPException(status_code=400, detail="missing payload")

    commands = payload if isinstance(payload, list) else [payload]
    for command in commands:
        QUEUE.put(command)

    return {"queued": len(commands)}
