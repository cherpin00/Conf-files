#!/bin/sh
# Emit a pre-styled tmux status segment for the current kube context, or
# nothing at all when there is no kubeconfig. Like scm-status.sh, this prints
# the WHOLE segment including its trailing separator -- tmux formats cannot
# branch on the output of #(), so collapsing cleanly has to happen here.
#
# Reflects `kubectx`/`kubens`, which rewrite current-context in the kubeconfig
# globally. It does NOT know about `kubectl --context <x>` passed per command;
# in that case the bar shows the ambient context, not the one being used.
#
# Colours are Catppuccin Mocha and intentionally duplicated from the theme;
# a #() runs as a separate process and cannot read tmux's @palette options.

TEAL='#94e2d5'    # the helm icon
TEXT='#cdd6f4'    # context name
YELLOW='#f9e2af'  # non-default namespace -- the state worth noticing
OVERLAY='#6c7086' # separator

ICON='⎈'          # U+2388, matches the starship prompt; plain Unicode, no Nerd Font needed

# KUBECONFIG may be a colon-separated list; the first entry wins for context.
cfg=${KUBECONFIG:-$HOME/.kube/config}
cfg=${cfg%%:*}
[ -n "$cfg" ] && [ -r "$cfg" ] || exit 0

ctx=""
ns=""

if command -v yq >/dev/null 2>&1; then
    # Real YAML parse: indentation-independent, unlike grepping for the key.
    # Two lines rather than a delimiter: yq does not interpret "\t" as a tab,
    # and context names may legitimately contain : or /, so no single-character
    # separator is safe.
    out=$(timeout 1 yq -r \
        '(.["current-context"]) as $c
         | .contexts[]? | select(.name == $c)
         | ($c, (.context.namespace // ""))' \
        "$cfg" 2>/dev/null)
    ctx=$(printf '%s\n' "$out" | sed -n 1p)
    ns=$(printf '%s\n' "$out" | sed -n 2p)
fi

# Fallback if yq is missing or the context has no entry: context only.
if [ -z "$ctx" ]; then
    ctx=$(sed -n 's/^current-context:[[:space:]]*//p' "$cfg" 2>/dev/null | head -1)
fi
[ -n "$ctx" ] || exit 0

# Long context names crowd out the centred window list on narrow terminals.
case $ctx in
    ?????????????????????*) ctx=$(printf '%.18s' "$ctx")… ;;
esac

# "default" is the overwhelmingly common case and carries no information;
# showing it only when it is something else makes it a real signal.
if [ -n "$ns" ] && [ "$ns" != "default" ]; then
    printf '#[fg=%s]%s #[fg=%s]%s#[fg=%s]:%s #[fg=%s]│ ' \
        "$TEAL" "$ICON" "$TEXT" "$ctx" "$YELLOW" "$ns" "$OVERLAY"
else
    printf '#[fg=%s]%s #[fg=%s]%s #[fg=%s]│ ' \
        "$TEAL" "$ICON" "$TEXT" "$ctx" "$OVERLAY"
fi
