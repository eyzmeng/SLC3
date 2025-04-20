#!/bin/sh
# shellcheck disable=SC2317

. t/lib/test-functions.sh
. t/lib/test-find-exec.sh
plan 16

EXEPATH=util/bin2bit
EXECBIN="$PWD/$EXEPATH"
EXENAME="$(basename "$EXEPATH")"
cd "$tmp" || die "error: cd \$tmp"

if find_exec
then
	#
	# Case 0: partial byte (currently
	# silently truncated, not an error)
	#
	my=error.0
	mc="case 0"
	cat >"$my".txt <<'EOF'
0001001101111110
1101010
EOF

	"$EXECBIN" "$my".txt >"$my".out 2>"$my".err

	ok "$mc - bin2bit exits normally" || {
		diag "error: bin2bit exited with status $?"
		diag <"${my}.err"
	}

	# is wc(1) portable enough for people? i hope so...
	size="$(wc -c <"$my".obj | awk '{print $1}')"
	test "$size" -eq 2
	ok "$mc - object size is 2" || {
		diag "Test for object size failed!"
		diag <<EOM
       got: $size
  expected: 2
EOM
	}

	hexdump -C "$my".obj > "$my".got
	printf '\x13\x7e' | hexdump -C >"$my".wnt
	is "$my".got "$my".wnt "$mc - object 137E"

	cat <<EOF >"$my".wnt
2 octets written
EOF
	is "$my".err "$my".wnt "$mc - stderr reports 2 octets"

	#
	# Case 1: misaligned bit
	#
	my=error.1
	mc="case 1"
	cat >"$my".txt <<'EOF'
000100110111111; oops
1101010000000000
EOF

	"$EXECBIN" "$my".txt >"$my".out 2>"$my".err

	r=$? ; test "$r" -eq 255
	ok "$mc - bin2bit exits abnormally" || {
		diag "error: bin2bit exited with status $r"
		diag ".... but I expected to see status 255."
	}

	size="$(wc -c <"$my".obj | awk '{print $1}')"
	test "$size" -eq 2
	ok "$mc - object size is 2" || {
		diag "Test for object size failed!"
		diag <<EOM
       got: $size
  expected: 2
EOM
	}

	hexdump -C "$my".obj > "$my".got
	printf '\x13\x7f' | hexdump -C >"$my".wnt
	is "$my".got "$my".wnt "$mc - object 137F"

	cat <<EOF >"$my".wnt
${my}.txt:2:2: start of word should be separated by whitespace
2 octets written
EOF
	is "$my".err "$my".wnt "$mc - stderr reports error and 2 octets"

	#
	# Case 2: weird character
	#
	my=error.2
	mc="case 2"
	cat <<EOF >"$my".txt
; Comment
; Comment
0010010010010OI0
EOF

	"$EXECBIN" "$my".txt >"$my".out 2>"$my".err

	r=$? ; test "$r" -eq 255
	ok "$mc - bin2bit exits abnormally" || {
		diag "error: bin2bit exited with status $r"
		diag ".... but I expected to see status 255."
	}

	size="$(wc -c <"$my".obj | awk '{print $1}')"
	test "$size" -eq 1
	ok "$mc - object size is 1" || {
		diag "Test for object size failed!"
		diag <<EOM
       got: $size
  expected: 1
EOM
	}

	hexdump -C "$my".obj > "$my".got
	printf '\x24' | hexdump -C >"$my".wnt
	is "$my".got "$my".wnt "$mc - object 24"

	cat <<EOF >"$my".wnt
${my}.txt:3:14: invalid character: \`O'
1 octet written
EOF
	is "$my".err "$my".wnt "$mc - stderr reports error and 1 octet"

	#
	# Dots and underscores are connectors, not separators
	#
	my=error.3
	mc="connectors"
	cat <<EOF >"$my".txt
; AND  R5, R2,       # 0
  0101 101 0_10 1 0_0000 ; 5AA0
; ADD  R5, R5,       #15
  0001 ;01 1_01 1 0_1111 ; 1B6F
; BR    z            # 2
  0000 010 0__0000__0010 ; 0402
; ADD  R5, R5,       #-1
  0001 101 1_01 1 1_1111 ; 1B7F
; BR   nzp           #-3
  0000 111 1__1111__1101 ; 0FFD
; TRAP     x     2     5
  1111  0000  0010  0101 ; F025
EOF

	"$EXECBIN" "$my".txt >"$my".out 2>"$my".err

	r=$? ; test "$r" -eq 255
	ok "$mc - bin2bit exits abnormally" || {
		diag "error: bin2bit exited with status $r"
		diag ".... but I expected to see status 255."
	}

	# writes normally up to 5AA0 1... then
	# everything gets misplaced ...040, where
	# the first word finishes mid-sentence
	hexdump -C "$my".obj > "$my".got
	printf '\x5a\xa0\x10\x40' | hexdump -C >"$my".wnt
	is "$my".got "$my".wnt "$mc - object 5AA0 1040"

	cat <<EOF >"$my".wnt
${my}.txt:6:21: start of word should be separated by whitespace
4 octets written
EOF
	is "$my".err "$my".wnt "$mc - stderr reports error and 4 octets"
else
	skip 15 "no $EXEPATH"
fi

conclude

# vim: ft=sh:
