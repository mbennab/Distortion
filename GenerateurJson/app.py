import json
import re
import uuid
from pathlib import Path

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

app = FastAPI(title="Distortion Dimension Editor")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = Path(__file__).parent
DIMENSIONS_DIR = BASE_DIR / "dimensions"
DIMENSIONS_DIR.mkdir(exist_ok=True)

SNAKE_CASE_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def _dimension_path(dim_id: str) -> Path:
    return DIMENSIONS_DIR / f"dimension_{dim_id}.json"


def _load_dimension(dim_id: str) -> dict:
    path = _dimension_path(dim_id)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Dimension not found")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _save_dimension(dim_id: str, data: dict) -> None:
    path = _dimension_path(dim_id)
    tmp = path.with_suffix(f".tmp.{uuid.uuid4().hex}")
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        tmp.replace(path)
    except Exception as e:
        if tmp.exists():
            tmp.unlink()
        raise HTTPException(status_code=500, detail=str(e))


def _collect_all_step_ids(data: dict) -> set:
    step_ids = set()
    for quest in data.get("quests", []):
        for step in quest.get("steps", []):
            step_ids.add(step.get("id", ""))
    return step_ids


def _collect_npc_ids(data: dict) -> set:
    return {npc.get("id", "") for npc in data.get("npcs", [])}


def _collect_item_ids(data: dict) -> set:
    return {item.get("id", "") for item in data.get("items", [])}


def _collect_quest_ids(data: dict) -> set:
    return {q.get("id", "") for q in data.get("quests", [])}


def _has_cycle(quests: list) -> bool:
    graph = {}
    for q in quests:
        graph[q.get("id", "")] = q.get("requires_quests", [])

    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}

    def dfs(node: str) -> bool:
        color[node] = GRAY
        for neighbor in graph.get(node, []):
            if neighbor not in color:
                continue
            if color[neighbor] == GRAY:
                return True
            if color[neighbor] == WHITE:
                if dfs(neighbor):
                    return True
        color[node] = BLACK
        return False

    for node in graph:
        if color[node] == WHITE:
            if dfs(node):
                return True
    return False


VALID_QUEST_STATUSES = {"not_started", "done"}


