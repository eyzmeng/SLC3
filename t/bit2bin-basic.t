#!/bin/sh
# shellcheck disable=SC2317

. t/lib/test-functions.sh
. t/lib/test-find-exec.sh
plan 4

EXEPATH=util/bit2bin
EXECBIN="$PWD/$EXEPATH"
EXENAME="$(basename "$EXEPATH")"
cd "$tmp" || die "error: cd \$tmp"

if find_exec
then
	my=basic.1
	printf '\x30\x00\x13\x24\xc0\xde\xf0\x25' >"$my".obj

	"$EXECBIN" "$my".obj >"$my".out 2>"$my".err

	ok "$EXENAME exits normally" || {
		diag "error: $EXENAME exited with status $?"
		diag <"$my".err
	}

	cat <<EOF | tr -d ' ' >"$my".wnt
0011 0000 0000 0000
0001 0011 0010 0100
1100 0000 1101 1110
1111 0000 0010 0101
EOF
	is "$my".out "$my".wnt "stdout has 4 lines"

	cat <<EOF >"$my".wnt
Serialized 8 octets
EOF
	is "$my".err "$my".wnt "stderr reports 8 octets"
else
	skip 3 "no $EXEPATH"
fi

conclude

# vim: ft=sh:
