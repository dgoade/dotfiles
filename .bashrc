#!/bin/bash
# A basically sane bash environment.
#
# Based on: Ryan Tomayko <http://tomayko.com/about> (with help from the internets).

# the basics
: ${HOME=~}
: ${LOGNAME=$(id -un)}
: ${UNAME=$(uname)}

# complete hostnames from this file
: ${HOSTFILE=~/.ssh/known_hosts}


# ----------------------------------------------------------------------
#  SHELL OPTIONS
# ----------------------------------------------------------------------
set_shell_options()
{

    # bring in system bashrc
    if [ -r /etc/bashrc ]; then
        . /etc/bashrc
    fi

    # notify of bg job completion immediately
    set -o notify

    # shell opts. see bash(1) for details
    shopt -s cdspell                 >/dev/null 2>&1
    shopt -s extglob                 >/dev/null 2>&1
    shopt -s histappend              >/dev/null 2>&1
    shopt -s hostcomplete            >/dev/null 2>&1
    shopt -s interactive_comments    >/dev/null 2>&1
    shopt -u mailwarn                >/dev/null 2>&1
    shopt -s no_empty_cmd_completion >/dev/null 2>&1

    # don't report new mail on login
    unset MAILCHECK

    # disable core dumps
    ulimit -S -c 0

    # default umask
    umask 0022

}

# ----------------------------------------------------------------------
# PATH
# ----------------------------------------------------------------------

set_path()
{

    # we want the various sbins on the path along with /usr/local/bin
    PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
    PATH="/usr/local/bin:$PATH"

    # put ~/bin first on PATH
    if [ -d "$HOME/bin" ]; then
        PATH="$HOME/bin:$PATH"
    fi
}

# ----------------------------------------------------------------------
# ENVIRONMENT CONFIGURATION
# ----------------------------------------------------------------------

set_env()
{

    # detect interactive shell
    case "$-" in
        *i*) INTERACTIVE=yes ;;
        *)   unset INTERACTIVE ;;
    esac

    # detect login shell
    case "$0" in
        -*) LOGIN=yes ;;
        *)  unset LOGIN ;;
    esac

    # enable en_US locale w/ utf-8 encodings if not already configured
    : ${LANG:="en_US.UTF-8"}
    : ${LANGUAGE:="en"}
    : ${LC_CTYPE:="en_US.UTF-8"}
    : ${LC_ALL:="en_US.UTF-8"}
    export LANG LANGUAGE LC_CTYPE LC_ALL

    # always use PASSIVE mode ftp
    : ${FTP_PASSIVE:=1}
    export FTP_PASSIVE

    # File name completion ignore
    # ignore backups, CVS directories, python bytecode, vim swap files
    FIGNORE="~:CVS:#:.pyc:.swp:.swa:apache-solr-*"

    # history stuff
    HISTCONTROL=ignoreboth
    HISTFILESIZE=100000
    HISTSIZE=100000

}

# ----------------------------------------------------------------------
# PAGER / EDITOR
# ----------------------------------------------------------------------
set_editor_and_pager()
{

    # See what we have to work with ...
    HAVE_VIM=$(command -v vim)
    HAVE_GVIM=$(command -v gvim)

    # EDITOR
    if [ -n "$HAVE_VIM" ]; then
        EDITOR=vim
    else
        EDITOR=vi
    fi
    export EDITOR

    # PAGER
    if [ -n "$(command -v less)" ]; then
        PAGER="less -FirSwX"
        MANPAGER="less -FiRswX"
    else
        PAGER=more
        MANPAGER="$PAGER"
    fi
    export PAGER MANPAGER

    # ACK
    ACK_PAGER="$PAGER"
    ACK_PAGER_COLOR="$PAGER"

}

# ----------------------------------------------------------------------
# PROMPT
# ----------------------------------------------------------------------
set_prompt()
{

    RED="\[\033[0;31m\]"
    BROWN="\[\033[0;33m\]"
    GREY="\[\033[0;97m\]"
    BLUE="\[\033[0;34m\]"
    PS_CLEAR="\[\033[0m\]"
    SCREEN_ESC="\[\033k\033\134\]"

    if [ "$LOGNAME" = "root" ]; then
        COLOR1="${RED}"
        COLOR2="${BROWN}"
        P="#"
    elif hostname | grep -q '\.github\.'; then
        GITHUB=true
        COLOR1="\[\e[0;94m\]"
        COLOR2="\[\e[0;92m\]"
        P="\$"
    else
        COLOR1="${BLUE}"
        COLOR2="${BROWN}"
        P="\$"
    fi

}