def _validate_json(data: dict) -> list:
    anomalies = []
    quest_ids = _collect_quest_ids(data)
    step_ids = _collect_all_step_ids(data)

    all_ids = []
    if isinstance(data.get("meta"), dict) and "id" in data["meta"]:
        all_ids.append(data["meta"]["id"])
    for npc in data.get("npcs", []):
        all_ids.append(npc.get("id", ""))
        for intent in npc.get("intentions", []):
            all_ids.append(intent.get("id", ""))
    for quest in data.get("quests", []):
        all_ids.append(quest.get("id", ""))
        for step in quest.get("steps", []):
            all_ids.append(step.get("id", ""))
    for mg in data.get("mini_games", []):
        all_ids.append(mg.get("id", ""))
    for item in data.get("items", []):
        all_ids.append(item.get("id", ""))

    seen_ids = {}
    for id_val in all_ids:
        if not id_val:
            continue
        if not SNAKE_CASE_RE.match(id_val):
            anomalies.append({
                "type": "id_format",
                "severity": "error",
                "message": f"ID '{id_val}' is not valid snake_case",
                "path": f"id:{id_val}"
            })
        if id_val in seen_ids:
            anomalies.append({
                "type": "duplicate_id",
                "severity": "error",
                "message": f"Duplicate ID '{id_val}' found (first at {seen_ids[id_val]})",
                "path": f"id:{id_val}"
            })
        else:
            seen_ids[id_val] = ""

    for npc in data.get("npcs", []):
        npc_id = npc.get("id", "?")
        intentions = npc.get("intentions", [])
        if not intentions:
            anomalies.append({
                "type": "npc_no_dialogue",
                "severity": "warning",
                "message": f"PNJ '{npc_id}' has no intentions entries",
                "path": f"npcs.{npc_id}"
            })

        involved_quests = set()
        for intent in intentions:
            qid = intent.get("condition", {}).get("quest_id")
            if qid:
                involved_quests.add(qid)

            cond = intent.get("condition", {})
            qs = cond.get("quest_status")
            if qs and qs not in VALID_QUEST_STATUSES:
                anomalies.append({
                    "type": "invalid_quest_status",
                    "severity": "error",
                    "message": f"Intent '{intent.get('id')}' has invalid quest_status '{qs}'",
                    "path": f"npcs.{npc_id}.intentions.{intent.get('id')}.condition.quest_status"
                })

            if not intent.get("example", "").strip():
                anomalies.append({
                    "type": "empty_reply_text",
                    "severity": "error",
                    "message": f"Intent '{intent.get('id')}' has no example dialogue",
                    "path": f"npcs.{npc_id}.intentions.{intent.get('id')}.example"
                })
            if not intent.get("trigger", "").strip():
                anomalies.append({
                    "type": "empty_reply_intention",
                    "severity": "warning",
                    "message": f"Intent '{intent.get('id')}' has no trigger description",
                    "path": f"npcs.{npc_id}.intentions.{intent.get('id')}.trigger"
                })

            r_id_val = intent.get("id", "")
            if r_id_val and not SNAKE_CASE_RE.match(r_id_val):
                anomalies.append({
                    "type": "id_format",
                    "severity": "error",
                    "message": f"Intent ID '{r_id_val}' is not valid snake_case",
                    "path": f"npcs.{npc_id}.intentions.{r_id_val}"
                })

        for qid in involved_quests:
            if qid not in quest_ids:
                anomalies.append({
                    "type": "missing_quest_ref",
                    "severity": "error",
                    "message": f"PNJ '{npc_id}' references non-existent quest '{qid}' in intention condition",
                    "path": f"npcs.{npc_id}.intentions"
                })
                continue

        for intent in intentions:
            cond = intent.get("condition", {})
            qid = cond.get("quest_id")
            cs = cond.get("quest_step")
            if qid and qid not in quest_ids:
                anomalies.append({
                    "type": "missing_quest_ref",
                    "severity": "error",
                    "message": f"Intent '{intent.get('id')}' references non-existent quest '{qid}'",
                    "path": f"npcs.{npc_id}.intentions.{intent.get('id')}.condition.quest_id"
                })
            if cs and cs not in step_ids:
                anomalies.append({
                    "type": "invalid_step",
                    "severity": "error",
                    "message": f"Intent '{intent.get('id')}' references unknown step '{cs}'",
                    "path": f"npcs.{npc_id}.intentions.{intent.get('id')}.condition.quest_step"
                })

        # Validate action field structure
        for intent in intentions:
            action = intent.get("action")
            if action is not None and isinstance(action, dict):
                if not action.get("type"):
                    anomalies.append({
                        "type": "invalid_action",
                        "severity": "error",
                        "message": f"Intent '{intent.get('id')}' action has no type",
                        "path": f"npcs.{npc_id}.intentions.{intent.get('id')}.action"
                    })
                if not action.get("id"):
                    anomalies.append({
                        "type": "invalid_action",
                        "severity": "error",
                        "message": f"Intent '{intent.get('id')}' action has no id",
                        "path": f"npcs.{npc_id}.intentions.{intent.get('id')}.action"
                    })

        for key in ("off_topic", "insult"):
            val = npc.get("fallbacks", {}).get(key, "")
            if not val.strip():
                anomalies.append({
                    "type": "empty_fallback",
                    "severity": "warning",
                    "message": f"PNJ '{npc_id}' fallback '{key}' is empty",
                    "path": f"npcs.{npc_id}.fallbacks.{key}"
                })

        dflt = npc.get("fallbacks", {}).get("default_template", "")
        if dflt and "{name}" not in dflt:
            anomalies.append({
                "type": "missing_name_template",
                "severity": "error",
                "message": f"PNJ '{npc_id}' default_template does not contain {{name}}",
                "path": f"npcs.{npc_id}.fallbacks.default_template"
            })

    gfallbacks = data.get("global_fallbacks", {})
    if isinstance(gfallbacks, dict):
        for key in ("off_topic", "insult", "timeout", "unknown"):
            val = gfallbacks.get(key, "")
            if not val.strip():
                anomalies.append({
                    "type": "empty_fallback",
                    "severity": "warning",
                    "message": f"Global fallback '{key}' is empty",
                    "path": f"global_fallbacks.{key}"
                })
        dflt = gfallbacks.get("default_template", "")
        if dflt and "{name}" not in dflt:
            anomalies.append({
                "type": "missing_name_template",
                "severity": "error",
                "message": "global_fallbacks.default_template does not contain {name}",
                "path": "global_fallbacks.default_template"
            })

    for quest in data.get("quests", []):
        quest_id = quest.get("id", "?")
        qs = quest.get("status", "")
        if qs and qs not in VALID_QUEST_STATUSES:
            anomalies.append({
                "type": "invalid_quest_status",
                "severity": "error",
                "message": f"Quest '{quest_id}' has invalid status '{qs}'",
                "path": f"quests.{quest_id}.status"
            })

        steps = quest.get("steps", [])
        if not steps:
            anomalies.append({
                "type": "quest_no_steps",
                "severity": "error",
                "message": f"Quest '{quest_id}' has no steps",
                "path": f"quests.{quest_id}"
            })

        for req in quest.get("requires_quests", []):
            if req not in quest_ids:
                anomalies.append({
                    "type": "missing_quest_dependency",
                    "severity": "error",
                    "message": f"Quest '{quest_id}' requires non-existent quest '{req}'",
                    "path": f"quests.{quest_id}.requires_quests.{req}"
                })

        for step in steps:
            step_id = step.get("id", "?")
            if not step.get("description", "").strip():
                anomalies.append({
                    "type": "step_no_description",
                    "severity": "warning",
                    "message": f"Step '{step_id}' in quest '{quest_id}' has no description",
                    "path": f"quests.{quest_id}.steps.{step_id}.description"
                })

    if _has_cycle(data.get("quests", [])):
        anomalies.append({
            "type": "dependency_cycle",
            "severity": "error",
            "message": "Quest dependencies contain a cycle",
            "path": "quests.requires_quests"
        })

    for mg in data.get("mini_games", []):
        mg_id = mg.get("id", "?")
        lqid = mg.get("linked_quest_id")
        if lqid and lqid not in quest_ids:
            anomalies.append({
                "type": "invalid_minigame_quest_link",
                "severity": "error",
                "message": f"Mini-game '{mg_id}' links to non-existent quest '{lqid}'",
                "path": f"mini_games.{mg_id}.linked_quest_id"
            })
        rqs = mg.get("requires_quest_step")
        if rqs and rqs not in step_ids:
            anomalies.append({
                "type": "invalid_minigame_step",
                "severity": "error",
                "message": f"Mini-game '{mg_id}' requires non-existent step '{rqs}'",
                "path": f"mini_games.{mg_id}.requires_quest_step"
            })

    return anomalies


