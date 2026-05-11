#!/usr/bin/env python3
"""
Distortion Dialogue Tester v2 — Teste les dialogues via OpenRouter (génération libre + actions).

Le nouveau système envoie la fiche PNJ complète (personnalité, speech, goals, arc de conversation,
intentions avec exemples) et l'IA génère du texte libre + actions structurées.

Usage:
    python distortion_dialogue.py [dimension_nuclear.json]
    python distortion_dialogue.py /path/to/dimension_X.json

Clé API : export OPENROUTER_API_KEY=sk-... ou commande /key dans l'interface
"""

import json
import os
import sys
import textwrap
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = os.environ.get("MODEL", "mistralai/ministral-3b-2512")
REQUEST_TIMEOUT = 15
MAX_TOKENS = 256
TEMPERATURE = 0.7

SITE_URL = os.environ.get("SITE_URL", "http://localhost:8000")
SITE_NAME = os.environ.get("SITE_NAME", "Distortion Dialogue Tester v2")

MAX_HISTORY = 15

# Référence globale pour complete_step
_dimension_ref = [None]

# ---------------------------------------------------------------------------
# Chargement JSON
# ---------------------------------------------------------------------------

def load_dimension(path: str) -> dict:
    p = Path(path)
    if not p.exists():
        print(f"Erreur : fichier introuvable — {p}")
        sys.exit(1)
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Game State
# ---------------------------------------------------------------------------

def init_game_state(dim: dict) -> dict:
    state = {}
    for quest in dim.get("quests", []):
        qid = quest.get("id", "")
        if not qid:
            continue
        steps = quest.get("steps", [])
        completed = {s["id"] for s in steps if s.get("completed")}
        current = None
        for s in steps:
            if s["id"] not in completed:
                current = s["id"]
                break
        status = quest.get("status", "not_started")
        if not current and status == "not_started":
            status = "done"
        state[qid] = {
            "status": status,
            "current_step": current,
            "completed_steps": completed,
        }
    return state


def complete_step(state: dict, quest_id: str, step_id: str) -> str:
    qs = state.get(quest_id)
    if not qs:
        return f"Quête '{quest_id}' introuvable."
    if step_id != qs["current_step"]:
        return f"L'étape '{step_id}' n'est pas l'étape courante ({qs['current_step']})."
    qs["completed_steps"].add(step_id)
    dim = _dimension_ref[0]
    quest = next((q for q in dim.get("quests", []) if q["id"] == quest_id), None)
    if quest:
        next_step = None
        for s in quest.get("steps", []):
            if s["id"] not in qs["completed_steps"]:
                next_step = s["id"]
                break
        qs["current_step"] = next_step
        if not next_step:
            qs["status"] = "done"
            return f"✓ Quête '{quest_id}' terminée !"
        return f"✓ Étape '{step_id}' complétée → {next_step}"
    return f"✓ Étape '{step_id}' complétée."


# ---------------------------------------------------------------------------
# Filtrage des intentions (remplace filter_dialogue_bank)
# ---------------------------------------------------------------------------

def filter_intentions(npc: dict, game_state: dict) -> list[dict]:
    matches = []
    for intent in npc.get("intentions", []):
        cond = intent.get("condition")
        if not cond or not isinstance(cond, dict):
            matches.append(intent)
            continue
        qid = cond.get("quest_id")
        if not qid:
            matches.append(intent)
            continue
        qs = game_state.get(qid)
        if qs is None:
            continue
        qs_cond = cond.get("quest_status")
        if qs_cond and qs_cond != qs["status"]:
            continue
        qstep_cond = cond.get("quest_step")
        if qstep_cond and qstep_cond != qs["current_step"]:
            continue
        matches.append(intent)
    return matches


# ---------------------------------------------------------------------------
# Fallbacks
# ---------------------------------------------------------------------------

def get_fallback(npc: dict, dim: dict, key: str) -> str:
    npc_fb = npc.get("fallbacks", {}) or {}
    global_fb = dim.get("global_fallbacks", {}) or {}
    text = npc_fb.get(key, "") or global_fb.get(key, "")
    if key == "default_template" and text:
        text = text.replace("{name}", npc.get("name", npc.get("id", "?")))
    return text


# ---------------------------------------------------------------------------
# Construction des prompts (nouveau format riche)
# ---------------------------------------------------------------------------

def build_system_prompt(npc: dict, intentions: list[dict], msg_count: int) -> str:
    """Construit le system prompt complet avec la fiche PNJ enrichie."""
    lines = []
    pers = npc.get("personality", {}) or {}

    lines.append("Tu incarnes un PNJ de jeu vidéo. Incarne-le avec rigueur et naturel.")
    lines.append("")
    lines.append("## IDENTITÉ")
    lines.append("NOM : %s" % npc.get("name", npc.get("id", "?")))

    backstory = pers.get("backstory", "")
    if backstory:
        lines.append("HISTOIRE : %s" % backstory)

    tone = pers.get("tone", "")
    if tone:
        lines.append("TEMPÉRAMENT : %s" % tone)

    # État émotionnel
    emotional = pers.get("emotional_state", "")
    if emotional:
        lines.append("")
        lines.append("## ÉTAT ÉMOTIONNEL ACTUEL")
        lines.append(emotional)

    # Speech rules
    speech = pers.get("speech", {})
    if speech:
        lines.append("")
        lines.append("## COMMENT TU T'EXPRIMES (strict)")
        if speech.get("vouvoiement"):
            lines.append("- Tu vouvoies TOUJOURS.")
        else:
            lines.append("- Tu tutoies.")
        voc = speech.get("vocatif", "")
        if voc:
            lines.append('- Tu appelles le joueur "%s".' % voc)
        phrases = speech.get("phrases", "")
        if phrases:
            lines.append("- Longueur : %s." % phrases)
        for expr in speech.get("expressions", []):
            lines.append("- %s." % expr)
        for interd in speech.get("interdits", []):
            lines.append("- INTERDIT : %s." % interd)

    # Connaissances
    knowledge = pers.get("knowledge", [])
    if knowledge:
        lines.append("")
        lines.append("## CE QUE TU SAIS")
        for k in knowledge:
            lines.append("- %s" % k)

    # Objectifs
    goals = pers.get("goals", [])
    if goals:
        lines.append("")
        lines.append("## TES OBJECTIFS")
        for g in goals:
            lines.append("- %s" % g)

    # Arc de conversation
    arc = pers.get("conversation_arc", [])
    if arc:
        phase = _find_phase(arc, msg_count)
        if phase:
            lines.append("")
            lines.append("## PHASE ACTUELLE")
            lines.append("Tu es ici : %s" % phase.get("focus", "conversation normale"))

    # Intentions disponibles
    lines.append("")
    lines.append("## SUJETS DE CONVERSATION")
    for intent in intentions:
        iid = intent.get("id", "?")
        trigger = intent.get("trigger", "")
        example = intent.get("example", "")
        action = intent.get("action")
        note = ""
        if action and isinstance(action, dict):
            desc = action.get("description", "")
            note = " → ACTION: %s" % desc
        lines.append('- [%s] %s. Ex: "%s"%s' % (iid, trigger, example, note))

    # Règles
    lines.append("")
    lines.append("## RÈGLES IMPÉRATIVES")
    lines.append('- Format : {"text": "ta réponse", "action": null}')
    lines.append('- Si la situation correspond à une ACTION, inclus-la : {"text": "...", "action": {"type": "X", "id": "Y"}}')
    lines.append("- Ne parle QUE de ce que tu sais (voir CE QUE TU SAIS). N'invente RIEN.")
    lines.append("- Si hors-sujet ou insultant, réponds EN RESTANT DANS LE PERSONNAGE.")
    lines.append("- Pas d'astérisques, pas de narration. Que du dialogue.")
    lines.append("- Reste cohérent avec l'historique.")

    # Forçage terminaison
    if msg_count >= 4:
        for intent in intentions:
            action = intent.get("action")
            if action and isinstance(action, dict) and action.get("type") == "trigger":
                lines.append("")
                lines.append("## ⚠️ URGENT — FIN DE CONVERSATION FORCÉE")
                lines.append("Cela fait %d messages. Ce message est ton DERNIER." % msg_count)
                lines.append("Dis adieu et inclus ABSOLUMENT l'action.")
                lines.append("Ne parle plus d'autre chose.")
                break

    return "\n".join(lines)


def build_user_prompt(history: list[dict], npc_name: str, player_message: str) -> str:
    """Construit le user prompt avec l'historique de conversation."""
    lines = ["Historique de la conversation :"]
    display = list(history)
    if display and display[-1]["role"] == "player":
        display.pop()
    if not display:
        lines.append("(premier message)")
    else:
        for entry in display:
            role = "Joueur" if entry["role"] == "player" else npc_name
            lines.append("- %s : %s" % (role, entry["text"]))
    lines.append("")
    lines.append('Dernier message du joueur : "%s"' % player_message)
    lines.append("")
    lines.append("Génère ta réponse (JSON uniquement).")
    return "\n".join(lines)


def _find_phase(arc: list[dict], msg_count: int) -> dict | None:
    for p in arc:
        if msg_count <= p.get("until_message", 0):
            return p
    return None


