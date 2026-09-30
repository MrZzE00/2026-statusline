# statusline-command.sh

Une ligne de statut pour [Claude Code](https://claude.com/claude-code) qui affiche,
à chaque rafraîchissement, **ce que la session est en train de consommer** :
le remplissage de la fenêtre de contexte, le coût estimé, et la part déjà
utilisée du quota de 5 heures.

```
Opus 5 | webapp-6demos | ~/Desktop/DROPS/2026-WAXConf | [####------] 43% | $1.23 | 5h:18%
```

De gauche à droite : le modèle, la branche git, le chemin courant, la barre de
contexte, le coût de la session, le quota 5 h.

## Pourquoi

Un agent qui travaille bien est un agent dont on voit le budget. Le contexte se
remplit sans bruit, le coût s'accumule sans bruit, le quota se consomme sans
bruit — et on ne s'en aperçoit qu'au moment où la session se dégrade ou
s'arrête. Une ligne de statut rend ces trois grandeurs visibles **en
permanence**, sans commande à taper.

C'est aussi un outil pédagogique : la barre qui passe au jaune puis au rouge
apprend, en quelques sessions, à découper le travail, à ouvrir une session neuve
au bon moment et à `/compact` avant d'y être forcé.

Partagé à l'occasion du talk **« Heroes : save the token, save the world »**
(WAX 2026, Marseille).

## Installation

**Prérequis** : `bash`, `jq`, `git` (la branche est simplement omise hors dépôt).

1. Copier le script :

```sh
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/MrZzE00/2026-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

2. Le déclarer dans `~/.claude/settings.json` :

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

3. Relancer Claude Code. La ligne apparaît sous le prompt.

Pour ne l'activer que sur un projet, mettre la même clé dans le
`.claude/settings.json` du dépôt plutôt que dans le fichier global.

## Ce que fait le script

Claude Code envoie sur l'entrée standard un objet JSON décrivant l'état de la
session, et affiche la sortie standard du script comme ligne de statut. Ce
script lit six champs en **un seul appel à `jq`** — un appel par champ serait
payé à chaque rafraîchissement — puis compose les segments.

| Segment | Source JSON | Comportement |
|---|---|---|
| Modèle | `.model.display_name` | omis si absent |
| Branche | `git branch --show-current` | SHA court si HEAD détachée ; omis hors dépôt |
| Chemin | `.workspace.current_dir` / `.cwd` | `$HOME` réduit à `~` |
| Contexte | `.context_window.used_percentage` | barre 10 crans, vert < 50 %, jaune 50-79 %, rouge ≥ 80 % |
| Coût | `.cost.total_cost_usd` | estimation client, en USD |
| Quota 5 h | `.rate_limits.five_hour.used_percentage` | abonnements Pro/Max uniquement |

Tout segment dont la donnée est absente **disparaît** au lieu d'afficher un
zéro : au démarrage d'une session et juste après un `/compact`, le pourcentage
de contexte est `null` — une barre à 0 % serait un mensonge.

## Deux détails qui ont coûté cher

Ils sont commentés dans le script ; les voici pour qui voudrait s'en inspirer.

**Le séparateur est `US` (0x1f), pas une tabulation.** La tabulation fait partie
des caractères d'espacement d'`IFS` : `read` fusionne alors les délimiteurs
consécutifs et **décale les champs** dès qu'un champ intermédiaire est vide.
Avec `@tsv`, un `used_percentage` à `null` faisait lire le coût à la place du
pourcentage de contexte. `0x1f` n'est pas un caractère d'espacement, les champs
vides sont préservés.

**Le formatage passe par `/usr/bin/printf`, pas par le builtin bash.** Sous
`LANG=fr_FR.UTF-8`, le builtin refuse `"23.5"` (« invalid number »), affiche `0`
et pollue `stderr` — et préfixer `LC_ALL=C` ne recharge pas la locale d'un
builtin sur bash 3.2 (la version livrée avec macOS). `awk` n'est pas une
alternative : il rend `0,15`, avec une virgule.

## Personnaliser

Tout est en haut du fichier ou presque :

- **couleurs** : les constantes `COLOR_*`, en séquences ANSI atténuées (`\033[2;..m`) ;
- **seuils de la barre** : les comparaisons `-lt 50` et `-lt 80` ;
- **largeur de la barre** : `bar_width=10` ;
- **ordre et présence des segments** : le bloc `segments+=(...)` à la fin ;
- **caractères de la barre** : `#` et `-`, volontairement en ASCII pour rester
  lisible sur un terminal de conférence ou un vidéoprojecteur.

## Tester sans lancer Claude Code

```sh
echo '{"workspace":{"current_dir":"'"$HOME"'"},"model":{"display_name":"Opus 5"},
       "context_window":{"used_percentage":42.7},"cost":{"total_cost_usd":1.2345},
       "rate_limits":{"five_hour":{"used_percentage":18}}}' | ./statusline-command.sh
```

## Licence

MIT — voir [LICENSE](LICENSE). Reprenez, modifiez, partagez.