def _try_read_meta(path: Path) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        meta = data.get("meta", {})
        return {
            "id": meta.get("id", path.stem.replace("dimension_", "")),
            "name": meta.get("name", "Unknown"),
            "era": meta.get("era", "?"),
            "completed": meta.get("completed", False),
        }
    except (json.JSONDecodeError, Exception):
        return {
            "id": path.stem.replace("dimension_", ""),
            "name": "Invalid JSON",
            "era": "?",
            "completed": False,
        }


@app.get("/api/dimensions")
async def list_dimensions():
    results = []
    for fpath in sorted(DIMENSIONS_DIR.glob("dimension_*.json")):
        info = _try_read_meta(fpath)
        results.append(info)
    return results


@app.post("/api/dimensions/validate")
async def validate_dimension(payload: dict):
    anomalies = _validate_json(payload)
    return {"valid": len(anomalies) == 0, "anomalies": anomalies}


@app.post("/api/dimensions/import")
async def import_dimension(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided")
    try:
        raw = await file.read()
        data = json.loads(raw)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON")
    meta = data.get("meta", {})
    dim_id = meta.get("id", "").replace("dimension_", "")
    if not dim_id:
        dim_id = Path(file.filename).stem.replace("dimension_", "")
    if not dim_id:
        dim_id = "imported"
    dim_id = re.sub(r"[^a-z0-9_]", "", dim_id.lower())
    if not dim_id:
        dim_id = "imported"
    _save_dimension(dim_id, data)
    return {"status": "imported", "id": dim_id}


@app.get("/api/dimensions/{dim_id}/export")
async def export_dimension(dim_id: str):
    path = _dimension_path(dim_id)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Dimension not found")
    return FileResponse(
        path,
        media_type="application/json",
        filename=f"dimension_{dim_id}.json",
    )


@app.get("/api/dimensions/{dim_id}")
async def get_dimension(dim_id: str):
    return _load_dimension(dim_id)


@app.post("/api/dimensions/{dim_id}")
async def save_dimension(dim_id: str, payload: dict):
    _save_dimension(dim_id, payload)
    return {"status": "ok", "id": dim_id}


@app.delete("/api/dimensions/{dim_id}")
async def delete_dimension(dim_id: str):
    path = _dimension_path(dim_id)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Dimension not found")
    try:
        path.unlink()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"status": "deleted", "id": dim_id}


