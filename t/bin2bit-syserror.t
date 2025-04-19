#!/bin/sh
# shellcheck disable=SC2317

. t/lib/test-functions.sh
. t/lib/test-find-exec.sh
plan 4

EXEPATH=util/bin2bit
EXECBIN="$PWD/$EXEPATH"
EXENAME="$(basename "$EXEPATH")"
cd "$tmp" || die "error: cd \$tmp"

if find_exec
then
	#
	# Case 0: read error
	#
	my=error.0
	mc="read ENOENT"

	"$EXECBIN" "$my".txt >"$my".out 2>"$my".err

	r=$? ; test "$r" -eq 1
	ok "$mc - bin2bit exits abnormally" || {
		diag "error: bin2bit exited with status $r"
		diag ".... but I expected to see status 1."
	}

	! test -e "$my".obj
	ok "$mc - bin2bit does not create object" || {
		diag "error: bin2bit exhibited unwanted side-effects"
		diag "No file should be created, but it created this:"
		ls -l "$my".obj | diag
	}

	cat <<EOF >"$my".wnt
${my}.txt: No such file or directory
EOF
	is "$my".err "$my".wnt "TODO $mc - stderr reports no octets"
else
	skip 3 "no $EXEPATH"
fi

conclude

# vim: ft=sh:
