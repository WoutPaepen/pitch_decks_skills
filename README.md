# pitch_decks_skills

Installatiescript voor de Sputnik-skill `pitchdeck-nonscripted` op macOS. De skill helpt de unscripted developer om van een idee een eerste versie van een pitchdeck in Canva te maken: briefing, onderzoek, drie invalshoeken en dan de draft. Titel, hook en talent blijven bij de developer.

De skill zelf staat niet in deze repo. Je krijgt het bestand `SKILL.md` van de AI producer. Dit script zet het op de juiste plaatsen en installeert de tools die Antigravity en Claude ervoor nodig hebben.

## Installeren: de agent doet het

Je hoeft geen Terminal te openen.

**In Antigravity (of Claude Code):**

1. Sleep het bestand `SKILL.md` in een gesprek met de agent.
2. Typ: "Installeer deze skill."
3. De agent legt uit wat er gebeurt en vraagt je akkoord. Daarna voert hij dit installatiescript uit.
4. Doe de stappen uit het lijstje dat de agent je op het einde geeft, zoals inloggen bij Canva.

**In de Claude-app of op claude.ai:** Claude draait daar niet op je Mac, dus het script kan daar niet lopen. Voeg `SKILL.md` toe aan een gesprek en typ "Installeer deze skill". Claude maakt een ZIP en helpt je die te uploaden, en helpt je Canva en Claude in Chrome te koppelen.

## Zelf in Terminal (als reserve)

Zet `SKILL.md` in je map Downloads, open Terminal en plak:

```bash
curl -fsSL https://raw.githubusercontent.com/WoutPaepen/pitch_decks_skills/main/install.sh | bash
```

Wil je eerst zien wat het script doet, zonder iets te veranderen?

```bash
curl -fsSL https://raw.githubusercontent.com/WoutPaepen/pitch_decks_skills/main/install.sh | bash -s -- --dry-run
```

Het script vraagt toestemming voor elke installatie. Het logt nergens in en vraagt nooit om een wachtwoord. Vindt het geen `SKILL.md`, dan vraagt het je om het bestand in het Terminal-venster te slepen. Sla je dat over, dan installeert het alleen de tools.

## Wat het script doet

| Onderdeel | Wat het script doet | Wat je zelf nog doet |
| --- | --- | --- |
| Node.js | Installeert Node.js met Homebrew als die er is, anders opent het nodejs.org | Bij nodejs.org: de installer doorlopen |
| Google Chrome | Controleert of Chrome er is | Chrome installeren als het ontbreekt |
| Antigravity: skill | Zet de skill in `~/.gemini/config/skills/` (en in `~/.gemini/antigravity-cli/skills/` als je de CLI hebt) | Niets |
| Antigravity: Canva | Voegt de Canva-server toe aan `~/.gemini/config/mcp_config.json` | In de app op Authenticate klikken en inloggen bij Canva |
| Antigravity: browser | Voegt `chrome-devtools` toe aan hetzelfde bestand | In het Chrome-venster van de agent zelf inloggen bij Canva |
| Claude: skill | Maakt `~/Downloads/pitchdeck-nonscripted.zip` | De ZIP uploaden in Claude |
| Claude: Canva en browser | Opent de pagina van de extensie Claude in Chrome | De Canva-connector verbinden en de extensie installeren |

Bestaande instellingen blijven staan. Voor het script `mcp_config.json` of een skill aanpast, maakt het een reservekopie met `.bak-` en de datum in de naam.

## Na het script

**Antigravity**

1. Herstart de Antigravity-app.
2. Ga naar Settings, Customizations, Installed MCP Servers.
3. Klik bij canva op Authenticate, log in bij Canva in je browser, plak de code terug en bevestig.

**Claude** (betaald abonnement nodig: Pro, Max, Team of Enterprise)

1. Ga naar Instellingen (Settings), Capabilities. Zet "Code execution and file creation" aan.
2. Klik bij Skills op "Upload skill" en kies `pitchdeck-nonscripted.zip` uit je map Downloads.
3. Ga naar Instellingen, Connectors. Kies Canva en klik op Verbinden. Log in bij Canva en geef toegang.
4. Installeer de extensie [Claude in Chrome](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn) en log in met je Claude-account.
5. Optioneel: zet in de Claude desktop-app computer use aan via Settings, General.

Op een Team- of Enterprise-plan moet een beheerder skills en code execution soms eerst aanzetten.

## Een nieuwe versie van de skill

Geef de nieuwe `SKILL.md` aan de agent en vraag "Werk deze skill bij." Of zet hem in je map Downloads en plak in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/WoutPaepen/pitch_decks_skills/main/install.sh | bash -s -- --alleen-skill
```

Het script neemt de nieuwste `SKILL.md` die het vindt. Antigravity gebruikt de nieuwe versie meteen. In Claude upload je de nieuwe ZIP opnieuw.

## Opties

| Optie | Wat het doet |
| --- | --- |
| `--agent` | Voor agents: stelt geen vragen, opent geen pagina's en eindigt met een lijst voor de gebruiker. De agent vraagt eerst zelf akkoord in het gesprek |
| `--skill PAD` | Gebruikt deze `SKILL.md` in plaats van zelf te zoeken |
| `--dry-run` | Toont wat het script zou doen, zonder iets te veranderen |
| `--ja` | Beantwoordt elke vraag met ja |
| `--alleen-skill` | Werkt alleen de skill bij |
| `--help` | Toont de uitleg |

Opties zet je achter `bash -s --`, bijvoorbeeld `... | bash -s -- --skill ~/Desktop/SKILL.md`.

## Privacy

Deze repo is publiek. Zet er nooit een `SKILL.md`, links naar Sputnik-decks of inhoud van pitches in.

## Voor de beheerder

- Een nieuwe versie van de skill deel je rechtstreeks met de gebruikers, en verhoog je de regel `Versie:` in het bestand. Het script toont die versie bij het installeren.
- Verhuist de repo, pas dan de repo-naam aan in `install.sh` (de regel die begint met `REPO=`) en in de `curl`-commando's van deze README.
