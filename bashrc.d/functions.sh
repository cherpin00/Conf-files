# --- shell integrations -----------------------------------------------------
# Guarded: this file is symlinked onto every host, and not all of them have
# these tools. An unguarded `. <(flux completion bash)` errors on login.
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
command -v flux &>/dev/null && . <(flux completion bash)
# --cmd cd makes zoxide shadow cd, so plain `cd` learns frecency.
command -v zoxide &>/dev/null && eval "$(zoxide init bash --cmd cd)"

# --- general ----------------------------------------------------------------
function field() { n=$1; awk -v n="$n" '{print $n}'; }

function ip() {
  host="$1"
  host $host | awk '{print $NF}'
}

# Change dir to the dir a file lives in
cdd() {
  file="$1"
  cd "$(dirname "$file")"
}

# --- kubernetes -------------------------------------------------------------
# Throwaway netshoot debug shell. -c cluster, -n namespace, -h node hostname.
kdb() {
  local cluster="" namespace="" hostname="" opt
  local -a cmd
  # getopts resumes from the previous call's OPTIND unless it is reset, so
  # without this the second kdb in a shell parses no flags at all.
  local OPTIND=1

  while getopts ":c:n:h:" opt; do
    case $opt in
      c) cluster="$OPTARG";;
      n) namespace="$OPTARG";;
      h) hostname="$OPTARG";;
      \?) echo "Invalid option -$OPTARG"; return 1;;
    esac
  done

  # An array, not a string: the --overrides JSON contains spaces, and a
  # word-split string would hand kubectl each fragment as its own argument.
  cmd=(kubectl run ch-tmp-shell-1 --rm -i --tty)
  [ -n "$cluster" ] && cmd+=(--context "$cluster")
  cmd+=(--image "harbor${cluster:+-$cluster}.thefacebook.com/ee-k8s/netshoot")
  [ -n "$namespace" ] && cmd+=(--namespace "$namespace")
  [ -n "$hostname" ] && cmd+=(--overrides "{\"apiVersion\":\"v1\",\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"$hostname\"}}}")

  "${cmd[@]}"
}

# --- fbcode -----------------------------------------------------------------
# Build the sandcastle scheduler, publish a dev fbpkg, run $1 against it.
test_sc_job() {
  buck build @mode/opt -c build_info.package_release=1 \
    configerator/sandcastle_scheduler:configerator-sandcastle-scheduler || return 1
  fbpkg build -E --yes configerator.sandcastle_scheduler.dev >/tmp/output || return 1
  local hash
  hash=$(tail -1 /tmp/output | awk -F: '{print $NF}')
  buck run //configerator/sandcastle_scheduler:configerator-sandcastle-scheduler -- \
    run-simple --use-dev-package --fbpkg-version "$hash" "$1"
}
