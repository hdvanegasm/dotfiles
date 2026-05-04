#!/usr/bin/env bash
# Display all Sway keybindings extracted from the config file.
# Bound to $mod+F1 in ~/.config/sway/config.

set -euo pipefail
CONFIG="${HOME}/.config/sway/config"

# Self-page when run on a TTY (e.g. from the keybinding-launched terminal).
# Pass --no-page to skip (used internally and for piping to other tools).
if [[ "${1:-}" != "--no-page" && -t 1 ]]; then
    exec bash -c "'$0' --no-page | less -R"
fi

awk '
    BEGIN {
        BOLD    = "\033[1m";    RESET   = "\033[0m"
        DIM     = "\033[2m"
        CYAN    = "\033[1;36m"; MAGENTA = "\033[1;35m"
        YELLOW  = "\033[1;33m"; GREEN   = "\033[32m"

        printf "%sSway keybindings%s    %s(↑/↓ scroll · / search · q quit)%s\n",
               BOLD, RESET, DIM, RESET
        in_mode = 0
        pending_section = ""
        pending_subsection = ""
    }

    function flush_pending() {
        if (pending_section != "")    { printf "%s", pending_section;    pending_section = "" }
        if (pending_subsection != "") { printf "%s", pending_subsection; pending_subsection = "" }
    }

    function expand_vars(s,    k, idx, before, after) {
        for (k in vars) {
            while ((idx = index(s, k)) > 0) {
                before = substr(s, 1, idx-1)
                after  = substr(s, idx + length(k))
                s = before vars[k] after
            }
        }
        return s
    }

    # Capture "set $name value..." for substitution
    /^set[[:space:]]+\$/ {
        name = $2
        val = ""
        for (i = 3; i <= NF; i++) val = (val == "") ? $i : val " " $i
        vars[name] = val
        next
    }

    # Top-level section: "### Foo"
    /^### / {
        s = $0; sub(/^### /, "", s)
        pending_section = sprintf("\n%s── %s ──%s\n", MAGENTA, s, RESET)
        pending_subsection = ""
        next
    }

    # Subsection: "# Basics:"
    /^# .*:[[:space:]]*$/ && !in_mode {
        s = $0; sub(/^# /, "", s); sub(/:[[:space:]]*$/, "", s)
        pending_subsection = sprintf("\n  %s%s%s\n", CYAN, s, RESET)
        next
    }

    # Mode block start
    /^mode "/ {
        if (match($0, /"[^"]+"/)) {
            name = substr($0, RSTART+1, RLENGTH-2)
            flush_pending()
            printf "\n  %sMode: %s%s\n", YELLOW, name, RESET
            in_mode = 1
        }
        next
    }

    /^}/ && in_mode { in_mode = 0; next }

    /^[[:space:]]*bindsym/ {
        flush_pending()
        line = $0
        sub(/^[[:space:]]*bindsym[[:space:]]+/, "", line)
        gsub(/--[a-zA-Z-]+[[:space:]]+/, "", line)
        gsub(/\$mod/, "Super", line)
        line = expand_vars(line)
        if (match(line, /[[:space:]]+/)) {
            combo  = substr(line, 1, RSTART-1)
            action = substr(line, RSTART+RLENGTH)
        } else { next }
        if (length(action) > 80) action = substr(action, 1, 77) "..."
        indent = in_mode ? "      " : "    "
        printf "%s%s%-28s%s  %s\n", indent, GREEN, combo, RESET, action
    }
' "$CONFIG"
