#!/usr/bin/env bash
input=$(cat)

# Single jq call: extract every field needed in one pass to avoid spawning
# one jq process per field on every debounced status-line refresh.
#
# Séparateur = US (0x1f) et NON une tabulation : la tabulation fait partie des
# caractères d'espacement d'IFS, donc `read` fusionne les délimiteurs consécutifs
# et DÉCALE les champs dès qu'un champ intermédiaire est vide. Avec @tsv, un
# used_percentage à null (début de session, post-/compact) faisait lire le coût
# à la place du pourcentage de contexte. 0x1f n'est pas un caractère d'espacement :
# les champs vides sont préservés.
IFS=$'\x1f' read -r cwd model ctx_pct cost rate5h <<< "$(echo "$input" | jq -r '
  [
    (.workspace.current_dir // .cwd // ""),
    (.model.display_name // ""),
    (if .context_window.used_percentage == null then "" else (.context_window.used_percentage | tostring) end),
    (if .cost.total_cost_usd == null then "" else (.cost.total_cost_usd | tostring) end),
    (if .rate_limits.five_hour.used_percentage == null then "" else (.rate_limits.five_hour.used_percentage | tostring) end)
  ] | join("\u001f")
')"

# Path: shorten home to ~
if [ -n "$cwd" ]; then
  home="$HOME"
  short_path="${cwd/#$home/~}"
else
  short_path="$(pwd)"
  cwd="$short_path"
fi

# Git branch (empty if not a repo). --no-optional-locks avoids lock contention.
branch=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  fi
fi

# ANSI colors (dimmed, terminal-friendly)
COLOR_MODEL="\033[2;36m"   # dim cyan
COLOR_BRANCH="\033[2;33m"  # dim yellow
COLOR_PATH="\033[2;32m"    # dim green
COLOR_SEP="\033[2;37m"     # dim white
COLOR_CTX_LOW="\033[2;32m"  # dim green  (<50% used)
COLOR_CTX_MID="\033[2;33m"  # dim yellow (50-79% used)
COLOR_CTX_HIGH="\033[2;31m" # dim red    (>=80% used)
COLOR_COST="\033[2;35m"    # dim magenta
COLOR_RATE="\033[2;34m"    # dim blue
RESET="\033[0m"

# Context window usage bar (only when the API has already returned a
# percentage; null happens at session start and right after /compact).
ctx_segment=""
if [ -n "$ctx_pct" ]; then
  # /usr/bin/printf et non le builtin bash : sous LANG=fr_FR.UTF-8, le builtin
  # refuse "23.5" (« invalid number »), affiche 0 et pollue stderr — et le
  # préfixe LC_ALL=C ne recharge pas la locale d'un builtin sur bash 3.2.
  # awk n'est pas une alternative : il rend "0,15" (virgule) sur macOS.
  ctx_int=$(LC_ALL=C /usr/bin/printf '%.0f' "$ctx_pct" 2>/dev/null)
  [ -z "$ctx_int" ] && ctx_int=0
  if [ "$ctx_int" -lt 50 ]; then
    ctx_color="$COLOR_CTX_LOW"
  elif [ "$ctx_int" -lt 80 ]; then
    ctx_color="$COLOR_CTX_MID"
  else
    ctx_color="$COLOR_CTX_HIGH"
  fi

  bar_width=10
  filled=$(( ctx_int * bar_width / 100 ))
  [ "$filled" -gt "$bar_width" ] && filled="$bar_width"
  empty=$(( bar_width - filled ))

  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}#"; i=$((i + 1)); done
  i=0
  while [ "$i" -lt "$empty" ]; do bar="${bar}-"; i=$((i + 1)); done

  ctx_segment="${ctx_color}[${bar}] ${ctx_int}%${RESET}"
fi

# Session cost (client-side estimate, USD)
cost_segment=""
if [ -n "$cost" ]; then
  cost_fmt=$(LC_ALL=C /usr/bin/printf '%.2f' "$cost" 2>/dev/null)
  [ -z "$cost_fmt" ] && cost_fmt="0.00"
  cost_segment="${COLOR_COST}\$${cost_fmt}${RESET}"
fi

# Claude.ai 5-hour rate-limit usage (Pro/Max subscribers only; absent otherwise)
rate_segment=""
if [ -n "$rate5h" ]; then
  rate_int=$(LC_ALL=C /usr/bin/printf '%.0f' "$rate5h" 2>/dev/null)
  [ -z "$rate_int" ] && rate_int=0
  rate_segment="${COLOR_RATE}5h:${rate_int}%${RESET}"
fi

segments=()

if [ -n "$model" ]; then
  segments+=("${COLOR_MODEL}${model}${RESET}")
fi

if [ -n "$branch" ]; then
  segments+=("${COLOR_BRANCH}${branch}${RESET}")
fi

segments+=("${COLOR_PATH}${short_path}${RESET}")

if [ -n "$ctx_segment" ]; then
  segments+=("$ctx_segment")
fi

if [ -n "$cost_segment" ]; then
  segments+=("$cost_segment")
fi

if [ -n "$rate_segment" ]; then
  segments+=("$rate_segment")
fi

output=""
for seg in "${segments[@]}"; do
  if [ -z "$output" ]; then
    output="$seg"
  else
    output="${output} ${COLOR_SEP}|${RESET} ${seg}"
  fi
done

printf '%b' "$output"
