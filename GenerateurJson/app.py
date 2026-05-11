import json
import os
import re
import sys
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

# Dossiers des eres du jeu Godot (chemin relatif depuis GenerateurJson/)
GAME_FOLDERS = {
    "hub":      BASE_DIR.parent / "HUB Central",
    "moyenage": BASE_DIR.parent / "MoyenAge",
    "nuclear":  BASE_DIR.parent / "Present",
    "futur":    BASE_DIR.parent / "Futur",
}


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


# ─── AI Prompts ─────────────────────────────────────────────────────

SYSTEM_CREATE = """Tu es un architecte de jeu video. Tu transformes les idees du createur en JSON structure pour le jeu Distortion.

## FORMAT STRICT — toujours, sans exception
{"text": "ton message", "data": {JSON complet}, "done": false}
"done": true uniquement quand le createur valide tout (ok, parfait, c'est bon, termine).
"data" commence vide et se remplit progressivement sans jamais perdre ce qui est deja valide.
Squelette initial : {"meta":{},"npcs":[],"quests":[],"mini_games":[],"items":[],"global_fallbacks":{}}

## COMPORTEMENT
- Proactif : propose des valeurs pertinentes, le createur valide ou ajuste.
- Concis : 2-4 phrases max. Va droit au but.
- Si le createur dit "ok", "oui", "go", "parfait" -> passe directement a l'etape suivante.
- Si vague -> une seule question de clarification. Si precis -> traite tout d'un coup.
- IDs toujours en snake_case, jamais de doublons dans tout le document.

## FLUX EN 4 PHASES

### Phase 1 — PITCH
Le createur decrit son jeu. Tu structures IMMEDIATEMENT :
- meta : id (snake_case), name, era, description
- PNJs detectes : id + nom + role en 5 mots chacun
- Quetes pressenties : titre + etapes grossieres
Termine par : "Je detaille les PNJ ?"

### Phase 2 — PNJ (un par un, fiche complete)
Pour chaque PNJ, proposes une fiche complete et attends validation :
personality : tone, backstory (1 phrase), emotional_state
personality.speech : vouvoiement (bool), vocatif (string), phrases (style), expressions (liste 2-3), interdits (liste 1-2)
personality.knowledge : liste de 3-5 faits concrets
personality.goals : liste de 2-3 objectifs de conversation
personality.conversation_arc : liste de 2-4 phases {phase, until_message, focus}
intentions : liste de 3-6 entrees {id (snake_case), condition (null ou {quest_id,quest_status,quest_step}), trigger, example, action (null ou {type,id,description})}
fallbacks : off_topic, insult, timeout, unknown, default_template (doit contenir {name})
Termine par : "PNJ suivant ?" ou "On passe aux quetes ?"

### Phase 3 — QUETES
Pour chaque quete :
{id, title, status:"not_started", requires_quests:[], steps:[{id,description}]}
Adapter les intentions des PNJ : ajouter les conditions quest_id/quest_status/quest_step.

### Phase 4 — FINALISATION
- global_fallbacks complet (off_topic, insult, timeout, unknown, default_template avec {name})
- Proposer mini_games et items si pertinent
- done:true quand le createur est satisfait

## REGLES ABSOLUES
- IDs snake_case (minuscules + underscores uniquement), jamais de doublons
- default_template contient toujours {name}
- Actions : {"type":"trigger","id":"...","description":"..."}
- Inclure tous les champs meme vides : [], {}, null
- Ne jamais supprimer de donnees deja validees dans "data"
"""

SYSTEM_MODIFY = """Tu es un expert en modification de dimensions JSON pour le jeu Distortion.

## FORMAT STRICT — toujours respecte
{"text": "description des changements effectues", "data": {JSON complet mis a jour}, "done": false}
"done": true uniquement si l'utilisateur dit que c'est termine (ok, parfait, fini, c'est bon).

## COMPORTEMENT
- Tu recois le JSON actuel en contexte systeme.
- Si l'utilisateur n'a pas precise ce qu'il veut modifier, demande-le en 1 question.
- Applique les changements et renvoie le JSON COMPLET mis a jour.
- Modifications chirurgicales : ne change que ce qui est demande.
- Si la demande est ambigue -> 1 question de clarification.
- Si l'utilisateur ajoute un PNJ -> genere une fiche complete (personality, intentions, fallbacks).
- Si une quete change -> adapte les conditions dans les intentions des PNJ lies.

## REGLES ABSOLUES
- Conserve TOUS les champs existants non modifies.
- IDs en snake_case, pas de doublons dans tout le document.
- default_template doit contenir {name}.
- Actions : {"type":"trigger","id":"...","description":"..."}.
- Inclure tous les champs meme vides ([], {}, null).
"""

