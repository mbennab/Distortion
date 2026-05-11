#!/usr/bin/env python3
"""
Distortion Dialogue Tester v3 — Teste et crée des dimensions via OpenRouter.

Utilisation:
    python distortion_dialogue.py                          # wizard interactif
    python distortion_dialogue.py dimension_nuclear.json    # tester une dimension
    python distortion_dialogue.py --new mon_nom             # créer rapide

Clé API lue depuis ../../.env (racine projet) ou variable OPENROUTER_API_KEY.
"""

import json
import os
import sys
import textwrap
from pathlib import Path
from datetime import datetime

# ─── ANSI ───────────────────────────────────────────────────────────────
C = {
    "reset": "\033[0m", "bold": "\033[1m", "dim": "\033[2m",
    "red": "\033[31m", "green": "\033[32m", "yellow": "\033[33m",
    "blue": "\033[34m", "magenta": "\033[35m", "cyan": "\033[36m",
    "white": "\033[37m", "gray": "\033[90m",
    "bg_red": "\033[41m", "bg_green": "\033[42m", "bg_blue": "\033[44m",
}

def c(tag: str, text: str) -> str:
    return f"{C.get(tag,'')}{text}{C['reset']}"

# ─── Configuration ──────────────────────────────────────────────────────

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
for env_p in [Path(__file__).parent.parent / ".env", Path(__file__).parent / ".env"]:
    if env_p.exists() and not OPENROUTER_API_KEY:
        with open(env_p) as f:
            for line in f:
                line = line.strip()
                if line.startswith("OPENROUTER_API_KEY="):
                    v = line.split("=", 1)[1].strip().strip('"').strip("'")
                    if v: OPENROUTER_API_KEY = v; break
        if OPENROUTER_API_KEY: break

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = os.environ.get("MODEL", "mistralai/ministral-3b-2512")
REQUEST_TIMEOUT = 15
MAX_TOKENS = 256
TEMPERATURE = 0.7
SITE_URL = "http://localhost:8000"
SITE_NAME = "Distortion Dialogue Tester v3"
MAX_HISTORY = 15
DIM_DIR = Path(__file__).parent / "dimensions"

_dimension_ref = [None]

# ─── Chargement ─────────────────────────────────────────────────────────

def load_dimension(path: str) -> dict:
    p = Path(path)
    if not p.exists():
        print(c("red", f"Fichier introuvable: {p}"))
        sys.exit(1)
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)

def list_dimensions() -> list[Path]:
    if not DIM_DIR.exists(): return []
    return sorted(DIM_DIR.glob("dimension_*.json"))

# ─── Game State ─────────────────────────────────────────────────────────

def init_game_state(dim: dict) -> dict:
    state = {}
    for quest in dim.get("quests", []):
        qid = quest.get("id", "")
        if not qid: continue
        steps = quest.get("steps", [])
        completed = {s["id"] for s in steps if s.get("completed")}
        current = None
        for s in steps:
            if s["id"] not in completed:
                current = s["id"]; break
        status = quest.get("status", "not_started")
        if not current and status == "not_started": status = "done"
        state[qid] = {"status": status, "current_step": current, "completed_steps": completed}
    return state

def complete_step(state: dict, quest_id: str, step_id: str) -> str:
    qs = state.get(quest_id)
    if not qs: return f"Quête '{quest_id}' introuvable."
    if step_id != qs["current_step"]: return f"L'étape '{step_id}' n'est pas l'étape courante ({qs['current_step']})."
    qs["completed_steps"].add(step_id)
    dim = _dimension_ref[0]
    quest = next((q for q in dim.get("quests", []) if q["id"] == quest_id), None)
    if quest:
        nxt = None
        for s in quest.get("steps", []):
            if s["id"] not in qs["completed_steps"]: nxt = s["id"]; break
        qs["current_step"] = nxt
        if not nxt: qs["status"] = "done"; return f"{c('green','✓')} Quête '{quest_id}' terminée !"
        return f"{c('green','✓')} {step_id} → {nxt}"
    return f"{c('green','✓')} {step_id}"

# ─── Filtrage ───────────────────────────────────────────────────────────

def filter_intentions(npc: dict, game_state: dict) -> list[dict]:
    matches = []
    for intent in npc.get("intentions", []):
        cond = intent.get("condition")
        if not cond or not isinstance(cond, dict): matches.append(intent); continue
        qid = cond.get("quest_id")
        if not qid: matches.append(intent); continue
        qs = game_state.get(qid)
        if not qs: continue
        if cond.get("quest_status") and cond["quest_status"] != qs["status"]: continue
        if cond.get("quest_step") and cond["quest_step"] != qs["current_step"]: continue
        matches.append(intent)
    return matches