prompt_simple() 
{
    unset PROMPT_COMMAND
    PS1="[\u@\h:\w]\$ "
    PS2="> "
}

prompt_compact() 
{
    unset PROMPT_COMMAND
    PS1="${COLOR1}${P}${PS_CLEAR} "
    PS2="> "
}

prompt_color() 
{
    PS1="${GREY}[${COLOR1}\u${GREY}@${COLOR2}\h${GREY}:${COLOR1}\W${GREY}]${COLOR2}$P${PS_CLEAR} "
    PS2="\[[33;1m\] \[[0m[1m\]> "
}

# ----------------------------------------------------------------------
# MACOS X / DARWIN SPECIFIC
# ----------------------------------------------------------------------
set_mac_settings()
{

    if [ "$UNAME" = Darwin ]; then
        # setup java environment. puke.
        export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Home"
    fi

}

# ----------------------------------------------------------------------
# BASH COMPLETION
# ----------------------------------------------------------------------
set_bash_completion()
{

    if [ -z "$BASH_COMPLETION" ]; then
        bash=${BASH_VERSION%.*}; bmajor=${bash%.*}; bminor=${bash#*.}
        if [ -n "$PS1" -a "$bmajor" -gt 1 ]; then
            # search for a bash_completion file to source
            for f in /usr/local/etc/bash_completion \
                /etc/bash_completion \
                /opt/local/etc/bash_completion
            do
                if [ -f $f ]; then
                    . $f
                    break
                fi
            done
        fi
        unset bash bmajor bminor
    fi

}

# override and disable tilde expansion
_expand() {
    return 0
}

# ----------------------------------------------------------------------
# LS AND DIRCOLORS
# ----------------------------------------------------------------------
set_dircolors()
{

    # we always pass these to ls(1)
    LS_COMMON="-hBG"

    # if the dircolors utility is available, set that up too
    dircolors="$(type -P gdircolors dircolors | head -1)"
    if [ -n "$dircolors" ]; then
        COLORS=/etc/DIR_COLORS
        test -e "/etc/DIR_COLORS.$TERM"   && COLORS="/etc/DIR_COLORS.$TERM"
        test -e "$HOME/.dircolors"        && COLORS="$HOME/.dircolors"
        test ! -e "$COLORS"               && COLORS=
        eval $(${dircolors} --sh ${COLORS})
    fi
    unset dircolors

    # setup the main ls alias if we've established common args
    if [ -n "$LS_COMMON" ]; then
    # dcg -- this is causing ls to ignore the colors set above
    #    alias ls="command ls $LS_COMMON"
        :
    fi

    # these use the ls aliases above
    alias ll="ls -l"
}

# -------------------------------------------------------------------
# USER SHELL ENVIRONMENT
# -------------------------------------------------------------------
set_user_env()
{

    # bring in rbdev functions from ~/bin
    . rbdev 2>/dev/null || true

    # ~/.shenv is used as a machine specific ~/.bashrc
    if [ -r ~/.shenv ]
    then
        source ~/.shenv
    fi

    # Use the color prompt by default when interactive
    if [ -n "$PS1" ]; then
        prompt_color
    fi

    # readline config
    if [ "x${INPUTRC}" = "x" ]
    then
        # default to emacs
        INPUTRC=~/.inputrc_emacs
    else
        # use the readline config set elsewhere, like in .shenv
        :
    fi
}

# -------------------------------------------------------------------
# Aliases
# -------------------------------------------------------------------

alias topdu='du -s * | sort -k1,1rn | head'

# -------------------------------------------------------------------
# MOTD / FORTUNE
# -------------------------------------------------------------------
set_motd()
{

    if [ -n "$INTERACTIVE" -a -n "$LOGIN" ]; then
        uname -npsr
        uptime
    fi

    # beep
    alias beep='tput bel'
}

main()
{

    declare -i rval=0

    if [ ${rval} -eq 0 ]
    then
        set_shell_options
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_path
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_env
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_editor_and_pager
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_prompt
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_mac_settings
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_bash_completion
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_dircolors
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_user_env
        rval=$?
    fi

    if [ ${rval} -eq 0 ]
    then
        set_motd
        rval=$?
    fi

    # if you don't want to install bash_completion
    # from packaged source, you can enable this
    # and get just the user-defined completions
    # source ~/.bash_completion

    return ${rval}

}

main
EXIT_STATUS=$?
# don't exit here but report
if [ ${EXIT_STATUS} -eq 0 ]
then
    :
else
    echo "Problems occurred in $0"
fi

# vim: ts=4 sts=4 shiftwidth=4 expandtab