SYSTEM_TEST = """Tu es un PNJ de jeu video. Le contexte systeme decrit ton personnage : incarne-le avec rigueur.
FORMAT JSON STRICT — toujours : {"text":"ta reponse en francais","action":null}
Si la situation correspond a une action de tes intentions, inclus-la : {"text":"...","action":{"type":"trigger","id":"..."}}
Pas d'astérisques, pas de narration. Que du dialogue en restant dans le personnage.
"""

DISTORTION_LORE = """## CONTEXTE DU PROJET — DISTORTION
Jeu 2D de voyage temporel en Godot 4 (GDScript, pas .NET). Joueur : TimeAunote.
4 eres reliees par des portails dans le HUB Central :

HUB Central (hors du temps) — portails : jaune=MoyenAge, bleu=Present, rouge=Futur.
  PNJs existants : Gardien du Nexus (enigmatique, parle par enigmes), Chien prankeur (visuel).
  Dimension : dimension_hub.json — aucune quete, le gardien guide vers les portails.

Moyen Age (ere medievale) — chateau fort.
  PNJs existants : npc_roi_moyenage (mourant, action roi_adieu → declenche cinematique gardes).
  Dimensions : dimension_moyenage.json — action roi_adieu est l'action cle.

Present/Nucleaire (2087) — ruines radioactives, bunkers.
  PNJs existants : Dr Helene Vasseur, Colonel Bravo, Zak l'Ecumeur (dimension_nuclear.json dans workshop).
  A CREER : dimension pour le Present du jeu.

Futur (futuriste) — cite hi-tech, androide, sous-sol accessible par escalier.
  PNJs existants : pnj_futur.gd (visuel uniquement, pas de dialogue pour l'instant).
  A CREER : premiere dimension pour le Futur, avec dialogue IA.

MECANIQUES CLES :
- Actions {type:"trigger","id":"...","description":"..."} envoient des signaux Godot (cinematiques, transitions scene).
- Le systeme force l'action trigger apres 5 messages si elle n'a pas ete emise.
- conversation_arc guide les phases de focus de l'IA a chaque echange.
- Dialogues en francais. IDs en snake_case. Fallback default_template doit contenir {name}.
"""


def _build_dimension_prompt(dim: dict) -> str:
    if not dim: return ""
    parts = ["## DIMENSION ACTUELLE"]
    m = dim.get("meta", {})
    parts.append(f"ID: {m.get('id','?')} | {m.get('name','?')} | {m.get('era','?')}")
    parts.append(f"Description: {m.get('description','')}")
    for npc in dim.get("npcs", []):
        p = npc.get("personality", {})
        sp = p.get("speech", {})
        parts.append(f"\n### PNJ: {npc.get('name','?')} [{npc.get('id','?')}]")
        parts.append(f"Tone: {p.get('tone','')}")
        parts.append(f"Etat: {p.get('emotional_state','')}")
        parts.append(f"Backstory: {p.get('backstory','')}")
        parts.append(f"Speech: v={sp.get('vouvoiement',True)}, voc={sp.get('vocatif','')}, {sp.get('phrases','')}")
        if sp.get('expressions'): parts.append(f"Expressions: {sp['expressions']}")
        if sp.get('interdits'): parts.append(f"Interdits: {sp['interdits']}")
        if p.get('knowledge'): parts.append(f"Connaissances: {p['knowledge']}")
        if p.get('goals'): parts.append(f"Objectifs: {p['goals']}")
        arc = p.get('conversation_arc', [])
        if arc: parts.append(f"Arc: {' → '.join(a.get('focus','') for a in arc)}")
        for i in npc.get("intentions", []):
            a = i.get("action")
            act = f" ⚡{a['type']}/{a['id']}" if a else ""
            cond = i.get("condition", {})
            c = f" [{cond.get('quest_status','')}/{cond.get('quest_step','')}]" if cond and cond.get('quest_id') else ""
            parts.append(f"  [{i.get('id','?')}{c}] {i.get('trigger','')} → \"{i.get('example','')[:60]}\"{act}")
    for q in dim.get("quests", []):
        steps = [s["id"] for s in q.get("steps", [])]
        deps = q.get("requires_quests", [])
        parts.append(f"\n### Quete: {q.get('id','?')} [{q.get('status','?')}] {q.get('title','')}")
        if deps: parts.append(f"  Depends on: {deps}")
        parts.append(f"  Steps: {' → '.join(steps)}")
    return "\n".join(parts)


# ─── API key ─────────────────────────────────────────────────────────

def _load_api_key() -> str:
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if not key:
        for p in [BASE_DIR.parent / ".env", BASE_DIR / ".env"]:
            if p.exists():
                with open(p) as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("OPENROUTER_API_KEY="):
                            v = line.split("=", 1)[1].strip().strip('"').strip("'")
                            if v: key = v; break
                if key: break
    return key


def _call_openrouter(messages: list, max_tokens: int = 1024, temperature: float = 0.7) -> dict:
    import requests
    api_key = _load_api_key()
    if not api_key:
        raise HTTPException(status_code=400, detail="No OPENROUTER_API_KEY")
    hdrs = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "http://localhost:8000",
        "X-OpenRouter-Title": "Distortion AI Builder",
    }
    payload = {
        "model": os.environ.get("MODEL", "mistralai/mistral-small-3.2-24b-instruct"),
        "temperature": temperature,
        "max_tokens": max_tokens,
        "messages": messages,
        "response_format": {"type": "json_object"},
    }
    try:
        r = requests.post("https://openrouter.ai/api/v1/chat/completions", headers=hdrs, json=payload, timeout=30)
        if not r.ok: raise HTTPException(status_code=502, detail=f"OpenRouter {r.status_code}")
        return r.json()
    except requests.Timeout:
        raise HTTPException(status_code=504, detail="Timeout")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── AI Endpoints ────────────────────────────────────────────────────

def _clean_json_response(content: str) -> str:
    """Nettoie les reponses IA : retire les blocs markdown ```json ... ```."""
    content = content.strip()
    if content.startswith("```"):
        lines = content.split("\n")
        # Retire la premiere ligne (```json ou ```) et la derniere (```)
        start = 1
        end = len(lines)
        if lines[-1].strip() == "```":
            end -= 1
        content = "\n".join(lines[start:end]).strip()
    return content


def _parse_ai_response(content: str) -> dict:
    """Parse la reponse IA avec nettoyage. Leve une exception si echec total."""
    content = _clean_json_response(content)
    return json.loads(content)


@app.post("/api/ai-build")
async def ai_build(req: dict):
    """Mode create: l'IA construit une dimension en dialoguant avec le createur."""
    msgs = [{"role": "system", "content": DISTORTION_LORE + "\n\n" + SYSTEM_CREATE}]
    for m in req.get("messages", []):
        if m.get("role") in ("user", "assistant"):
            msgs.append({"role": m["role"], "content": m["content"]})
    msg = req.get("user_message", "").strip()
    if not msg and not msgs[1:]:
        msg = "Bonjour, commençons la creation d'une dimension."
    msgs.append({"role": "user", "content": msg})
    if len(msgs) > 30:
        msgs = [msgs[0]] + msgs[-29:]

    resp = _call_openrouter(msgs, max_tokens=2048, temperature=0.7)
    raw = resp["choices"][0]["message"]["content"].strip()
    try:
        ai = _parse_ai_response(raw)
    except (json.JSONDecodeError, Exception) as e:
        raise HTTPException(status_code=502, detail=f"Reponse IA invalide: {e}. Brut: {raw[:200]}")
    return {"text": ai.get("text", ""), "data": ai.get("data", {}), "done": ai.get("done", False)}


@app.post("/api/ai-modify")
async def ai_modify(req: dict):
    """Mode modify: l'IA edite chirurgicalement une dimension existante."""
    dim = req.get("dimension", {})
    dim_context = _build_dimension_prompt(dim)
    system_content = (
        DISTORTION_LORE + "\n\n" + SYSTEM_MODIFY + "\n\n" +
        dim_context + "\n\nJSON ACTUEL COMPLET:\n" +
        json.dumps(dim, ensure_ascii=False, indent=2)
    )
    msgs = [{"role": "system", "content": system_content}]
    for m in req.get("messages", []):
        if m.get("role") in ("user", "assistant"):
            msgs.append({"role": m["role"], "content": m["content"]})
    msg = req.get("user_message", "").strip()
    if not msg:
        msg = "Qu'est-ce que tu veux modifier dans cette dimension ?"
    msgs.append({"role": "user", "content": msg})
    if len(msgs) > 30:
        msgs = [msgs[0]] + msgs[-29:]

    resp = _call_openrouter(msgs, max_tokens=2048, temperature=0.7)
    raw = resp["choices"][0]["message"]["content"].strip()
    try:
        ai = _parse_ai_response(raw)
    except (json.JSONDecodeError, Exception) as e:
        raise HTTPException(status_code=502, detail=f"Reponse IA invalide: {e}. Brut: {raw[:200]}")
    return {"text": ai.get("text", ""), "data": ai.get("data", {}), "done": ai.get("done", False)}


