#!/bin/sh

set -e

: ${ANSIBLE_GPG=gpg2}
: ${ANSIBLE_GPG_LANG=C}

export LANG=$ANSIBLE_GPG_LANG

usage() {
        test -n "$1" && exec >&2
        cat <<EOF
Usage:
  $program [options]
Options:
  -h       Show this help
  -d       Decrypt embedded content in this script and print it (default)
  -p       Print embedded content in this script
  -r FILE  Print updated script with embedded content replaced with FILE
  -i       Used with -r, in-place replace $0
Notes:
  You need to feed embedded content in ASCII-armored format for -r.
  You should specify -a to gpg for encryption as the following example.
Example:
  \$ echo secret-content | gpg -ac | $0 -ir -
  \$ $0
  secret-content
EOF
        exit $1
}

program=${0##*/}
args=$(getopt -o dpr:ih -n $program -- "$@")
test $? -eq 0 || usage 1
eval set -- "$args"

MODE=DECRYPT
FILE=-
INPLACE=false
while test $# -gt 0; do
        case "$1" in
        -d)
                MODE=DECRYPT
                shift
                ;;
        -p)
                MODE=PRINT
                shift
                ;;
        -r)
                MODE=REPLACE
                FILE=$2
                shift 2
                ;;
        -i)
                INPLACE=true
                shift
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

case "$MODE" in
DECRYPT)
        LANG=$ANSIBlE_GPG_LANG $ANSIBLE_GPG -q -d $0
        ;;
PRINT)
        sed -e '1,/^# EMBED /d' $0
        ;;
REPLACE)
        TEMPFILE=$(tempfile)
        trap "rm -f $TEMPFILE" EXIT
        sed -ne '1,/^# EMBED /p' $0 >$TEMPFILE
        cat "$FILE" >>$TEMPFILE
        if $INPLACE; then
                chmod +x $TEMPFILE
                mv $TEMPFILE $0
        else
                cat $TEMPFILE
        fi
        ;;
esac

exit $?

# EMBED SECURE CONTENT IN ASCII-ARMORED FORMAT BELOW
-----BEGIN PGP MESSAGE-----
Version: GnuPG v2.0.22 (GNU/Linux)

jA0ECQMCabaaMycJCffT0k0BtFRPBRtSLtfqM/21/AhgJWn3XhHMnLXYy7h1GFeZ
8lbtGHl1cLQkTg8mC1b1oidkNEzZiwRrDJtg43pj5GSBP1Hed7r0hOWS34ix6A==
=iEkS
-----END PGP MESSAGE-----