# ─── Fallbacks ──────────────────────────────────────────────────────────

def get_fallback(npc: dict, dim: dict, key: str) -> str:
    t = (npc.get("fallbacks", {}) or {}).get(key, "") or (dim.get("global_fallbacks", {}) or {}).get(key, "")
    if key == "default_template" and t: t = t.replace("{name}", npc.get("name", npc.get("id", "?")))
    return t

# ─── Prompts ────────────────────────────────────────────────────────────

def build_system_prompt(npc: dict, intentions: list[dict], msg_count: int) -> str:
    L = []
    pers = npc.get("personality", {}) or {}
    speech = pers.get("speech", {})
    arc = pers.get("conversation_arc", [])

    L.append("Tu incarnes un PNJ de jeu vidéo. Incarne-le avec rigueur.")
    L.append(""); L.append("## IDENTITÉ")
    L.append(f"NOM : {npc.get('name', npc.get('id', '?'))}")
    if pers.get("backstory"): L.append(f"HISTOIRE : {pers['backstory']}")
    if pers.get("tone"): L.append(f"TEMPÉRAMENT : {pers['tone']}")

    if pers.get("emotional_state"): L.append(""); L.append("## ÉTAT ÉMOTIONNEL"); L.append(pers["emotional_state"])

    if speech:
        L.append(""); L.append("## COMMENT TU T'EXPRIMES (strict)")
        L.append(f"- {'Vouvoiement' if speech.get('vouvoiement') else 'Tutoiement'}.")
        if speech.get("vocatif"): L.append(f'- Tu appelles le joueur "{speech["vocatif"]}".')
        if speech.get("phrases"): L.append(f"- Longueur : {speech['phrases']}.")
        for e in speech.get("expressions", []): L.append(f"- {e}.")
        for i in speech.get("interdits", []): L.append(f"- INTERDIT : {i}.")

    if pers.get("knowledge"):
        L.append(""); L.append("## CE QUE TU SAIS")
        for k in pers["knowledge"]: L.append(f"- {k}")

    if pers.get("goals"):
        L.append(""); L.append("## TES OBJECTIFS")
        for g in pers["goals"]: L.append(f"- {g}")

    if arc:
        phase = _find_phase(arc, msg_count)
        if phase: L.append(""); L.append("## PHASE ACTUELLE"); L.append(phase.get("focus", ""))

    L.append(""); L.append("## SUJETS DE CONVERSATION")
    for intent in intentions:
        note = ""
        a = intent.get("action")
        if a and isinstance(a, dict): note = f" → ACTION: {a.get('description','')}"
        L.append(f'- [{intent.get("id","?")}] {intent.get("trigger","")}. Ex: "{intent.get("example","")}"{note}')

    L.append(""); L.append("## RÈGLES IMPÉRATIVES")
    L.append('- Format : {"text": "ta réponse", "action": null}')
    L.append('- Si correspond à une ACTION, inclus-la : {"text": "...", "action": {"type": "X", "id": "Y"}}')
    L.append("- Ne parle QUE de ce que tu sais. N'invente RIEN.")
    L.append("- Si hors-sujet, réponds EN RESTANT DANS LE PERSONNAGE.")
    L.append("- Pas d'astérisques, pas de narration. Que du dialogue.")
    L.append("- Reste cohérent avec l'historique.")

    if msg_count >= 4:
        for intent in intentions:
            a = intent.get("action")
            if a and isinstance(a, dict) and a.get("type") == "trigger":
                L.append(""); L.append("## ⚠️ URGENT — FIN DE CONVERSATION FORCÉE")
                L.append(f"Cela fait {msg_count} messages. Ce message est ton DERNIER.")
                L.append("Dis adieu et inclus ABSOLUMENT l'action."); break

    return "\n".join(L)

def build_user_prompt(history: list[dict], npc_name: str, msg: str) -> str:
    L = ["Historique de la conversation :"]
    disp = list(history)
    if disp and disp[-1]["role"] == "player": disp.pop()
    if not disp: L.append("(premier message)")
    else:
        for e in disp:
            r = "Joueur" if e["role"] == "player" else npc_name
            L.append(f"- {r} : {e['text']}")
    L.append(""); L.append(f'Dernier message : "{msg}"')
    L.append(""); L.append("Génère ta réponse (JSON uniquement).")
    return "\n".join(L)

def _find_phase(arc: list[dict], msg_count: int) -> dict | None:
    for p in arc:
        if msg_count <= p.get("until_message", 0): return p
    return None

# ─── Appel API ──────────────────────────────────────────────────────────

def call_openrouter(system_prompt: str, user_prompt: str) -> dict | None:
    if not OPENROUTER_API_KEY: return None
    import requests
    hdrs = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": SITE_URL, "X-OpenRouter-Title": SITE_NAME,
    }
    payload = {
        "model": MODEL, "temperature": TEMPERATURE, "max_tokens": MAX_TOKENS,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "response_format": {"type": "json_object"},
    }
    try:
        r = requests.post(OPENROUTER_URL, headers=hdrs, json=payload, timeout=REQUEST_TIMEOUT)
        if not r.ok:
            try: msg = r.json().get("error", {}).get("message", r.text[:200])
            except: msg = r.text[:200]
            print(f"\n  {c('red','❌')} API ({r.status_code}): {msg}"); return None
        return r.json()
    except requests.Timeout:
        print(f"\n  {c('yellow','⏱️')} Timeout."); return None
    except requests.RequestException as e:
        print(f"\n  {c('red','❌')} Réseau: {e}"); return None

# ─── Parsing ────────────────────────────────────────────────────────────

def extract_ai_response(api_response: dict | None) -> tuple[str | None, dict | None]:
    if not api_response: return None, None
    try:
        content = api_response["choices"][0]["message"]["content"].strip()
        data = json.loads(content)
        if isinstance(data, dict):
            return data.get("text"), data.get("action")
    except: pass
    return None, None

def validate_action(action: dict | None, npc: dict) -> dict | None:
    if not action or not isinstance(action, dict): return None
    at, aid = action.get("type",""), action.get("id","")
    if not at or not aid: return None
    for i in npc.get("intentions", []):
        a = i.get("action")
        if a and isinstance(a, dict) and a.get("type")==at and a.get("id")==aid:
            return {"type": at, "id": aid}
    return None

def simulate_response(npc: dict, intentions: list[dict], msg_count: int) -> tuple[str, dict | None]:
    if not intentions: return (get_fallback(npc, _dimension_ref[0] or {}, "default_template") or "..."), None
    txt = f"[SIMULÉ] {intentions[0].get('example', '...')}"
    action = None
    if msg_count >= 5:
        for i in intentions:
            a = i.get("action")
            if a and isinstance(a, dict) and a.get("type") == "trigger":
                action = {"type": a["type"], "id": a["id"]}; break
    return txt, action

# ─── Wizard ─────────────────────────────────────────────────────────────

