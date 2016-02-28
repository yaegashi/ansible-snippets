#!/bin/sh

set -e

: ${ANSIBLE_GPG_AGENT=gpg-agent}
: ${ANSIBLE_GPG_CONNECT_AGENT=gpg-connect-agent}
: ${ANSIBLE_GPG_AGENT_INFO=~/.gnupg/.ansible-gpg-agent-info}
: ${ANSIBLE_GPG_LANG=C}

export LANG=$ANSIBLE_GPG_LANG

usage() {
        test -n "$1" && exec >&2
        cat <<EOF
Usage:
  $program [options]
  $program -- command...
Options:
  -h   Show this help
  -a   Print aliases for the shell and exit
  -r   Remove credentials cached in the agent
  -k   Terminate the agent
EOF
        exit $1
}

agent() {
        if test -r $ANSIBLE_GPG_AGENT_INFO; then
               . $ANSIBLE_GPG_AGENT_INFO
               export GPG_AGENT_INFO
               export SSH_AUTH_SOCK
        fi
        case "$1" in
        start)
                if ! $ANSIBLE_GPG_CONNECT_AGENT /bye >/dev/null 2>&1; then
                        eval $($ANSIBLE_GPG_AGENT \
                                --daemon \
                                --enable-ssh-support \
                                --write-env-file $ANSIBLE_GPG_AGENT_INFO)
                fi
                ;;
        stop)
                # This won't work for GnuPG 2.0.22 on Ubuntu 14.04
                # $ANSIBLE_GPG_CONNECT_AGENT KILLAGENT /bye
                PID=$($ANSIBLE_GPG_CONNECT_AGENT GETINFO\ pid /bye |
                      sed -ne 's/D //p')
                test -n "$PID" && kill $PID
                ;;
        reload)
                $ANSIBLE_GPG_CONNECT_AGENT RELOADAGENT /bye >/dev/null
                ;;
        esac
}

aliases() {
        SCRIPT="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
        for i in ansible ansible-playbook ansible-vault; do
                echo "alias $i='$SCRIPT -- $i';"
        done
}

program=${0##*/}
args=$(getopt -o arkh -n $program -- "$@")
test $? -eq 0 || usage 1
eval set -- "$args"

while test $# -gt 0; do
        case "$1" in
        -a)
                aliases "$0"
                exit $?
                ;;
        -r)
                agent reload
                exit $?
                ;;
        -k)
                agent stop
                exit $?
                ;;
        -h)
                usage
                ;;
        --)
                shift
                break
                ;;
        *)
                usage 1
                ;;
        esac
done

test $# -gt 0 || usage 1

agent start
exec "$@"