# ---------------------------------------------------------------------------
# Appel OpenRouter
# ---------------------------------------------------------------------------

def call_openrouter(system_prompt: str, user_prompt: str) -> dict | None:
    if not OPENROUTER_API_KEY:
        print("\n  ⚠️  OPENROUTER_API_KEY non définie. Simulation locale...")
        return None

    import requests

    headers = {
        "Authorization": "Bearer %s" % OPENROUTER_API_KEY,
        "Content-Type": "application/json",
        "HTTP-Referer": SITE_URL,
        "X-OpenRouter-Title": SITE_NAME,
    }

    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": TEMPERATURE,
        "max_tokens": MAX_TOKENS,
        "response_format": {"type": "json_object"},
    }

    try:
        resp = requests.post(OPENROUTER_URL, headers=headers, json=payload, timeout=REQUEST_TIMEOUT)
        if not resp.ok:
            try:
                err = resp.json()
                msg = err.get("error", {}).get("message", resp.text[:200])
            except Exception:
                msg = resp.text[:200]
            print("\n  ❌ Erreur API (%d) : %s" % (resp.status_code, msg))
            return None
        return resp.json()
    except requests.Timeout:
        print("\n  ⏱️  Timeout API.")
        return None
    except requests.RequestException as e:
        print("\n  ❌ Erreur réseau : %s" % e)
        return None


# ---------------------------------------------------------------------------
# Parsing réponse IA (nouveau format JSON)
# ---------------------------------------------------------------------------

def extract_ai_response(api_response: dict | None) -> tuple[str | None, dict | None]:
    """
    Extrait le texte et l'action depuis la réponse OpenRouter.
    Format attendu : {"text": "...", "action": null|{"type":"X","id":"Y"}}
    Retourne (text, action_dict).
    """
    if api_response is None:
        return None, None

    try:
        choices = api_response.get("choices", [])
        if not choices:
            return None, None
        content = choices[0].get("message", {}).get("content", "").strip()
    except (KeyError, IndexError, AttributeError):
        return None, None

    try:
        data = json.loads(content)
        if isinstance(data, dict):
            text = data.get("text", "")
            action = data.get("action")
            if action and isinstance(action, dict):
                return text, action
            return text, None
    except json.JSONDecodeError:
        pass

    return None, None


def validate_action(action: dict | None, npc: dict) -> dict | None:
    """Valide que l'action (type, id) existe dans les intentions du PNJ."""
    if not action or not isinstance(action, dict):
        return None
    atype = action.get("type", "")
    aid = action.get("id", "")
    if not atype or not aid:
        return None
    for intent in npc.get("intentions", []):
        ia = intent.get("action")
        if ia and isinstance(ia, dict):
            if ia.get("type") == atype and ia.get("id") == aid:
                return {"type": atype, "id": aid}
    return None


# ---------------------------------------------------------------------------
# Simulation locale (quand pas de clé API)
# ---------------------------------------------------------------------------

def simulate_response(npc: dict, intentions: list[dict], msg_count: int) -> tuple[str, dict | None]:
    """Simule une réponse PNJ basée sur la première intention + l'arc de conversation."""
    if not intentions:
        return get_fallback(npc, _dimension_ref[0] or {}, "default_template") or "...", None

    intent = intentions[0]
    text = intent.get("example", "...")

    # Forçage action en simulation
    action = None
    if msg_count >= 5:
        for i in intentions:
            a = i.get("action")
            if a and isinstance(a, dict) and a.get("type") == "trigger":
                action = {"type": a["type"], "id": a["id"]}
                break

    return "[SIMULÉ] %s" % text, action


# ---------------------------------------------------------------------------
# Affichage
# ---------------------------------------------------------------------------

def print_state(game_state: dict, dim: dict):
    print("\n  ┌─ État des quêtes ─────────────────────────────")
    quests = dim.get("quests", [])
    if not quests:
        print("  │  Aucune quête.")
    else:
        for q in quests:
            qid = q["id"]
            qs = game_state.get(qid, {})
            status = qs.get("status", "?")
            current = qs.get("current_step")
            icon = "✓" if status == "done" else "○"
            step = " → %s" % current if current else ""
            print("  │  %s %s [%s]%s" % (icon, qid, status, step))
            print("  │     %s" % q.get("title", qid))
    print("  └──────────────────────────────────────────────")


def print_npc_list(dim: dict):
    npcs = dim.get("npcs", [])
    print("\n  PNJ disponibles :")
    for i, npc in enumerate(npcs, 1):
        nid = npc.get("id", "?")
        name = npc.get("name", nid)
        nint = len(npc.get("intentions", []))
        actions = sum(1 for x in npc.get("intentions", []) if x.get("action"))
        print("    %d. %s [%s]  (%d intentions, %d actions)" % (i, name, nid, nint, actions))


def print_npc_detail(npc: dict, game_state: dict):
    """Affiche la fiche complète d'un PNJ."""
    pers = npc.get("personality", {})
    speech = pers.get("speech", {})
    print("\n  ╔═ %s [%s] ═══════════════════════" % (npc.get("name", "?"), npc.get("id", "?")))
    print("  ║ Tone: %s" % pers.get("tone", "—"))
    print("  ║ État: %s" % pers.get("emotional_state", "—"))
    if speech:
        v = "vouvoiement" if speech.get("vouvoiement") else "tutoiement"
        print("  ║ Parle: %s, vocatif='%s', phrases=%s" % (
            v, speech.get("vocatif", ""), speech.get("phrases", "—")))
    goals = pers.get("goals", [])
    if goals:
        print("  ║ Objectifs:")
        for g in goals:
            print("  ║   • %s" % g)
    print("  ╚══════════════════════════════════")


def cmd_help():
    print(textwrap.dedent("""
    Commandes :
      /npc <id>        — Parler à un PNJ
      /info            — Fiche détaillée du PNJ actuel
      /list            — Lister tous les PNJ
      /state           — Afficher l'état des quêtes
      /step <qid> <sid> — Compléter une étape
      /complete <qid>  — Terminer une quête
      /reset <qid>     — Réinitialiser une quête
      /action <type> <id> — Forcer une action manuellement
      /history         — Afficher l'historique
      /model <id>      — Changer le modèle
      /key <apikey>    — Définir la clé API
      /help            — Cette aide
      /quit            — Quitter
    """))


# ---------------------------------------------------------------------------
# Boucle interactive
# ---------------------------------------------------------------------------

def interactive_loop(dim: dict):
    global _dimension_ref
    _dimension_ref[0] = dim

    game_state = init_game_state(dim)
    current_npc = None
    history: list[dict] = []
    msg_count = 0

    meta = dim.get("meta", {})
    print("\n  ╔══════════════════════════════════════════════╗")
    print("  ║  Distortion Dialogue Tester v2               ║")
    print("  ║  IA libre + actions structurées              ║")
    print("  ║  %s (%s)".ljust(51) % (meta.get("name", "?"), meta.get("era", "")) + "║")
    print("  ╚══════════════════════════════════════════════╝")
    print_npc_list(dim)
    print('\n  Tapez "/npc <id>" pour parler à un PNJ.')

    while True:
        try:
            raw = input("\n  > ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n  Au revoir !")
            break

        if not raw:
            continue

        if raw.startswith("/"):
            parts = raw.split(maxsplit=2)
            cmd = parts[0].lower()
            args = parts[1:] if len(parts) > 1 else []

            if cmd in ("/quit", "/q"):
                print("  Au revoir !")
                break

            elif cmd in ("/help", "/h"):
                cmd_help()

            elif cmd == "/list":
                print_npc_list(dim)

            elif cmd == "/state":
                print_state(game_state, dim)

            elif cmd == "/npc":
                if not args:
                    print("  Usage : /npc <id>")
                    continue
                npc = next((n for n in dim.get("npcs", []) if n["id"] == args[0]), None)
                if npc is None:
                    print("  PNJ '%s' introuvable." % args[0])
                    continue
                current_npc = npc
                history.clear()
                msg_count = 0
                print_npc_detail(npc, game_state)
                print_state(game_state, dim)
                print('\n  [%s] Que voulez-vous me dire ?' % npc.get("name", npc.get("id", "?")))

            elif cmd == "/info":
                if current_npc is None:
                    print("  Aucun PNJ sélectionné.")
                else:
                    print_npc_detail(current_npc, game_state)

            elif cmd == "/step":
                if len(args) < 2:
                    print("  Usage : /step <quest_id> <step_id>")
                    continue
                result = complete_step(game_state, args[0], args[1])
                print("  %s" % result)

            elif cmd == "/complete":
                if not args:
                    print("  Usage : /complete <quest_id>")
                    continue
                qs = game_state.get(args[0])
                if qs:
                    qs["status"] = "done"
                    qs["current_step"] = None
                    print("  Quête '%s' → done." % args[0])
                else:
                    print("  Quête '%s' introuvable." % args[0])

            elif cmd == "/reset":
                if not args:
                    print("  Usage : /reset <quest_id>")
                    continue
                quest = next((q for q in dim.get("quests", []) if q["id"] == args[0]), None)
                if quest:
                    steps = quest.get("steps", [])
                    game_state[args[0]] = {
                        "status": "not_started",
                        "current_step": steps[0]["id"] if steps else None,
                        "completed_steps": set(),
                    }
                    print("  Quête '%s' réinitialisée." % args[0])
                else:
                    print("  Quête '%s' introuvable." % args[0])

            elif cmd == "/action":
                if current_npc is None:
                    print("  Sélectionnez d'abord un PNJ.")
                    continue
                if len(args) < 2:
                    print("  Usage : /action <type> <id>")
                    continue
                atype, aid = args[0], args[1]
                valid = validate_action({"type": atype, "id": aid}, current_npc)
                if valid:
                    print("  ⚡ Action déclenchée : %s/%s" % (atype, aid))
                else:
                    print("  ❌ Action invalide : %s/%s (absente des intentions du PNJ)" % (atype, aid))

            elif cmd == "/history":
                if not history:
                    print("  Historique vide.")
                else:
                    print("\n  ┌─ Historique (%d entrées) ───────" % len(history))
                    for i, entry in enumerate(history):
                        role = "Joueur" if entry["role"] == "player" else current_npc.get("name", "PNJ") if current_npc else "PNJ"
                        print("  │ %d. [%s] %s" % (i + 1, role, entry["text"]))
                    print("  └────────────────────────────────")

            elif cmd == "/model":
                global MODEL
                if not args:
                    print("  Modèle : %s" % MODEL)
                else:
                    MODEL = args[0]
                    print("  Modèle → %s" % MODEL)

            elif cmd == "/key":
                global OPENROUTER_API_KEY
                if not args:
                    m = OPENROUTER_API_KEY[:8] + "..." if len(OPENROUTER_API_KEY) > 8 else "(non définie)"
                    print("  Clé : %s" % m)
                else:
                    OPENROUTER_API_KEY = args[0]
                    print("  Clé mise à jour.")

            else:
                print("  Commande inconnue : %s. /help pour l'aide." % cmd)

            continue

        # --- Message joueur → dialogue ---
        if current_npc is None:
            print('  Sélectionnez un PNJ avec "/npc <id>".')
            continue

        msg_count += 1

        # Filtrer les intentions
        intentions = filter_intentions(current_npc, game_state)
        if not intentions:
            fb = get_fallback(current_npc, dim, "default_template") or "..."
            print("\n  [%s] %s" % (current_npc.get("name", "?"), fb))
            continue

        # Ajouter message joueur à l'historique
        history.append({"role": "player", "text": raw})
        while len(history) > MAX_HISTORY:
            history.pop(0)

        npc_name = current_npc.get("name", current_npc.get("id", "?"))

        # Construire les prompts
        system_prompt = build_system_prompt(current_npc, intentions, msg_count)
        user_prompt = build_user_prompt(history, npc_name, raw)

        # Appeler l'API (ou simuler)
        api_response = call_openrouter(system_prompt, user_prompt)

        # Extraire la réponse
        if api_response is not None:
            text, action = extract_ai_response(api_response)
            if text is None:
                text = get_fallback(current_npc, dim, "unknown") or "..."
        else:
            text, action = simulate_response(current_npc, intentions, msg_count)

        # Valider l'action
        valid_action = validate_action(action, current_npc)

        # Forçage action après 5 messages
        if not valid_action and msg_count >= 5:
            for intent in intentions:
                ia = intent.get("action")
                if ia and isinstance(ia, dict) and ia.get("type") == "trigger":
                    valid_action = {"type": ia["type"], "id": ia["id"]}
                    print("  [system] ⚡ Action forcée après %d messages" % msg_count)
                    break

        # Ajouter réponse à l'historique
        history.append({"role": "npc", "text": text})
        while len(history) > MAX_HISTORY:
            history.pop(0)

        # Afficher
        print("\n  [%s] %s" % (npc_name, text))
        if valid_action:
            print("  ⚡ Action : %s/%s" % (valid_action["type"], valid_action["id"]))
        print("  [debug] msg #%d | %d intentions filtrées | temp=%.1f max_tokens=%d" % (
            msg_count, len(intentions), TEMPERATURE, MAX_TOKENS))


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        default = Path(__file__).parent / "dimensions" / "dimension_nuclear.json"
        if default.exists():
            path = str(default)
        else:
            print("Usage : python distortion_dialogue.py <fichier_dimension.json>")
            sys.exit(1)
    else:
        path = sys.argv[1]

    dim = load_dimension(path)
    interactive_loop(dim)


if __name__ == "__main__":
    main()
