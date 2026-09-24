alias dir="ls -latrh"
alias tmux_start="tmux new -A -s tmux_ssh"
alias tp="trash"
alias nvimm="NVIM_APPNAME=nvim-minimal nvim"

# remote shells
alias becca-vm="ssh -i ~/.ssh/becca-vm beccacb3@192.168.98.202"
alias dev='x2ssh -et cherpin.sb.facebook.com -x -c '\''tmux new -A -s tmux_ssh; exit'\'

# kubectl
alias kt="kubectl --context test"
alias kp="kubectl --context prod"
alias kd="kubectl --context dmz"

# claude-os (fbcode, Meta devserver only)
alias claude-os="cd ~/.config/claude-os/workdirs/claude-os/ && buck2 run fbcode//ee_containers/other/claude_os:claude-os"
alias kill-claude-os="pkill -9 -f 'claude_os:claude-os|claude_os/__claude-os__'"
