# statusline-command.sh

A status line for [Claude Code](https://claude.com/claude-code) that shows, on
every refresh, **what the session is actually consuming**: how full the context
window is, the estimated cost, and how much of the 5-hour quota is already gone.

```
Opus 5 | webapp-6demos | ~/Desktop/DROPS/2026-WAXConf | [####------] 43% | $1.23 | 5h:18%
```

Left to right: model, git branch, current path, context bar, session cost,
5-hour quota.

## Why

An agent that works well is an agent whose budget you can see. The context fills
up quietly, the cost adds up quietly, the quota drains quietly — and you only
notice at the point where the session degrades or stops. A status line keeps
those three numbers **permanently** visible, with no command to type.

It is also a teaching tool: a bar that turns yellow and then red teaches you,
within a few sessions, to split the work up, to start a fresh session at the
right moment, and to `/compact` before you are forced to.

Shared for the talk **"Heroes: save the token, save the world"**
(WAX 2026, Marseille).

## Install

**Requirements**: `bash`, `jq`, `git` (the branch segment is simply omitted
outside a repository).

1. Grab the script:

```sh
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/MrZzE00/2026-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

2. Declare it in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

3. Restart Claude Code. The line shows up under the prompt.

To enable it for a single project, put the same key in that repository's
`.claude/settings.json` instead of the global file.

## What the script does

Claude Code writes a JSON object describing the session state to stdin, and
renders the script's stdout as the status line. This script reads the fields it
needs in **a single `jq` call** — one call per field would be paid on every
refresh — then assembles the segments.

| Segment | JSON source | Behaviour |
|---|---|---|
| Model | `.model.display_name` | omitted when absent |
| Branch | `git branch --show-current` | short SHA when HEAD is detached; omitted outside a repo |
| Path | `.workspace.current_dir` / `.cwd` | `$HOME` collapsed to `~` |
| Context | `.context_window.used_percentage` | 10-step bar, green < 50%, yellow 50-79%, red ≥ 80% |
| Cost | `.cost.total_cost_usd` | client-side estimate, in USD |
| 5-hour quota | `.rate_limits.five_hour.used_percentage` | Pro/Max subscribers only |

Any segment whose data is missing **disappears** rather than showing a zero: at
the start of a session and right after a `/compact`, the context percentage is
`null` — a bar at 0% would be a lie.

## Customising

Almost everything sits near the top of the file:

- **colours**: the `COLOR_*` constants, dimmed ANSI sequences (`\033[2;..m`);
- **bar thresholds**: the `-lt 50` and `-lt 80` comparisons;
- **bar width**: `bar_width=10`;
- **segment order and presence**: the `segments+=(...)` block at the end;
- **bar characters**: `#` and `-`, deliberately ASCII so they stay legible on a
  conference terminal or a projector.

## Testing without launching Claude Code

```sh
echo '{"workspace":{"current_dir":"'"$HOME"'"},"model":{"display_name":"Opus 5"},
       "context_window":{"used_percentage":42.7},"cost":{"total_cost_usd":1.2345},
       "rate_limits":{"five_hour":{"used_percentage":18}}}' | ./statusline-command.sh
```

## License

MIT — see [LICENSE](LICENSE). Take it, change it, pass it on.
