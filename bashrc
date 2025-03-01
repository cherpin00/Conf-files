function ip() {
  host="$1"
  host $host | awk '{print $NF}'
}

function ks() {
  if ! command -v kubectl &>/dev/null; then
    echo "kubectl is not installed." >&2
    return 1
  fi

  if [ -z "$1" ]; then
    echo $(kubectl config view --minify -o jsonpath='{..namespace}')
    return 0
  fi
  kubectl config set-context --current --namespace "$1"
}

function copy_text_to_pod() {
  if ! command -v kubectl &>/dev/null; then
    echo "kubectl is not installed." >&2
    return 1
  fi

  namespace=$1
  pod_name=$2
  src_filename=$3
  dest_filename=$4

  base64_text=$(cat "$src_filename" | base64)
  kubectl exec -n "$namespace" "$pod_name" -- bash -c "echo \"$base64_text\" | base64 -d > \"$dest_filename\""
}

# Only enable kubectl completion if kubectl is installed
if command -v kubectl &>/dev/null; then
  source <(kubectl completion bash)
  complete -o default -F __start_kubectl k

  alias k="kubectl"
  alias kg="kubectl get"
  alias kga="kubectl get -A"
  alias kgo="kubectl get -o wide"
  alias kgao="kubectl get -A -o wide"
fi

# Load fzf if installed
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

alias dir="ls -latrh"
alias tmux_start="tmux new -A -s tmux_ssh"
alias tp="trash"