def wizard_create_dimension():
    """Crée une nouvelle dimension interactivement."""
    print(f"\n  {c('bold',c('cyan','🧙 Wizard — Création de dimension'))}")
    print(f"  {c('dim','Répondez aux questions (Entrée = valeur par défaut)')}\n")

    # Meta
    did = _ask("  ID de la dimension", default="new_dimension", validate=lambda x: x.isidentifier())
    name = _ask("  Nom affiché", default=did.replace("_", " ").title())
    era = _ask("  Époque", default="???")
    desc = _ask("  Description (1 phrase)", default="")

    dim = {
        "meta": {"id": did, "name": name, "era": era, "description": desc, "completed": False},
        "npcs": [], "quests": [], "mini_games": [], "items": [],
        "global_fallbacks": {
            "off_topic": "Cette question n'a pas de sens ici. Concentre-toi sur ta quête.",
            "insult": "Tes insultes sont ignorées.",
            "timeout": "La connexion est rompue. Réessaie plus tard.",
            "unknown": "Je ne comprends pas. Peux-tu reformuler ?",
            "default_template": "Le PNJ te regarde sans comprendre. Que dis-tu ?"
        }
    }

    # PNJs
    print(f"\n  {c('bold','Ajout de PNJ')} (laisser le nom vide pour terminer)")
    while True:
        nid = _ask("    ID du PNJ (snake_case, vide = fini)", default="")
        if not nid: break
        nname = _ask("    Nom affiché", default=nid.replace("_", " ").title())
        tone = _ask("    Tempérament", default="neutre")
        backstory = _ask("    Backstory (1 phrase)", default="")
        emo = _ask("    État émotionnel", default="neutre")
        vouv = _ask("    Vouvoiement ? (o/n)", default="o").lower().startswith("o")
        voc = _ask("    Vocatif (ex: voyageur)", default="")
        phrases = _ask("    Longueur des réponses", default="2-3 phrases")
        goal = _ask("    Objectif principal", default="")

        npc = {
            "id": nid, "name": nname,
            "personality": {
                "tone": tone, "backstory": backstory,
                "emotional_state": emo,
                "speech": {
                    "vouvoiement": vouv, "vocatif": voc,
                    "phrases": phrases,
                    "expressions": [], "interdits": []
                },
                "knowledge": [],
                "goals": [goal] if goal else [],
                "conversation_arc": [
                    {"phase": 1, "until_message": 3, "focus": "accueillir et se présenter"},
                    {"phase": 2, "until_message": 99, "focus": "répondre aux questions"}
                ]
            },
            "intentions": [],
            "fallbacks": {
                "off_topic": "Restons concentrés sur l'essentiel.",
                "insult": "Je préfère ignorer ça.",
                "timeout": "Je ne t'entends plus...",
                "unknown": "Peux-tu répéter ?",
                "default_template": f"Je suis {nname}. Que veux-tu ?"
            }
        }

        # Intentions rapides
        print(f"    {c('dim','Intentions (laisser vide pour terminer)')}")
        while True:
            trigger = _ask("      Déclencheur (ex: le joueur salue)", default="")
            if not trigger: break
            example = _ask("      Exemple de réponse", default="...")
            has_action = _ask("      Action ? (type/id ou vide)", default="")
            action = None
            if has_action and "/" in has_action:
                at, aid = has_action.split("/", 1)
                action = {"type": at.strip(), "id": aid.strip(), "description": ""}
            iid = f"{nid}_{_slug(trigger[:30])}"
            npc["intentions"].append({
                "id": iid, "condition": None,
                "trigger": trigger, "example": example, "action": action
            })
            print(f"        {c('green','✓')} {iid}")

        if npc["intentions"]:
            dim["npcs"].append(npc)
            nint = len(npc["intentions"])
            print(f"    {c('green',f'✓ PNJ {nname} ajouté ({nint} intentions)')}")
        else:
            print(f"    {c('yellow','⚠️ PNJ sans intentions, ignoré')}")

    # Sauvegarde
    out = DIM_DIR / f"dimension_{did}.json"
    DIM_DIR.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(dim, f, ensure_ascii=False, indent=2)
    print(f"\n  {c('green',c('bold',f'✅ Dimension créée : {out}'))}")
    npc_count = len(dim["npcs"])
    print(f"  {c('dim',f'   {npc_count} PNJ(s), lancer avec :')}")
    print(f"  {c('cyan',f'   python distortion_dialogue.py {out}')}")
    return str(out)

def _ask(prompt: str, default: str = "", validate=None) -> str:
    d = f" [{c('dim',default)}]" if default else ""
    while True:
        v = input(f"{prompt}{d}: ").strip()
        if not v and default: return default
        if not v: continue
        if validate and not validate(v):
            print(f"  {c('red','Valeur invalide')}")
            continue
        return v

def _slug(text: str) -> str:
    import re
    t = text.lower().strip()
    t = re.sub(r'[^a-z0-9\s]', '', t)
    t = re.sub(r'\s+', '_', t)
    return t[:40]

# ─── Affichage ─────────────────────────────────────────────────────────

def print_header(dim: dict):
    m = dim.get("meta", {})
    print()
    print(f"  {c('bold',c('cyan','╔══ Distortion Dialogue Tester v3 ══╗'))}")
    print(f"  {c('bold',c('cyan','║'))} {c('bold',m.get('name','?'))} ({m.get('era','')})")
    key_status = c('green','✓ clé chargée') if OPENROUTER_API_KEY else c('yellow','⚠️ simulation (pas de clé)')
    print(f"  {c('bold',c('cyan','║'))} {key_status}  |  {MODEL}  |  temp={TEMPERATURE}")
    print(f"  {c('bold',c('cyan','╚══════════════════════════╝'))}")

def print_npc_list(dim: dict):
    npcs = dim.get("npcs", [])
    if not npcs:
        print(f"\n  {c('yellow','Aucun PNJ dans cette dimension.')}")
        return
    print(f"\n  {c('bold','PNJ disponibles')} :")
    for i, npc in enumerate(npcs, 1):
        nid = npc.get("id", "?")
        name = npc.get("name", nid)
        ni = len(npc.get("intentions", []))
        na = sum(1 for x in npc.get("intentions", []) if x.get("action"))
        print(f"    {c('cyan',str(i))}. {c('bold',name)} {c('dim',f'[{nid}]')}  {c('dim',f'({ni} intentions, {na} actions)')}")
    print()

def print_npc_detail(npc: dict, game_state: dict):
    pers = npc.get("personality", {})
    speech = pers.get("speech", {})
    name = npc.get("name", "?")
    nid = npc.get("id", "?")

    print(f"\n  {c('bold',c('magenta',f'╔═ {name} [{nid}] ')) + '═'*40}")
    print(f"  {c('magenta','║')} {c('dim','Tone:')} {pers.get('tone','—')}")
    if pers.get("emotional_state"):
        print(f"  {c('magenta','║')} {c('dim','État:')} {pers['emotional_state']}")
    if speech:
        v = "vouvoiement" if speech.get("vouvoiement") else "tutoiement"
        print(f"  {c('magenta','║')} {c('dim','Parle:')} {v}, vocatif={speech.get('vocatif','')}, {speech.get('phrases','')}")
    goals = pers.get("goals", [])
    if goals:
        print(f"  {c('magenta','║')} {c('dim','Objectifs:')}")
        for g in goals: print(f"  {c('magenta','║')}   • {g}")
    arc = pers.get("conversation_arc", [])
    if arc:
        print(f"  {c('magenta','║')} {c('dim','Arc:')}")
        for p in arc: print(f"  {c('magenta','║')}   msg ≤{p.get('until_message')}: {p.get('focus','')}")
    print(f"  {c('magenta','╚') + '═'*40}")

def print_state(game_state: dict, dim: dict):
    print(f"\n  {c('bold','┌─ État des quêtes ─')}")
    quests = dim.get("quests", [])
    if not quests: print(f"  │  {c('dim','Aucune quête.')}")
    else:
        for q in quests:
            qs = game_state.get(q["id"], {})
            icon = c('green','✓') if qs.get("status")=="done" else c('yellow','○')
            step = f" → {qs.get('current_step')}" if qs.get("current_step") else ""
            print(f"  │  {icon} {q['id']} [{qs.get('status','?')}]{step}")
            print(f"  │     {q.get('title', q['id'])}")
    print(f"  {c('bold','└────────────────────')}")

def print_history(history: list[dict], npc_name: str):
    if not history:
        print(f"  {c('dim','Historique vide.')}")
        return
    print(f"\n  {c('bold',f'┌─ Historique ({len(history)} msg) ─')}")
    for i, e in enumerate(history, 1):
        r = c('cyan','Joueur') if e["role"]=="player" else c('green',npc_name)
        txt = e["text"][:80] + ("..." if len(e["text"])>80 else "")
        print(f"  │ {c('dim',str(i))}. [{r}] {txt}")
    print(f"  {c('bold','└────────────────────────')}")

def print_help():
    print(textwrap.dedent(f"""
    {c('bold','Commandes')} :
      {c('cyan','/npc <id>')}         — Parler à un PNJ
      {c('cyan','/npc')}              — Choisir dans une liste
      {c('cyan','/list')}             — Lister tous les PNJ
      {c('cyan','/info')}             — Fiche détaillée du PNJ actuel
      {c('cyan','/state')}            — État des quêtes
      {c('cyan','/history')}          — Historique de la conversation
      {c('cyan','/step <qid> <sid>')} — Avancer une quête
      {c('cyan','/complete <qid>')}   — Terminer une quête
      {c('cyan','/reset <qid>')}      — Réinitialiser une quête
      {c('cyan','/action <type> <id>')} — Déclencher une action
      {c('cyan','/model <id>')}       — Changer de modèle
      {c('cyan','/key <apikey>')}     — Définir la clé API
      {c('cyan','/help')}             — Cette aide
      {c('cyan','/quit')}             — Quitter
    """))

# ─── Boucle interactive ────────────────────────────────────────────────

def interactive_loop(dim: dict):
    global _dimension_ref
    _dimension_ref[0] = dim
    gs = init_game_state(dim)
    npc = None
    history: list[dict] = []
    msg_count = 0

    print_header(dim)
    print_npc_list(dim)

    # Auto-sélection si 1 seul PNJ
    npcs = dim.get("npcs", [])
    if len(npcs) == 1:
        npc = npcs[0]
        print_npc_detail(npc, gs)
        print_state(gs, dim)
        name = npc.get("name", npc.get("id", "?"))
        print(f'\n  {c("bold",c("green",f"[{name}]"))} {c("dim","Que voulez-vous me dire ?")}')

    print(f'  {c("dim","Tapez /help pour les commandes, /npc <id> pour parler.")}')

    while True:
        try:
            raw = input(f"\n  {c('cyan','>')} ").strip()
        except (EOFError, KeyboardInterrupt):
            print(f"\n  {c('dim','Au revoir !')}")
            break
        if not raw: continue

        # Slash commands
        if raw.startswith("/"):
            parts = raw.split(maxsplit=2)
            cmd = parts[0].lower()
            args = parts[1:] if len(parts) > 1 else []

            if cmd in ("/quit", "/q"):
                print(f"  {c('dim','Au revoir !')}"); break
            elif cmd in ("/help", "/h", "/?"):
                print_help()
            elif cmd == "/list":
                print_npc_list(dim)
            elif cmd == "/state":
                print_state(gs, dim)
            elif cmd == "/history":
                print_history(history, npc.get("name","?") if npc else "PNJ")

            elif cmd == "/npc":
                if not args:
                    # Choisir dans la liste
                    npcs_list = dim.get("npcs", [])
                    if not npcs_list:
                        print(f"  {c('yellow','Aucun PNJ.')}"); continue
                    for i, n in enumerate(npcs_list, 1):
                        print(f"    {c('cyan',str(i))}. {n.get('name','?')} [{n.get('id','?')}]")
                    try:
                        choice = input(f"  {c('dim','Choix >')} ").strip()
                        if choice.isdigit():
                            idx = int(choice) - 1
                            if 0 <= idx < len(npcs_list):
                                args = [npcs_list[idx]["id"]]
                    except: pass
                    if not args:
                        print(f"  {c('yellow','/npc <id> ou numéro.')}"); continue
                nid = args[0]
                found = next((n for n in dim.get("npcs", []) if n["id"] == nid), None)
                if not found:
                    print(f'  {c("red","PNJ \'{nid}\' introuvable.")}'); continue
                npc = found; history.clear(); msg_count = 0
                print_npc_detail(npc, gs)
                print_state(gs, dim)
                print(f'\n  {c("bold",c("green",f"[{npc.get('name','?')}]"))} {c("dim","Que voulez-vous me dire ?")}')

            elif cmd == "/info":
                if not npc: print(f"  {c('yellow','/npc d abord.')}")
                else: print_npc_detail(npc, gs)

            elif cmd == "/step":
                if len(args) < 2: print(f"  {c('yellow','Usage: /step <quest_id> <step_id>')}"); continue
                print(f"  {complete_step(gs, args[0], args[1])}")

            elif cmd == "/complete":
                if not args: print(f"  {c('yellow','Usage: /complete <quest_id>')}"); continue
                if args[0] in gs:
                    gs[args[0]]["status"] = "done"
                    gs[args[0]]["current_step"] = None
                    print(f"  {c('green','✓')} {args[0]} → done")
                else: print(f'  {c("red","Quête '{args[0]}' introuvable.")}')

            elif cmd == "/reset":
                if not args: print(f"  {c('yellow','Usage: /reset <quest_id>')}"); continue
                q = next((q for q in dim.get("quests",[]) if q["id"]==args[0]), None)
                if q:
                    steps = q.get("steps",[])
                    gs[args[0]] = {"status":"not_started","current_step":steps[0]["id"] if steps else None,"completed_steps":set()}
                    print(f"  {c('green','↺')} {args[0]} réinitialisée.")
                else: print(f'  {c("red","Quête '{args[0]}' introuvable.")}')

            elif cmd == "/action":
                if not npc: print(f"  {c('yellow','/npc d abord.')}"); continue
                if len(args) < 2: print(f"  {c('yellow','Usage: /action <type> <id>')}"); continue
                v = validate_action({"type":args[0],"id":args[1]}, npc)
                if v: print(f"  {c('green','⚡')} Action déclenchée : {v['type']}/{v['id']}")
                else: print(f"  {c('red','❌')} Action invalide pour ce PNJ.")

            elif cmd == "/model":
                global MODEL
                if not args: print(f"  Modèle : {c('cyan',MODEL)}")
                else: MODEL = args[0]; print(f"  {c('green','✓')} Modèle → {MODEL}")

            elif cmd == "/key":
                global OPENROUTER_API_KEY
                if not args:
                    m = OPENROUTER_API_KEY[:8]+"..." if len(OPENROUTER_API_KEY)>8 else "(non définie)"
                    print(f"  Clé : {c('dim',m)}")
                else: OPENROUTER_API_KEY = args[0]; print(f"  {c('green','✓')} Clé mise à jour.")

            else:
                print(f"  {c('yellow',f'Commande inconnue : {cmd}')}  /help pour l'aide.")
            continue

        # Message joueur → dialogue
        if not npc:
            print(f'  {c("yellow","/npc <id> d abord pour parler.")}')
            continue

        msg_count += 1
        intentions = filter_intentions(npc, gs)
        if not intentions:
            fb = get_fallback(npc, dim, "default_template") or "..."
            name_fb = npc.get("name", "?")
            print(f"\n  {c('bold',c('green',f'[{name_fb}]'))} {fb}")
            continue

        name = npc.get("name", npc.get("id", "?"))
        history.append({"role": "player", "text": raw})
        while len(history) > MAX_HISTORY: history.pop(0)

        sys_prompt = build_system_prompt(npc, intentions, msg_count)
        usr_prompt = build_user_prompt(history, name, raw)

        api_resp = call_openrouter(sys_prompt, usr_prompt)

        if api_resp is not None:
            text, action = extract_ai_response(api_resp)
            if text is None: text = get_fallback(npc, dim, "unknown") or "..."
        else:
            text, action = simulate_response(npc, intentions, msg_count)

        valid_action = validate_action(action, npc)
        if not valid_action and msg_count >= 5:
            for i in intentions:
                a = i.get("action")
                if a and isinstance(a, dict) and a.get("type") == "trigger":
                    valid_action = {"type": a["type"], "id": a["id"]}
                    print(f"  {c('yellow','[system] ⚡ Action forcée après '+str(msg_count)+' messages')}")
                    break

        history.append({"role": "npc", "text": text})
        while len(history) > MAX_HISTORY: history.pop(0)

        print(f"\n  {c('bold',c('green',f'[{name}]'))} {text}")
        if valid_action:
            va_type = valid_action["type"]
            va_id = valid_action["id"]
            print(f"  {c('yellow',f'⚡ Action : {va_type}/{va_id}')}")
        api_info = c('green','live') if api_resp else c('yellow','simulé')
        print(f"  {c('dim',f'[msg #{msg_count} | {len(intentions)} int | {api_info}]')}")

# ─── AI Wizard ────────────────────────────────────────────────────────

AI_WIZARD_PROMPT = """Tu es un assistant de création de jeu vidéo. Ton rôle : interviewer le créateur
pour construire un fichier JSON de dimension (PNJ, quêtes, dialogues) étape par étape.

Tu poses DES QUESTIONS UNE PAR UNE. Chaque réponse te sert à remplir le JSON.

Étapes à suivre dans l'ordre :
1. Demander le nom de la dimension, l'époque, une courte description
2. Pour chaque PNJ (un par un, jusqu'à ce que le créateur dise "fini") :
   a. Nom, tempérament, backstory (1 phrase)
   b. État émotionnel
   c. Comment il parle (vouvoiement ? vocatif ? style ?)
   d. Ce qu'il sait (2-3 faits)
   e. Ses objectifs dans la conversation
   f. Les intentions (déclencheur + exemple de réponse, une par une)
   g. Y a-t-il une action spéciale ? (trigger)
3. Demander s'il y a des quêtes (étapes)
4. Proposer de sauvegarder

FORMAT DE RÉPONSE STRICT — tu réponds TOUJOURS en JSON :
{"text": "ta question ou commentaire", "data": { ... le JSON complet en cours ... }, "done": false}

Le champ "data" contient le JSON complet tel qu'il est pour l'instant.
Quand tout est fini, mets "done": true et le JSON complet dans "data".

Sois naturel, amical, enthousiaste. Pose des questions claires, une à la fois.
Suggère des valeurs par défaut quand c'est pertinent.
Si le créateur donne une réponse vague, demande des précisions.
Adapte-toi : si le créateur te donne beaucoup d'infos d'un coup, traite-les toutes."""

def wizard_ai():
    """Wizard conversationnel — l'IA pose les questions et construit le JSON."""
    if not OPENROUTER_API_KEY:
        print(f"\n  {c('red','❌ Clé API requise pour le wizard IA.')}")
        print(f"  {c('dim','Ajoute OPENROUTER_API_KEY=sk-... dans le .env')}")
        sys.exit(1)

    import requests
    print(f"\n  {c('bold',c('cyan','🤖 Wizard IA — Assistant de création de dimension'))}")
    print(f"  {c('dim','L IA va vous interviewer pour construire le JSON.')}")
    print(f"  {c('dim','Repondez naturellement. /quit pour arreter, /skip pour passer.')}\n")

    messages = [{"role": "system", "content": AI_WIZARD_PROMPT}]
    data = None

    while True:
        # Construire le user prompt
        parts = [{"role": "system", "content": AI_WIZARD_PROMPT}]
        parts.extend(messages[1:])  # skip system, keep history
        if not messages[1:]:
            parts.append({"role": "user", "content": "Bonjour ! Commençons la création d'une dimension. Quelle est la première question ?"})
            messages.append({"role": "user", "content": "Bonjour ! Commençons la création d'une dimension."})

        hdrs = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
            "HTTP-Referer": SITE_URL, "X-OpenRouter-Title": SITE_NAME,
        }
        payload = {
            "model": MODEL, "temperature": 0.8, "max_tokens": 1024,
            "messages": parts,
            "response_format": {"type": "json_object"},
        }

        try:
            r = requests.post(OPENROUTER_URL, headers=hdrs, json=payload, timeout=30)
            if not r.ok:
                print(f"\n  {c('red',f'❌ API error {r.status_code}')}")
                break
            resp = r.json()
            content = resp["choices"][0]["message"]["content"].strip()
            ai_msg = json.loads(content)
        except Exception as e:
            print(f"\n  {c('red',f'❌ Erreur: {e}')}")
            break

        text = ai_msg.get("text", "")
        data = ai_msg.get("data", {})
        done = ai_msg.get("done", False)

        print(f"\n  {c('cyan',c('bold','Assistant'))} : {text}")

        if done and data:
            # Sauvegarder
            meta = data.get("meta", {})
            did = meta.get("id", "nouvelle_dimension")
            out = DIM_DIR / f"dimension_{did}.json"
            DIM_DIR.mkdir(parents=True, exist_ok=True)
            with open(out, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"\n  {c('green',c('bold',f'✅ Dimension sauvegardée : {out}'))}")
            npc_count = len(data.get("npcs", []))
            quest_count = len(data.get("quests", []))
            print(f"  {c('dim',f'{npc_count} PNJ(s), {quest_count} quête(s)')}")
            print(f"  {c('dim',f'Lancer : python distortion_dialogue.py {out}')}")
            return str(out)

        try:
            user_input = input(f"\n  {c('yellow','Vous')} > ").strip()
        except (EOFError, KeyboardInterrupt):
            print(f"\n  {c('dim','Interrompu.')}")
            break

        if user_input.lower() in ("/quit", "/q"):
            # Sauvegarder même si pas fini
            if data:
                meta = data.get("meta", {})
                did = meta.get("id", "nouvelle_dimension")
                out = DIM_DIR / f"dimension_{did}.json"
                DIM_DIR.mkdir(parents=True, exist_ok=True)
                with open(out, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                print(f"\n  {c('yellow',f'💾 Sauvegarde partielle : {out}')}")
            break

        if user_input.lower() in ("/skip", "/s"):
            user_input = "(passe)"

        messages.append({"role": "assistant", "content": content})
        messages.append({"role": "user", "content": user_input})

        # Limiter l'historique
        if len(messages) > 20:
            messages = [messages[0]] + messages[-19:]


# ─── Main ───────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--ai":
        wizard_ai()
        return

    if len(sys.argv) >= 2 and sys.argv[1] == "--new":
        name = sys.argv[2] if len(sys.argv) > 2 else "ma_dimension"
        path = wizard_create_dimension()
        dim = load_dimension(path)
        interactive_loop(dim)
        return

    if len(sys.argv) >= 2:
        path = sys.argv[1]
    else:
        dims = list_dimensions()
        if not dims:
            print(f"\n  {c('yellow','Aucune dimension trouvée.')}")
            print(f"  {c('dim','Lancement du wizard de création...')}")
            path = wizard_create_dimension()
        elif len(dims) == 1:
            path = str(dims[0])
            print(f"\n  {c('dim',f'Auto-sélection : {dims[0].name}')}")
        else:
            print(f"\n  {c('bold','Dimensions disponibles')} :")
            for i, d in enumerate(dims, 1):
                print(f"    {c('cyan',str(i))}. {d.stem}")
            print(f"    {c('cyan','n')}. Nouvelle dimension (wizard manuel)")
            print(f"    {c('cyan','ai')}. Wizard IA (l'IA vous interviewe)")
            choice = input(f"\n  {c('dim','Choix >')} ").strip()
            if choice.lower() == 'n':
                path = wizard_create_dimension()
            elif choice.lower() == 'ai':
                path = wizard_ai()
                if not path: sys.exit(0)
            elif choice.isdigit():
                idx = int(choice) - 1
                if 0 <= idx < len(dims): path = str(dims[idx])
                else: print(c('red','Choix invalide.')); sys.exit(1)
            else:
                print(c('red','Choix invalide.')); sys.exit(1)

    dim = load_dimension(path)
    interactive_loop(dim)

if __name__ == "__main__":
    main()
