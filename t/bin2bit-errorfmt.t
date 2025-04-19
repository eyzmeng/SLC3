#!/bin/sh
# shellcheck disable=SC2317

. t/lib/test-functions.sh
. t/lib/test-find-exec.sh
plan 3

EXEPATH=util/bin2bit
EXECBIN="$PWD/$EXEPATH"
EXENAME="$(basename "$EXEPATH")"
cd "$tmp" || die "error: cd \$tmp"

if find_exec
then
	my=errorfmt.1
	mx=errorfmt.1.a-veryveryveryveryVERYveryveryveryVERYveryveryveryvery.very.very.looooooooooooongname

	"$EXECBIN" "$mx".txt >"$my".out 2>"$my".err

	r=$? ; test "$r" -eq 1
	ok "bin2bit exits abnormally" || {
		diag "error: bin2bit exited with status $r"
		diag ".... but I expected to see status 1."
	}

	cat <<EOF >"$my".wnt
errorfmt.1.a-veryveryveryveryVERYveryveryveryVERYver: No such file or directory
EOF
	is "$my".err "$my".wnt "TODO stderr truncates correctly"
else
	skip 2 "no $EXEPATH"
fi

conclude

# vim: ft=sh:
