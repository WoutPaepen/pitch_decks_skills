#!/usr/bin/env bash
#
# Sputnik Media - pitchdeck-nonscripted
# Installeert de skill en de tools die Antigravity en Claude nodig hebben (macOS).
#
# Gebruik:
#   curl -fsSL https://raw.githubusercontent.com/JOUW-GITHUB-NAAM/sputnik-pitchdeck-skill/main/install.sh | bash
#   of, in een gekloonde repo:  ./install.sh
#
# Opties:
#   --dry-run       Toon wat het script zou doen, zonder iets te veranderen
#   --ja            Beantwoord elke vraag met ja (geen vragen stellen)
#   --alleen-skill  Werk alleen de skill bij (geen tools installeren)
#   --help          Toon deze uitleg
#
# Het script installeert niets zonder te vragen, logt nergens in en vraagt geen wachtwoorden.

set -euo pipefail

# ---------------------------------------------------------------------------
# Instellingen. Pas REPO aan nadat je de repo op GitHub hebt gezet.
# ---------------------------------------------------------------------------
REPO="${PITCHDECK_REPO:-JOUW-GITHUB-NAAM/sputnik-pitchdeck-skill}"
BRANCH="${PITCHDECK_BRANCH:-main}"
SKILL_NAME="pitchdeck-nonscripted"
CANVA_MCP_URL="https://mcp.canva.com/mcp"
MIN_NODE_MAJOR=20

ANTIGRAVITY_APP_SKILLS="$HOME/.gemini/config/skills"
ANTIGRAVITY_CLI_SKILLS="$HOME/.gemini/antigravity-cli/skills"
ANTIGRAVITY_MCP_CONFIG="$HOME/.gemini/config/mcp_config.json"

URL_NODE="https://nodejs.org/en/download"
URL_CHROME="https://www.google.com/chrome/"
URL_ANTIGRAVITY="https://antigravity.google"
URL_CLAUDE_APP="https://claude.ai/download"
URL_CLAUDE_IN_CHROME="https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn"

DRY_RUN=0
ASSUME_YES=0
ONLY_SKILL=0

# ---------------------------------------------------------------------------
# Hulpfuncties
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_BOLD="$(printf '\033[1m')"; C_GREEN="$(printf '\033[32m')"
  C_YELLOW="$(printf '\033[33m')"; C_RED="$(printf '\033[31m')"; C_OFF="$(printf '\033[0m')"
else
  C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_OFF=""
fi

STATUS_LINES=""
TODO_LINES=""
TODO_COUNT=0

say()   { printf '%s\n' "$*"; }
title() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_OFF"; }
ok()    { printf '%s  ok%s  %s\n' "$C_GREEN" "$C_OFF" "$*"; }
warn()  { printf '%s  !%s   %s\n' "$C_YELLOW" "$C_OFF" "$*"; }
fail()  { printf '%s  x%s   %s\n' "$C_RED" "$C_OFF" "$*" >&2; }

status() { # $1 = klaar | ontbreekt | actie nodig, $2 = onderdeel
  STATUS_LINES="${STATUS_LINES}$(printf '  %-12s %s' "$1" "$2")
"
}

todo() { # voeg een stap toe aan de lijst met wat je zelf nog moet doen
  TODO_COUNT=$((TODO_COUNT + 1))
  TODO_LINES="${TODO_LINES}$(printf '  %d. %s' "$TODO_COUNT" "$*")
"
}

run() { # voer een commando uit, of toon het bij --dry-run
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '      (dry-run) %s\n' "$*"
  else
    "$@"
  fi
}

have_tty() { ( exec < /dev/tty ) 2>/dev/null; }

ask() { # $1 = vraag. Standaard ja. Geeft 0 bij ja.
  if [ "$ASSUME_YES" -eq 1 ]; then
    printf '  ?   %s [J/n] ja (--ja)\n' "$1"
    return 0
  fi
  if ! have_tty; then
    warn "Geen invoer mogelijk, overgeslagen: $1"
    return 1
  fi
  local answer=""
  printf '  ?   %s [J/n] ' "$1" > /dev/tty
  read -r answer < /dev/tty || answer=""
  case "$answer" in
    [nN]*) return 1 ;;
    *) return 0 ;;
  esac
}

open_url() { # vraag of een pagina geopend mag worden
  if ask "Open $1 in je browser?"; then
    if [ "$(uname -s)" = "Darwin" ] && command -v open >/dev/null 2>&1; then
      run open "$1" || say "      Kon de pagina niet openen. Open zelf: $1"
    else
      say "      Open zelf: $1"
    fi
  else
    say "      Later zelf openen: $1"
  fi
}

usage() {
  cat <<'TXT'
Sputnik Media - pitchdeck-nonscripted installeren (macOS)

Gebruik:
  curl -fsSL https://raw.githubusercontent.com/<github-naam>/sputnik-pitchdeck-skill/main/install.sh | bash
  of, in een gekloonde repo:  ./install.sh

Opties:
  --dry-run       Toon wat het script zou doen, zonder iets te veranderen
  --ja            Beantwoord elke vraag met ja
  --alleen-skill  Werk alleen de skill bij (geen tools installeren)
  --help          Toon deze uitleg

Opties doorgeven bij curl:  ... | bash -s -- --dry-run
TXT
}

# ---------------------------------------------------------------------------
# Opties
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --ja|-y|--yes) ASSUME_YES=1 ;;
    --alleen-skill) ONLY_SKILL=1 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Onbekende optie: $1 (gebruik --help)"; exit 2 ;;
  esac
  shift
done

if [ "$(uname -s)" != "Darwin" ] && [ "${PITCHDECK_ALLOW_NON_MACOS:-0}" != "1" ]; then
  fail "Dit script is gemaakt voor macOS. Volg op Windows of Linux de stappen in de README."
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pitchdeck-install.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

say "${C_BOLD}Sputnik Media: pitchdeck-nonscripted installeren${C_OFF}"
[ "$DRY_RUN" -eq 1 ] && say "Dry-run: er wordt niets veranderd."

# ---------------------------------------------------------------------------
# 1. De skill ophalen
# ---------------------------------------------------------------------------
title "1. De skill ophalen"

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

SKILL_SRC="$WORK_DIR/SKILL.md"
LOCAL_SKILL="$SCRIPT_DIR/skills/$SKILL_NAME/SKILL.md"

if [ -n "$SCRIPT_DIR" ] && [ -f "$LOCAL_SKILL" ]; then
  cp "$LOCAL_SKILL" "$SKILL_SRC"
  ok "Skill gevonden in de repo naast dit script."
else
  case "$REPO" in
    JOUW-GITHUB-NAAM/*)
      fail "REPO staat nog op de voorbeeldwaarde. Zet bovenaan install.sh de juiste GitHub-naam,"
      fail "of draai het script vanuit een gekloonde repo."
      exit 1
      ;;
  esac
  SKILL_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/skills/$SKILL_NAME/SKILL.md"
  if ! curl -fsSL "$SKILL_URL" -o "$SKILL_SRC"; then
    fail "Kon de skill niet downloaden van $SKILL_URL"
    exit 1
  fi
  ok "Skill gedownload van GitHub ($REPO)."
fi

if [ "$(head -n 1 "$SKILL_SRC")" != "---" ] || ! grep -q "^name: $SKILL_NAME\$" "$SKILL_SRC"; then
  fail "Het gedownloade bestand is geen geldige SKILL.md. Er is niets veranderd."
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Wat staat er al op deze Mac?
# ---------------------------------------------------------------------------
title "2. Controleren wat er al is"

find_app() { # $1 = naam van de app zonder .app
  local d
  for d in "/Applications" "$HOME/Applications"; do
    if [ -d "$d/$1.app" ]; then printf '%s' "$d/$1.app"; return 0; fi
  done
  return 1
}

BREW=""
for b in "$(command -v brew 2>/dev/null || true)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -n "$b" ] && [ -x "$b" ]; then BREW="$b"; break; fi
done

node_major() {
  command -v node >/dev/null 2>&1 || { printf '0'; return; }
  node -p 'process.versions.node.split(".")[0]' 2>/dev/null || printf '0'
}

HAS_ANTIGRAVITY_APP=0; find_app "Antigravity" >/dev/null && HAS_ANTIGRAVITY_APP=1
HAS_AGY=0
if command -v agy >/dev/null 2>&1 || [ -x "$HOME/.local/bin/agy" ] || [ -d "$HOME/.gemini/antigravity-cli" ]; then HAS_AGY=1; fi
HAS_CLAUDE_APP=0; find_app "Claude" >/dev/null && HAS_CLAUDE_APP=1
HAS_CHROME=0; find_app "Google Chrome" >/dev/null && HAS_CHROME=1

found() { # $1 = 1 of 0, $2 = tekst als gevonden, $3 = tekst als niet gevonden
  if [ "$1" -eq 1 ]; then ok "$2"; else warn "$3"; fi
}
found "$HAS_ANTIGRAVITY_APP" "Antigravity-app gevonden." "Antigravity-app niet gevonden."
if [ "$HAS_AGY" -eq 1 ]; then ok "Antigravity CLI (agy) gevonden."; else say "      Antigravity CLI (agy) niet gevonden; niet nodig als je de app gebruikt."; fi
found "$HAS_CLAUDE_APP" "Claude-app gevonden." "Claude-app niet gevonden (claude.ai in de browser kan ook)."
found "$HAS_CHROME" "Google Chrome gevonden." "Google Chrome niet gevonden."
if [ -n "$BREW" ]; then ok "Homebrew gevonden."; else say "      Homebrew niet gevonden."; fi
NODE_MAJOR="$(node_major)"
if [ "$NODE_MAJOR" -ge "$MIN_NODE_MAJOR" ]; then ok "Node.js $(node --version) gevonden."; else warn "Node.js $MIN_NODE_MAJOR of nieuwer niet gevonden."; fi

# ---------------------------------------------------------------------------
# 3. Ontbrekende tools installeren
# ---------------------------------------------------------------------------
if [ "$ONLY_SKILL" -eq 0 ]; then
  title "3. Ontbrekende tools"

  # Node.js: nodig voor browserbesturing in Antigravity (chrome-devtools-mcp).
  if [ "$NODE_MAJOR" -lt "$MIN_NODE_MAJOR" ]; then
    if [ -n "$BREW" ]; then
      if ask "Node.js installeren met Homebrew (nodig voor browserbesturing in Antigravity)?"; then
        run "$BREW" install node
        if [ "$DRY_RUN" -eq 0 ]; then
          eval "$("$BREW" shellenv)"
          NODE_MAJOR="$(node_major)"
        fi
      fi
    else
      warn "Installeer Node.js (de LTS-versie) via de installer van nodejs.org en draai dit script daarna opnieuw."
      open_url "$URL_NODE"
    fi
  fi
  if [ "$NODE_MAJOR" -ge "$MIN_NODE_MAJOR" ]; then
    status "klaar" "Node.js"
  else
    status "ontbreekt" "Node.js (nodig voor browserbesturing in Antigravity)"
    todo "Installeer Node.js (LTS) via $URL_NODE en draai dit script opnieuw."
  fi

  if [ "$HAS_CHROME" -eq 0 ]; then
    warn "Google Chrome is nodig voor browserbesturing."
    open_url "$URL_CHROME"
    status "ontbreekt" "Google Chrome"
    todo "Installeer Google Chrome via $URL_CHROME."
  else
    status "klaar" "Google Chrome"
  fi

  if [ "$HAS_ANTIGRAVITY_APP" -eq 0 ]; then
    warn "Installeer de Antigravity-app via de site van Google en open hem één keer."
    open_url "$URL_ANTIGRAVITY"
    todo "Installeer de Antigravity-app ($URL_ANTIGRAVITY), open hem één keer en draai dit script opnieuw."
  fi

  if [ "$HAS_CLAUDE_APP" -eq 0 ]; then
    if ask "Wil je de Claude desktop-app installeren? (Nee = je gebruikt claude.ai in de browser)"; then
      open_url "$URL_CLAUDE_APP"
      todo "Installeer de Claude desktop-app vanaf $URL_CLAUDE_APP en log in."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 4. Antigravity: skill en koppelingen
# ---------------------------------------------------------------------------
title "4. Antigravity"

install_skill() { # $1 = map met skills, $2 = label
  local dest="$1/$SKILL_NAME"
  if [ -f "$dest/SKILL.md" ] && cmp -s "$dest/SKILL.md" "$SKILL_SRC"; then
    ok "$2: skill is al up-to-date."
    return 0
  fi
  if [ -f "$dest/SKILL.md" ]; then
    run cp "$dest/SKILL.md" "$dest/SKILL.md.bak-$(date +%Y%m%d-%H%M%S)"
  fi
  run mkdir -p "$dest"
  run cp "$SKILL_SRC" "$dest/SKILL.md"
  if [ "$DRY_RUN" -eq 1 ]; then
    say "      $2: skill zou in $dest komen"
  else
    ok "$2: skill geplaatst in $dest"
  fi
}

install_skill "$ANTIGRAVITY_APP_SKILLS" "Antigravity-app"
status "klaar" "Skill voor de Antigravity-app"
if [ "$HAS_AGY" -eq 1 ]; then
  install_skill "$ANTIGRAVITY_CLI_SKILLS" "Antigravity CLI"
  status "klaar" "Skill voor de Antigravity CLI"
fi

if [ "$ONLY_SKILL" -eq 0 ]; then
  if [ "$NODE_MAJOR" -ge "$MIN_NODE_MAJOR" ]; then
    NPX_PATH="$(command -v npx || true)"
    NODE_DIR="$(dirname "$(command -v node)")"
    MERGE_JS="$WORK_DIR/merge-mcp.js"
    cat > "$MERGE_JS" <<'JS'
const fs = require("fs");
const [file, canvaUrl, npxPath, pathEnv, write] = process.argv.slice(2);
process.on("uncaughtException", (e) => { console.error("FOUT: " + e.message); process.exit(1); });
let cfg = {};
if (fs.existsSync(file)) {
  const raw = fs.readFileSync(file, "utf8").trim();
  if (raw) cfg = JSON.parse(raw);
}
if (typeof cfg !== "object" || cfg === null || Array.isArray(cfg)) {
  throw new Error("mcp_config.json is geen JSON-object");
}
if (typeof cfg.mcpServers !== "object" || cfg.mcpServers === null) cfg.mcpServers = {};
const added = [];
const kept = [];
if (cfg.mcpServers.canva) kept.push("canva");
else { cfg.mcpServers.canva = { serverUrl: canvaUrl }; added.push("canva"); }
if (npxPath) {
  if (cfg.mcpServers["chrome-devtools"]) kept.push("chrome-devtools");
  else {
    cfg.mcpServers["chrome-devtools"] = {
      command: npxPath,
      args: ["-y", "chrome-devtools-mcp@latest"],
      env: { PATH: pathEnv }
    };
    added.push("chrome-devtools");
  }
}
if (write === "1" && added.length > 0) {
  fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");
}
console.log(added.join(",") + "|" + kept.join(","));
JS
    MCP_PATH_ENV="$NODE_DIR:/usr/bin:/bin:/usr/sbin:/sbin"
    # Eerst kijken wat er zou veranderen, zonder te schrijven.
    if RESULT="$(node "$MERGE_JS" "$ANTIGRAVITY_MCP_CONFIG" "$CANVA_MCP_URL" "$NPX_PATH" "$MCP_PATH_ENV" 0 2>"$WORK_DIR/merge.err")"; then
      ADDED="${RESULT%%|*}"; KEPT="${RESULT#*|}"
      if [ -n "$ADDED" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
          say "      (dry-run) zou toevoegen aan $ANTIGRAVITY_MCP_CONFIG: $ADDED"
        else
          mkdir -p "$(dirname "$ANTIGRAVITY_MCP_CONFIG")"
          if [ -f "$ANTIGRAVITY_MCP_CONFIG" ]; then
            cp "$ANTIGRAVITY_MCP_CONFIG" "$ANTIGRAVITY_MCP_CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
          fi
          node "$MERGE_JS" "$ANTIGRAVITY_MCP_CONFIG" "$CANVA_MCP_URL" "$NPX_PATH" "$MCP_PATH_ENV" 1 >/dev/null
          ok "Toegevoegd aan $ANTIGRAVITY_MCP_CONFIG: $ADDED"
        fi
      fi
      if [ -n "$KEPT" ]; then ok "Stond er al (niet veranderd): $KEPT"; fi
      status "klaar" "Canva en browserbesturing in Antigravity (inloggen nog nodig)"
      todo "Antigravity: herstart de app. Ga naar Settings, Customizations, Installed MCP Servers. Klik bij canva op Authenticate, log in bij Canva in je browser, plak de code terug en bevestig."
    else
      fail "Kon $ANTIGRAVITY_MCP_CONFIG niet lezen: $(tail -n 1 "$WORK_DIR/merge.err")"
      warn "Het bestand is niet veranderd. Voeg de servers zelf toe (zie de README)."
      status "actie nodig" "MCP-instellingen van Antigravity (bestand is geen geldige JSON)"
      todo "Repareer $ANTIGRAVITY_MCP_CONFIG en draai dit script opnieuw."
    fi
  else
    warn "Zonder Node.js voegt het script alleen niets toe aan Antigravity. Voeg Canva zelf toe:"
    say "      Settings, Customizations, Installed MCP Servers, Add MCP, zoek Canva in de MCP Store."
    status "ontbreekt" "Koppelingen in Antigravity (Node.js nodig)"
    todo "Antigravity: voeg Canva toe via Settings, Customizations, Installed MCP Servers, Add MCP."
  fi
fi

# ---------------------------------------------------------------------------
# 5. Claude: ZIP voor de skill en de stappen in de app
# ---------------------------------------------------------------------------
title "5. Claude"

ZIP_DIR="$HOME/Downloads"; [ -d "$ZIP_DIR" ] || ZIP_DIR="$HOME"
ZIP_PATH="$ZIP_DIR/$SKILL_NAME.zip"
mkdir -p "$WORK_DIR/pkg/$SKILL_NAME"
cp "$SKILL_SRC" "$WORK_DIR/pkg/$SKILL_NAME/SKILL.md"
if [ "$DRY_RUN" -eq 1 ]; then
  say "      (dry-run) ZIP maken: $ZIP_PATH"
elif command -v ditto >/dev/null 2>&1; then
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$WORK_DIR/pkg/$SKILL_NAME" "$ZIP_PATH"
  ok "Skill klaargezet als ZIP: $ZIP_PATH"
elif command -v zip >/dev/null 2>&1; then
  rm -f "$ZIP_PATH"
  (cd "$WORK_DIR/pkg" && zip -qr "$ZIP_PATH" "$SKILL_NAME")
  ok "Skill klaargezet als ZIP: $ZIP_PATH"
else
  warn "Geen zip-programma gevonden; maak zelf een ZIP van de map $SKILL_NAME."
fi
status "actie nodig" "Skill in Claude (ZIP uploaden)"
todo "Claude: ga naar Instellingen (Settings), Capabilities. Zet 'Code execution and file creation' aan, klik bij Skills op 'Upload skill' en kies $ZIP_PATH."

if [ "$ONLY_SKILL" -eq 0 ]; then
  status "actie nodig" "Canva in Claude (connector verbinden)"
  todo "Claude: ga naar Instellingen (Settings), Connectors, kies Canva en klik op Verbinden. Log in bij Canva en geef toegang. Doe hetzelfde voor Google Drive als je Google Docs gebruikt."
  status "actie nodig" "Claude in Chrome (extensie)"
  todo "Claude: installeer de extensie Claude in Chrome en log in met je Claude-account: $URL_CLAUDE_IN_CHROME"
  if [ "$HAS_CHROME" -eq 1 ]; then
    open_url "$URL_CLAUDE_IN_CHROME"
  fi
  todo "Optioneel: zet in de Claude desktop-app computer use aan via Settings, General (onder Desktop app)."
fi

# ---------------------------------------------------------------------------
# 6. Samenvatting
# ---------------------------------------------------------------------------
title "Klaar"
say "Stand van zaken:"
printf '%s' "$STATUS_LINES"
if [ "$TODO_COUNT" -gt 0 ]; then
  say ""
  say "${C_BOLD}Wat je nu nog zelf doet:${C_OFF}"
  printf '%s' "$TODO_LINES"
fi
say ""
say "Een nieuwe versie van de skill? Draai dit script opnieuw (of met --alleen-skill)."
say "Antigravity gebruikt de nieuwe versie meteen; in Claude upload je de nieuwe ZIP opnieuw."