@app.get("/api/template")
async def get_template():
    """Retourne un squelette de dimension prêt à remplir."""
    return {
        "meta": {"id": "nouvelle", "name": "Nouvelle dimension", "era": "???", "description": "", "completed": False},
        "npcs": [],
        "quests": [],
        "mini_games": [],
        "items": [],
        "global_fallbacks": {
            "off_topic": "...",
            "insult": "...",
            "timeout": "...",
            "unknown": "...",
            "default_template": "Le PNJ te regarde. {name}, que dis-tu ?"
        }
    }


@app.get("/api/template/npc")
async def get_npc_template():
    """Retourne un squelette de PNJ."""
    return {
        "id": "npc_nouveau",
        "name": "Nouveau PNJ",
        "personality": {
            "tone": "neutre",
            "backstory": "",
            "emotional_state": "neutre",
            "speech": {"vouvoiement": True, "vocatif": "", "phrases": "2-3 phrases", "expressions": [], "interdits": []},
            "knowledge": [],
            "goals": [],
            "conversation_arc": [
                {"phase": 1, "until_message": 3, "focus": "accueillir et se présenter"},
                {"phase": 2, "until_message": 99, "focus": "répondre aux questions"}
            ]
        },
        "intentions": [],
        "fallbacks": {"off_topic": "", "insult": "", "timeout": "", "unknown": "", "default_template": ""}
    }


@app.get("/api/dimensions/{dim_id}/npc/{npc_id}/export")
async def export_npc(dim_id: str, npc_id: str):
    """Exporte un PNJ seul (pour réutilisation entre dimensions)."""
    dim = _load_dimension(dim_id)
    if dim is None:
        raise HTTPException(status_code=404, detail="Dimension not found")
    for npc in dim.get("npcs", []):
        if npc.get("id") == npc_id:
            return npc
    raise HTTPException(status_code=404, detail="NPC not found")


@app.get("/")
async def serve_index():
    index_path = BASE_DIR / "index.html"
    if not index_path.exists():
        raise HTTPException(status_code=404, detail="index.html not found")
    return FileResponse(str(index_path), media_type="text/html")


if __name__ == "__main__":
    import os
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