@app.post("/api/ai-test")
async def ai_test(req: dict):
    """Mode test: dialogue libre avec un PNJ — prompt identique au jeu Distortion."""
    dim = req.get("dimension", {})
    npc_id = req.get("npc_id", "")
    npc = next((n for n in dim.get("npcs", []) if n.get("id") == npc_id), None)
    if not npc:
        raise HTTPException(status_code=404, detail="NPC not found")

    sys.path.insert(0, str(BASE_DIR))
    import distortion_dialogue as dd_mod

    # Accepte un etat de quetes envoye par le frontend pour tester differentes branches
    game_state_raw = req.get("game_state")
    if game_state_raw and isinstance(game_state_raw, dict):
        game_state = {
            qid: {
                "status": info.get("status", "not_started"),
                "current_step": info.get("current_step"),
                "completed_steps": set(),
            }
            for qid, info in game_state_raw.items()
        }
    else:
        game_state = dd_mod.init_game_state(dim)

    msg_count = req.get("msg_count", 1)
    intentions = dd_mod.filter_intentions(npc, game_state)
    sys_prompt = dd_mod.build_system_prompt(npc, intentions, msg_count)
    usr_prompt = dd_mod.build_user_prompt(
        req.get("history", []), npc.get("name", npc_id), req.get("user_message", "")
    )
    msgs = [{"role": "system", "content": sys_prompt}, {"role": "user", "content": usr_prompt}]

    resp = _call_openrouter(msgs, max_tokens=512, temperature=0.75)
    raw = resp["choices"][0]["message"]["content"].strip()
    try:
        ai = _parse_ai_response(raw)
        return {
            "text": ai.get("text", raw),
            "action": ai.get("action"),
            "active_intentions": len(intentions),
        }
    except (json.JSONDecodeError, Exception):
        return {"text": raw, "action": None, "active_intentions": len(intentions)}


# ─── Game dimension endpoints ────────────────────────────────────────

@app.get("/api/game-dimensions")
async def list_game_dimensions():
    """Liste les dimensions presentes dans les dossiers du jeu Godot."""
    results = []
    for era_key, folder in GAME_FOLDERS.items():
        if not folder.exists():
            continue
        for fpath in sorted(folder.glob("dimension_*.json")):
            info = _try_read_meta(fpath)
            info["era_key"] = era_key
            results.append(info)
    return results


@app.get("/api/game-dimensions/{era_key}")
async def get_game_dimension(era_key: str):
    """Charge une dimension depuis le dossier du jeu."""
    folder = GAME_FOLDERS.get(era_key)
    if not folder or not folder.exists():
        raise HTTPException(status_code=404, detail=f"Era '{era_key}' inconnue ou dossier absent")
    for fpath in sorted(folder.glob("dimension_*.json")):
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            continue
    raise HTTPException(status_code=404, detail=f"Aucune dimension trouvee pour l'ere '{era_key}'")


@app.post("/api/dimensions/{dim_id}/deploy")
async def deploy_dimension(dim_id: str, payload: dict):
    """Sauvegarde dans le workshop ET dans le dossier du jeu si l'ID correspond a une ere connue."""
    _save_dimension(dim_id, payload)

    real_id = payload.get("meta", {}).get("id", dim_id)
    game_folder = GAME_FOLDERS.get(real_id)
    deployed = False
    game_path = None

    if game_folder and game_folder.exists():
        dest = game_folder / f"dimension_{real_id}.json"
        tmp = dest.with_suffix(f".tmp.{uuid.uuid4().hex}")
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            tmp.replace(dest)
            deployed = True
            game_path = str(dest)
        except Exception as e:
            if tmp.exists():
                tmp.unlink()

    return {"status": "ok", "id": real_id, "deployed": deployed, "game_path": game_path}


@app.get("/ai-builder")
async def serve_ai_builder():
    p = BASE_DIR / "ai-builder.html"
    if not p.exists():
        raise HTTPException(status_code=404, detail="ai-builder.html not found")
    return FileResponse(str(p), media_type="text/html")


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
