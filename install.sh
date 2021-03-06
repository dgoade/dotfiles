#!/usr/bin/env bash
# Time-stamp: <Tue 2015-08-10 10:52 david.goade>
################################################################################
#       _   _ _     _   _ ____   ____   ____        _    __ _ _
#      | | | | |   | | | |  _ \ / ___| |  _ \  ___ | |_ / _(_) | ___  ___
#      | | | | |   | |_| | |_) | |     | | | |/ _ \| __| |_| | |/ _ \/ __|
#      | |_| | |___|  _  |  __/| |___  | |_| | (_) | |_|  _| | |  __/\__ \
#       \___/|_____|_| |_|_|    \____| |____/ \___/ \__|_| |_|_|\___||___/
#
################################################################################
# Installation script for ULHPC dotfiles within the homedir of the user running
# this script. 

#set -x # Debug

### Global variables
VERSION=0.1
COMMAND=`basename $0`
VERBOSE=""
DEBUG=""
SIMULATION=""
OFFLINE=""
MODE=""
FORCE=""

### displayed colors
COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_YELLOW="\033[0;33m"
COLOR_VIOLET="\033[0;35m"
COLOR_CYAN="\033[0;36m"
COLOR_BOLD="\033[1m"
COLOR_BACK="\033[0m"

### Local variables
STARTDIR="$(pwd)"
SCRIPTFILENAME=$(basename $0)
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DOTFILES=~/.dotfiles

REPO_URL="https://github.com/dgoade/dotfiles.git"

#######################
### print functions ###
#######################

######
# Print information in the following form: '[$2] $1' ($2=INFO if not submitted)
# usage: info text [title]
##
info() {
    [ -z "$1" ] && print_error_and_exit "[$FUNCNAME] missing text argument"
    local text=$1
    local title=$2
    # add default title if not submitted but don't print anything
    [ -n "$text" ] && text="${title:==>} $text"
    echo -e $text
}
debug()   { [ -n "$DEBUG"   ] && info "$1" "[${COLOR_YELLOW}DEBUG${COLOR_BACK}]"; }
verbose() { [ -n "$VERBOSE" ] && info "$1"; }
error()   { info "$1" "[${COLOR_RED}ERROR${COLOR_BACK}]"; }
warning() { info "$1" "[${COLOR_VIOLET}WARNING${COLOR_BACK}]"; }
print_error_and_exit() {
    local text=$1
    [ -z "$1" ] && text=" Bad format"
    error  "$text. '$COMMAND -h' for help."
    exit 1
}
print_version() {
    cat <<EOF
This is ULHPC/dotfiles/$COMMAND version "$VERSION".
Copyright (c) 2015 UL HPC Management team  (hpc-sysadmins@uni.lu)
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
EOF
}
print_help() {
    less <<EOF
NAME
    $COMMAND -- install (or remove) ULHPC dotfiles in the current user's homedir

SYNOPSIS
    $COMMAND [-V | -h]
    $COMMAND [--debug] [-v] [-n] [-d DIR] [--offline]
    $COMMAND --delete [-d DIR]

OPTIONS
    --debug
        Debug mode. Causes $COMMAND to print debugging messages.
    -h --help
        Display a help screen and quit.
    -n --dry-run
        Simulation mode.
    -v --verbose
        Verbose mode.
    -f --force
        Force mode -- do not raise questions ;)
    -V --version
        Display the version number then quit.
    -d --dir DIR
        Set the dotfiles directory (Default: ~/.dotfiles)
    --delete --remove --uninstall
        Remove / Restore the installed components
    --offline
        Proceed in offline mode (assuming you have already cloned the repository)

AUTHOR
    UL HPC Management Team (hpc-sysadmins@uni.lu) aka.
      S.Varrette,  H. Cartiaux, V. Plugaru and S. Diehl at the time of writting

REPORTING BUGS
    Please report bugs using the Issue Tracker of the project:
       <https://github/dgoade/dotfiles/issues>

COPYRIGHT
    This is free software; see the source for copying conditions.  There is
    NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR
    PURPOSE.
EOF
}
#########################
### toolbox functions ###
#########################

