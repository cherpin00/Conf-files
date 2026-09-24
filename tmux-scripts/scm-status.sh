#!/bin/sh
# Emit a pre-styled tmux status segment for the VCS state of $1, or nothing at
# all when $1 is not a repo. Emitting the whole segment (separator included)
# is what lets the bar collapse cleanly outside a repo -- tmux has no way to
# branch on the output of a #() call.
#
# git  : branch name, coloured by dirty state. ~70ms, uncached.
# sl   : Phabricator diff number, coloured by REVIEW STATUS. Expensive, cached.
#
# Deliberately does NOT use `jf`: `jf status` measured 12.8s, which is longer
# than the status-bar refresh interval. Sapling already exposes the same
# information locally via {phabdiff} / {phabstatus}.
#
# Colors are Catppuccin Mocha and intentionally duplicated from the theme;
# a #() runs as a separate process and cannot read tmux's @palette options.

GREEN='#a6e3a1'   # clean / Accepted
YELLOW='#f9e2af'  # Needs Review
RED='#f38ba8'     # Needs Revision
PEACH='#fab387'   # dirty working copy
GREY='#6c7086'    # closed / landed
TEXT='#cdd6f4'
OVERLAY='#6c7086' # separator

GIT_ICON=''
SL_ICON=''

# How long a cached sapling result stays good. {phabstatus} costs 1.5-2.3s and
# is network-backed; at a 15s refresh that would burn ~20% of a core forever.
SL_TTL=90

emit() { # emit <colour> <icon> <label> [suffix]
    printf '#[fg=%s]%s #[fg=%s]%s%s #[fg=%s]│ ' \
        "$1" "$2" "$TEXT" "$3" "$4" "$OVERLAY"
}

truncate_label() { # long names crowd out the centred window list
    case $1 in
        ?????????????????????*) printf '%.18s…' "$1" ;;
        *) printf '%s' "$1" ;;
    esac
}

dir="$1"
[ -n "$dir" ] && [ -d "$dir" ] || exit 0
cd "$dir" 2>/dev/null || exit 0

# ---------------------------------------------------------------- git --------
if branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) && [ -n "$branch" ]; then
    # --porcelain can crawl on a big worktree or a loaded box; never let the bar
    # block. Measured at 1.9s on this host at load 73, so the budget is 3s.
    dirty=$(timeout 3 git status --porcelain 2>/dev/null); rc=$?
    if [ "$rc" -eq 124 ]; then
        # Timed out. Report UNKNOWN rather than silently claiming clean -- a
        # false "clean" on a dirty tree is the one wrong answer that matters.
        colour="$GREY"; mark='?'
    elif [ -n "$dirty" ]; then
        colour="$PEACH"; mark=''
    else
        colour="$GREEN"; mark=''
    fi
    emit "$colour" "$GIT_ICON" "$(truncate_label "$branch")" "$mark"
    exit 0
fi

# ------------------------------------------------------------- sapling -------
# Find the repo root by walking up in pure shell -- no subprocess, so a cache
# hit costs essentially nothing. `sl root` is ~0.5-1s and must never sit on the
# hot path in front of the cache check. fbsource uses .hg, not .sl.
root="$PWD"
while [ -n "$root" ] && [ ! -d "$root/.sl" ] && [ ! -d "$root/.hg" ]; do
    root=${root%/*}
done
[ -n "$root" ] || exit 0

cache_dir="${TMPDIR:-/tmp}/tmux-scm-cache-$(id -u)"
mkdir -p "$cache_dir" 2>/dev/null
cache="$cache_dir/$(printf '%s' "$root" | cksum | tr -d ' /')"

stale=''
if [ -f "$cache" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))
    if [ "$age" -lt "$SL_TTL" ]; then
        cat "$cache"
        exit 0
    fi
    # Expired, but keep it: if the refresh below times out we would rather show
    # a slightly old diff number than have the segment blink out of existence.
    stale=$(cat "$cache" 2>/dev/null)
fi

# One sl invocation for all three fields; separate lines because sl templates
# do not interpret \t and the values may contain arbitrary characters.
info=$(timeout 8 sl log -r . -T '{phabdiff}\n{phabstatus}\n{ifeq(activebookmark,"","{node|short}","{activebookmark}")}' 2>/dev/null)
diff=$(printf '%s\n' "$info" | sed -n 1p)
status=$(printf '%s\n' "$info" | sed -n 2p)
label=$(printf '%s\n' "$info" | sed -n 3p)

# Prefer the diff number -- it is what you actually reference in review.
[ -n "$diff" ] && label="$diff"
if [ -z "$label" ]; then
    # sl timed out or failed. Serve stale rather than nothing; observed at
    # load 73 on this host, where sl log intermittently blew its budget.
    [ -n "$stale" ] && printf '%s' "$stale"
    exit 0
fi

case $status in
    Accepted)                     colour="$GREEN"  ;;
    "Needs Review"|"Changes Planned") colour="$YELLOW" ;;
    "Needs Revision")             colour="$RED"    ;;
    Closed|Committed|Landed|Abandoned) colour="$GREY" ;;
    *)                            colour="$TEXT"   ;;
esac

# Review status owns the colour now, so dirty state gets its own marker.
sldirty=$(timeout 5 sl status -mard 2>/dev/null); rc=$?
if [ "$rc" -eq 124 ]; then suffix='?'
elif [ -n "$sldirty" ]; then suffix='*'
else suffix=''
fi

out=$(emit "$colour" "$SL_ICON" "$(truncate_label "$label")" "$suffix")
# Write atomically so a concurrent refresh never reads a half-written file.
printf '%s' "$out" > "$cache.tmp" 2>/dev/null && mv -f "$cache.tmp" "$cache" 2>/dev/null
printf '%s' "$out"
