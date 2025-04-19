#!/bin/sh
# shellcheck disable=SC2317

. t/lib/test-functions.sh
. t/lib/test-find-exec.sh
plan 9

EXEPATH=util/bin2bit
EXECBIN="$PWD/$EXEPATH"
EXENAME="$(basename "$EXEPATH")"
cd "$tmp" || die "error: cd \$tmp"

if find_exec
then
	#
	# Case 1: partial byte
	#
	my=error.0
	cat >"$my".txt <<'EOF'
0001001101111110
1101010
EOF

	"$EXECBIN" "$my".txt >"$my".out 2>"$my".err

	ok "bin2bit exits normally, case 1" || {
		diag "error: bin2bit exited with status $?"
		diag <"${my}.err"
	}

	# is wc(1) portable enough for people? i hope so...
	size="$(wc -c <"$my".obj | awk '{print $1}')"
	test "$size" -eq 2
	ok "object size, case 1" || {
		diag "Test for object size failed!"
		diag <<EOM
       got: $size
  expected: 2
EOM
	}

	hexdump -C "$my".obj > "$my".got
	printf '\x13\x7e' |
		hexdump -C >"$my".wnt
	is "$my".got "$my".wnt "object 137C (7 bits truncated)"

	cat <<EOF >"$my".wnt
2 octets written
EOF
	is "$my".err "$my".wnt "stderr reports 2 octets, case 1"

	#
	# Case 2: misaligned bits
	#
	my=error.2
	cat >"$my".txt <<'EOF'
000100110111111; oops
1101010
EOF

	"$EXECBIN" "$my".txt >"$my".out 2>"$my".err

	r=$? ; test "$r" -eq 255
	ok "bin2bit exits abnormally, case 2" || {
		diag "error: bin2bit exited with status $r"
		diag ".... but I expected to see status 255."
	}

	# is wc(1) portable enough for people? i hope so...
	size="$(wc -c <"$my".obj | awk '{print $1}')"
	test "$size" -eq 2
	ok "object size, case 2" || {
		diag "Test for object size failed!"
		diag <<EOM
       got: $size
  expected: 2
EOM
	}

	hexdump -C "$my".obj > "$my".got
	printf '\x13\x7f' |
		hexdump -C >"$my".wnt
	is "$my".got "$my".wnt "object 137F"

	cat <<EOF >"$my".wnt
${my}.txt:2:2: start of word should be separated by something
2 octets written
EOF
	is "$my".err "$my".wnt "stderr reports error and 2 octets, case 2"
else
	skip 8 "no $EXEPATH"
fi

conclude

# vim: ft=sh:
