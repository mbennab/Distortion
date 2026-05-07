#!/usr/bin/env python3
"""
Distortion Dialogue Tester — Teste les dialogues d'une dimension via OpenRouter (Mistral).

Usage:
    python distortion_dialogue.py dimension_nuclear.json
    python distortion_dialogue.py /path/to/dimension_X.json

Nécessite requests : pip install requests
Clé API : export OPENROUTER_API_KEY=sk-... ou modifier OPENROUTER_API_KEY ligne 25
"""

import json
import os
import re
import sys
import textwrap
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "mistralai/ministral-3b-2512"
REQUEST_TIMEOUT = 15  # secondes

# Headers recommandés par OpenRouter
SITE_URL = os.environ.get("SITE_URL", "http://localhost:8000")
SITE_NAME = os.environ.get("SITE_NAME", "Distortion Dialogue Tester")

# IDs spéciaux que l'IA peut retourner
AI_SPECIAL_IDS = {"off_topic", "insult"}

# IDs gérés en local (sans appel API)
LOCAL_ONLY_IDS = {"timeout", "unknown"}

# ---------------------------------------------------------------------------
# Chargement du JSON
# ---------------------------------------------------------------------------

def load_dimension(path: str) -> dict:
    """Charge un fichier JSON de dimension."""
    p = Path(path)
    if not p.exists():
        print(f"Erreur : fichier introuvable — {p}")
        sys.exit(1)
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Game State (simulé)
# ---------------------------------------------------------------------------

def init_game_state(dim: dict) -> dict:
    """
    Construit l'état de partie initial à partir du JSON de dimension.
    Retourne un dict: quest_id -> {status, current_step, completed_steps}
    """
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
            # Toutes les étapes sont complétées mais statut pas mis à jour
            status = "done"
        state[qid] = {
            "status": status,
            "current_step": current,
            "completed_steps": completed,
        }
    return state


def quest_current_step(state: dict, quest_id: str) -> str | None:
    """Retourne l'étape courante d'une quête, ou None si terminée."""
    qs = state.get(quest_id)
    return qs["current_step"] if qs else None


def complete_step(state: dict, quest_id: str, step_id: str):
    """Marque une étape comme complétée et avance l'état."""
    qs = state.get(quest_id)
    if not qs:
        print(f"  Quête '{quest_id}' introuvable.")
        return
    if step_id != qs["current_step"]:
        print(f"  L'étape '{step_id}' n'est pas l'étape courante (actuelle: {qs['current_step']}).")
        return
    qs["completed_steps"].add(step_id)
    # Trouver la prochaine étape non complétée
    dim = _dimension_ref[0]  # hack pour accéder à la dimension depuis ici
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
            print(f"  ✓ Quête '{quest_id}' terminée !")
        else:
            print(f"  ✓ Étape '{step_id}' complétée → prochaine étape : {next_step}")


# Référence globale pour complete_step (évite de passer dim partout)
_dimension_ref = [None]


# ---------------------------------------------------------------------------
# Filtrage de la banque de dialogues
# ---------------------------------------------------------------------------

def filter_dialogue_bank(npc: dict, game_state: dict) -> list[dict]:
    """
    Retourne la liste des répliques du PNJ qui matchent l'état actuel
    de la partie.

    Règles :
    - condition entièrement null (quest_id, quest_status, quest_step)
      → réplique GÉNÉRIQUE, toujours incluse
    - quest_id défini + quest_status défini + quest_step null
      → inclus si le statut de la quête correspond
    - quest_id défini + quest_status null + quest_step défini
      → inclus si l'étape courante de la quête correspond
    - quest_id défini + quest_status défini + quest_step défini
      → inclus si les deux correspondent
    - quest_id défini, tout le reste null
      → inclus si la quête existe dans l'état (cas hybride)
    """
    matches = []
    for reply in npc.get("dialogue_bank", []):
        cond = reply.get("condition")
        if not cond or not isinstance(cond, dict):
            # Pas de condition → réplique générique
            matches.append(reply)
            continue

        qid = cond.get("quest_id")
        if not qid:
            # Pas de quête cible → générique
            matches.append(reply)
            continue

        qs_cond = cond.get("quest_status")      # None, "not_started", "done"
        qstep_cond = cond.get("quest_step")      # None ou step_id

        quest_state = game_state.get(qid)
        if quest_state is None:
            # Quête référencée mais pas dans l'état → ignorer
            continue

        # Vérifier quest_status
        if qs_cond and qs_cond != quest_state["status"]:
            continue

        # Vérifier quest_step
        if qstep_cond and qstep_cond != quest_state["current_step"]:
            continue

        matches.append(reply)

    return matches


# ---------------------------------------------------------------------------
# Fallbacks
# ---------------------------------------------------------------------------

def get_fallback(npc: dict, dim: dict, fallback_key: str) -> str:
    """
    Récupère un fallback : priorité PNJ, puis global.
    Remplace {name} par npc.name dans default_template.
    """
    npc_fb = npc.get("fallbacks", {}) or {}
    global_fb = dim.get("global_fallbacks", {}) or {}

    text = npc_fb.get(fallback_key, "") or global_fb.get(fallback_key, "")

    if fallback_key == "default_template" and text:
        text = text.replace("{name}", npc.get("name", npc.get("id", "?")))

    return text


# ---------------------------------------------------------------------------
# Construction du prompt
# ---------------------------------------------------------------------------

def build_prompt(npc: dict, replies: list[dict], player_message: str) -> tuple[str, str]:
    """
    Construit le system prompt et le user prompt pour OpenRouter.
    Retourne (system_content, user_content).

    Le system prompt = personality.prompt_context.
    Le user prompt = message du joueur + liste des id/intention (jamais les text).
    """
    personality = npc.get("personality", {}) or {}
    system_prompt = personality.get("prompt_context", "")

    lines = [f'Message du joueur : "{player_message}"', "", "Répliques disponibles :"]
    for r in replies:
        rid = r.get("id", "?")
        intention = r.get("intention", "")
        lines.append(f"- {rid} : {intention}")

    lines.append("")
    lines.append(
        "IMPORTANT : réponds UNIQUEMENT avec un objet JSON au format "
        '{"id": "<id_replique>"}. '
        "Si le message du joueur est hors-sujet, réponds "
        '{"id": "off_topic"}. '
        "Si le joueur est insultant ou agressif, réponds "
        '{"id": "insult"}. '
        "N'ajoute AUCUN autre texte avant ou après le JSON."
    )

    user_prompt = "\n".join(lines)
    return system_prompt, user_prompt


# ---------------------------------------------------------------------------
# Appel OpenRouter
# ---------------------------------------------------------------------------

def call_openrouter(system_prompt: str, user_prompt: str) -> dict | None:
    """Appelle l'API OpenRouter et retourne la réponse parsée, ou None si erreur."""
    if not OPENROUTER_API_KEY:
        print("\n  ⚠️  OPENROUTER_API_KEY non définie. Simulation locale...")
        return None

    import requests

    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
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
        "temperature": 0.1,
        "max_tokens": 128,
        "response_format": {"type": "json_object"},
    }

    try:
        resp = requests.post(OPENROUTER_URL, headers=headers, json=payload, timeout=REQUEST_TIMEOUT)
        if not resp.ok:
            try:
                err = resp.json()
                msg = err.get("error", {}).get("message", resp.text)
            except Exception:
                msg = resp.text[:200]
            print(f"\n  ❌ Erreur API OpenRouter ({resp.status_code}) : {msg}")
            return None
        return resp.json()
    except requests.Timeout:
        print("\n  ⏱️  Timeout de l'API OpenRouter.")
        return None
    except requests.RequestException as e:
        print(f"\n  ❌ Erreur réseau OpenRouter : {e}")
        return None


# ---------------------------------------------------------------------------
# Parsing de la réponse IA
# ---------------------------------------------------------------------------

def extract_reply_id(api_response: dict | None) -> str | None:
    """
    Extrait l'ID de réplique depuis la réponse OpenRouter.
    Gère le JSON structuré et tente un fallback regex.
    Retourne l'ID ou None.
    """
    if api_response is None:
        return None  # timeout

    try:
        choices = api_response.get("choices", [])
        if not choices:
            return None
        content = choices[0].get("message", {}).get("content", "").strip()
    except (KeyError, IndexError, AttributeError):
        return None

    # Essai 1 : parser le JSON complet
    try:
        data = json.loads(content)
        if isinstance(data, dict) and "id" in data:
            return data["id"]
    except json.JSONDecodeError:
        pass

    # Essai 2 : regex pour extraire {"id": "..."}
    m = re.search(r'"id"\s*:\s*"([^"]+)"', content)
    if m:
        return m.group(1)

    # Essai 3 : chercher un mot qui ressemble à un ID connu
    # (sera géré par l'appelant via le fallback unknown)

    return None


# ---------------------------------------------------------------------------
# Résolution finale de la réplique
# ---------------------------------------------------------------------------

def resolve_reply(
    reply_id: str | None,
    replies: list[dict],
    npc: dict,
    dim: dict,
    api_ok: bool,
) -> str:
    """
    Résout l'ID de réplique en texte final à afficher.
    Gère les fallbacks (off_topic, insult, timeout, unknown, default_template).
    """
    # Cas 1 : timeout API (ou pas de clé → simulation locale)
    if reply_id is None and not api_ok:
        if not OPENROUTER_API_KEY and replies:
            # Simulation locale : keyword matching basique
            return f"[SIMULÉ] {replies[0].get('text', '...')}"
        return get_fallback(npc, dim, "timeout") or "[Timeout] Aucune réponse."

    # Cas 2 : réponse invalide / ID inconnu
    if reply_id is None:
        return get_fallback(npc, dim, "unknown") or "[Erreur] ID de réplique introuvable."

    # Cas 3 : off_topic
    if reply_id == "off_topic":
        return get_fallback(npc, dim, "off_topic") or "[Hors-sujet] Le PNJ ne comprend pas."

    # Cas 4 : insult
    if reply_id == "insult":
        return get_fallback(npc, dim, "insult") or "[Insulte] Le PNJ est offensé."

    # Cas 5 : ID normal — chercher dans les répliques filtrées
    for r in replies:
        if r.get("id") == reply_id:
            return r.get("text", "[Texte manquant]")

    # Cas 6 : ID introuvable dans les répliques filtrées → chercher dans toute la banque
    for r in npc.get("dialogue_bank", []):
        if r.get("id") == reply_id:
            return r.get("text", "[Texte manquant]")

    # Cas 7 : ID vraiment inconnu
    return get_fallback(npc, dim, "unknown") or f"[Inconnu] ID '{reply_id}' non trouvé."


# ---------------------------------------------------------------------------
# Affichage
# ---------------------------------------------------------------------------

def print_state(game_state: dict, dim: dict):
    """Affiche l'état actuel des quêtes."""
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
            status_icon = "✓" if status == "done" else "○"
            step_info = f" → étape: {current}" if current else ""
            title = q.get("title", qid)
            print(f"  │  {status_icon} {qid} [{status}] {step_info}")
            print(f"  │     {title}")
    print("  └──────────────────────────────────────────────")


def print_npc_list(dim: dict):
    """Affiche la liste des PNJ disponibles."""
    npcs = dim.get("npcs", [])
    print("\n  PNJ disponibles :")
    for i, npc in enumerate(npcs, 1):
        nid = npc.get("id", "?")
        name = npc.get("name", nid)
        replies = len(npc.get("dialogue_bank", []))
        print(f"    {i}. {name} [{nid}]  ({replies} répliques)")


def print_help():
    """Affiche l'aide."""
    print(textwrap.dedent("""
    Commandes :
      /npc <id>       — Parler à un PNJ (ex: /npc npc_docteur_helene)
      /list            — Lister les PNJ disponibles
      /state           — Afficher l'état des quêtes
      /step <qid> <sid> — Compléter une étape de quête
      /complete <qid>  — Marquer une quête comme terminée
      /reset <qid>     — Réinitialiser une quête
      /model <id>      — Changer le modèle OpenRouter
      /key <apikey>    — Définir la clé API
      /help            — Cette aide
      /quit            — Quitter
    """))


# ---------------------------------------------------------------------------
# Boucle interactive
# ---------------------------------------------------------------------------

def interactive_loop(dim: dict):
    """Boucle principale interactive."""
    global _dimension_ref
    _dimension_ref[0] = dim
    game_state = init_game_state(dim)
    current_npc = None

    dim_name = dim.get("meta", {}).get("name", dim.get("meta", {}).get("id", "?"))
    dim_era = dim.get("meta", {}).get("era", "")
    print(f"\n  ╔══════════════════════════════════════════════╗")
    print(f"  ║  Distortion Dialogue Tester                 ║")
    print(f"  ║  Dimension : {dim_name} ({dim_era})".ljust(51) + "║")
    print(f"  ╚══════════════════════════════════════════════╝")
    print_npc_list(dim)
    print('\n  Tapez "/npc <id>" pour parler à un PNJ, ou "/help" pour les commandes.')

    while True:
        try:
            raw = input("\n  > ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n  Au revoir !")
            break

        if not raw:
            continue

        # Commandes slash
        if raw.startswith("/"):
            parts = raw.split(maxsplit=2)
            cmd = parts[0].lower()
            args = parts[1:] if len(parts) > 1 else []

            if cmd == "/quit" or cmd == "/q":
                print("  Au revoir !")
                break

            elif cmd == "/help" or cmd == "/h":
                print_help()

            elif cmd == "/list":
                print_npc_list(dim)

            elif cmd == "/state":
                print_state(game_state, dim)

            elif cmd == "/npc":
                if not args:
                    print("  Usage : /npc <id>")
                    continue
                npc_id = args[0]
                npc = next((n for n in dim.get("npcs", []) if n["id"] == npc_id), None)
                if npc is None:
                    print(f"  PNJ '{npc_id}' introuvable.")
                    continue
                current_npc = npc
                print(f"\n  🎭 Vous parlez maintenant à {npc.get('name', npc_id)} [{npc_id}]")
                print(f"     Tone : {npc.get('personality', {}).get('tone', '—')}")
                print_state(game_state, dim)
                print(f'\n  [{npc.get("name", npc_id)}] Que voulez-vous me dire ?')

            elif cmd == "/step":
                if len(args) < 2:
                    print("  Usage : /step <quest_id> <step_id>")
                    continue
                qid, sid = args[0], args[1]
                complete_step(game_state, qid, sid)

            elif cmd == "/complete":
                if not args:
                    print("  Usage : /complete <quest_id>")
                    continue
                qid = args[0]
                qs = game_state.get(qid)
                if qs:
                    qs["status"] = "done"
                    qs["current_step"] = None
                    print(f"  Quête '{qid}' marquée comme terminée.")
                else:
                    print(f"  Quête '{qid}' introuvable.")

            elif cmd == "/reset":
                if not args:
                    print("  Usage : /reset <quest_id>")
                    continue
                qid = args[0]
                quest = next((q for q in dim.get("quests", []) if q["id"] == qid), None)
                if quest:
                    game_state[qid] = {
                        "status": "not_started",
                        "current_step": quest["steps"][0]["id"] if quest.get("steps") else None,
                        "completed_steps": set(),
                    }
                    print(f"  Quête '{qid}' réinitialisée.")
                else:
                    print(f"  Quête '{qid}' introuvable.")

            elif cmd == "/model":
                global MODEL
                if not args:
                    print(f"  Modèle actuel : {MODEL}")
                else:
                    MODEL = args[0]
                    print(f"  Modèle changé : {MODEL}")

            elif cmd == "/key":
                global OPENROUTER_API_KEY
                if not args:
                    masked = OPENROUTER_API_KEY[:8] + "..." if len(OPENROUTER_API_KEY) > 8 else "(non définie)"
                    print(f"  Clé actuelle : {masked}")
                else:
                    OPENROUTER_API_KEY = args[0]
                    print("  Clé API mise à jour.")

            else:
                print(f"  Commande inconnue : {cmd}. Tapez /help pour l'aide.")

            continue

        # Message joueur → dialogue
        if current_npc is None:
            print('  Sélectionnez d\'abord un PNJ avec "/npc <id>".')
            continue

        # 1. Filtrer les répliques
        replies = filter_dialogue_bank(current_npc, game_state)

        if not replies:
            fallback = get_fallback(current_npc, dim, "default_template") or "..."
            print(f"\n  [{current_npc.get('name', '?')}] {fallback}")
            continue

        # 2. Construire le prompt
        system_prompt, user_prompt = build_prompt(current_npc, replies, raw)

        # 3. Appeler l'API
        api_response = call_openrouter(system_prompt, user_prompt)

        # 4. Extraire l'ID
        reply_id = extract_reply_id(api_response)

        # 5. Résoudre le texte final
        api_ok = api_response is not None
        final_text = resolve_reply(reply_id, replies, current_npc, dim, api_ok)

        # 6. Afficher
        npc_name = current_npc.get("name", current_npc.get("id", "?"))
        print(f"\n  [{npc_name}] {final_text}")

        # Debug (optionnel)
        if reply_id:
            print(f"  [debug] ID reçu : {reply_id}  |  {len(replies)} répliques filtrées")
        else:
            print(f"  [debug] Aucun ID reçu  |  {len(replies)} répliques filtrées")


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        # Chercher un JSON dans le dossier dimensions/
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