#####
# execute a local command
# usage: execute command
###
execute() {
    [ $# -eq 0 ] && print_error_and_exit "[$FUNCNAME] missing command argument"
    debug "[$FUNCNAME] $*"
    [ -n "${SIMULATION}" ] && echo "(simulation) $*" || eval $*
    local exit_status=$?
    debug "[$FUNCNAME] exit status: $exit_status"
    return $exit_status
}

####
# ask to continue. exit 1 if the answer is no
# usage: really_continue text
##
really_continue() {
    echo -e -n "[${COLOR_VIOLET}WARNING${COLOR_BACK}] $1 Are you sure you want to continue? [Y|n] "
    read ans
    case $ans in
        n*|N*) exit 1;;
    esac
}

####
# Add (or remove) a given link pointing to the corresponding dotfile.
# A backup of the file is performed if it previoiusly existed.
# Upon removal, the link is deleted only if it targets the expected dotfile
##
add_or_remove_link() {
    [ $# -ne 2 ] && print_error_and_exit "[$FUNCNAME] missing argument(s). Format: $FUNCNAME <src> <dst>"
    local src=$1
    local dst=$2
	[ ! -f $src ] && print_error_and_exit "Unable to find the dotfile '${src}'"
    if [ "${MODE}" == "--delete" ]; then
		debug "removing dst='$dst' (if symlink pointing to src='$src' =? $(readlink $dst))"
		if [[ -h $dst && "$(readlink $dst)" == "${src}" ]]; then
			warning "removing the symlink '$dst'"
			[ -n "${VERBOSE}" ] && really_continue
			execute "rm $dst"
			if [ -f "${dst}.bak" ]; then
				warning "restoring ${dst} from ${dst}.bak"
				execute "mv ${dst}.bak ${dst}"
			fi
		fi
	else
		debug "attempt to add '$dst' symlink (pointing to '$src')"
        # return if the symlink already exists
        [ -h $dst ] && return
        if [ -f $dst ]; then
            warning "The file '$dst' already exists and will be backuped (as ${dst}.bak)"
            execute "cp $dst{,.bak}"
        fi
        execute "ln -sf $src $dst"
    fi
}

################################################################################
################################################################################
# Let's go

# Check for options
while [ $# -ge 1 ]; do
    case $1 in
        -h | --help)    print_help;        exit 0;;
        -V | --version) print_version;     exit 0;;
        --debug)         DEBUG="--debug";
                         VERBOSE="--verbose";;
        -v | --verbose)  VERBOSE="--verbose";;
		-f | --force)    FORCE="--force";;
        -n | --dry-run)  SIMULATION="--dry-run";;
		--offline)       OFFLINE="--offline";;
        --delete | --remove | --uninstall)
			OFFLINE="--offline"; MODE="--delete";;
        -d | --dir | --dotfiles)
            shift;       DOTFILES=$1;;
    esac
    shift
done
[ -z "${DOTFILES}" ] && print_error_and_exit "Wrong dotfiles directory (empty)"
echo ${DOTFILES} | grep  '^\/' > /dev/null
greprc=$?
if [ $greprc -ne 0 ]; then
    warning "Assume dotfiles directory '${DOTFILES}' is relative to the home directory"
    DOTFILES="$HOME/${DOTFILES}"
fi
info "About to install the ULHPC dotfiles from ${DOTFILES}"
[ -z "${FORCE}" ] && really_continue

[[ -z "${OFFLINE}" && -d "${DOTFILES}" ]]   && execute "( cd $DOTFILES ; git pull )"
[[ ! -d "${DOTFILES}" ]] && execute "git clone ${REPO_URL} ${DOTFILES}"

cd ~

## bash
add_or_remove_link $DOTFILES/.bashrc       ~/.bashrc
add_or_remove_link $DOTFILES/.inputrc      ~/.inputrc
add_or_remove_link $DOTFILES/.bash_profile ~/.bash_profile
add_or_remove_link $DOTFILES/.profile      ~/.profile
add_or_remove_link $DOTFILES/.bash_logout  ~/.bash_logout

## vim
add_or_remove_link $DOTFILES/.vimrc ~/.vimrc

## screen
add_or_remove_link $DOTFILES/.screenrc ~/.screenrc
