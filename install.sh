function copy() {
	src=$1
	dst=$2
	if [ -f $dst ]; then
		while true; do
			read -p "$dst already exists.  Do you want to overwrite? [y] yes (default), [s] skip, [c] cancel: " ysc
			case $ysc in
				[Yy]* ) break;;
				[Ss]* ) return 1;;
				[Cc]* ) echo "Install cancelled."; exit 1;;
				* )  break;;
			esac
		done
	fi
	cp $src $dst
	return 0
}

function install_vimrc() {
	if ! copy .vimrc $HOME/.vimrc; then
		return 1
	fi
	vim +PluginInstall +qall
}

function install_bashrc() {
	mkdir -p $HOME/.bashrc.d
	copy .bashrc $HOME/.bashrc.d/defaults
	if ! cat $HOME/.bashrc | grep "User specific aliases and functions" > /dev/null; then
		lines='
# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
	for rc in ~/.bashrc.d/*; do
			if [ -f "$rc" ]; then
					source "$rc"
			fi
	done
fi
		'
		echo "$lines" >> $HOME/.bashrc
	fi
	for rc in $HOME/.bashrc.d/*; do
		source "$rc"
	done
}

function install_fzf() {
	git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
	$HOME/.fzf/install
}

install_fzf
install_vimrc
install_bashrc
