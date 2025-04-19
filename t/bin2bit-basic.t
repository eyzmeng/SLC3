#!/bin/sh

. t/lib/test-functions
plan 5

found=0

EXENAME=util/bin2bit
EXECBIN="$PWD/$EXENAME"
cd "$tmp" || die "error: cd \$tmp"
test -x "$EXECBIN"
if ok "$EXENAME is executable by us"
then
	found=1
else
	diag <<EOM
error: $EXENAME isn't there
I am a test for bin2bit but I cannot execute \`$EXENAME'.
Either skip the t/bin2bit* tests or compile the requested program.
EOM
fi

if [ "$found" -eq 0 ]
then
	skip 4 "no $EXENAME"
else
	cat >basic.1.txt <<'EOF'
0011000000000000
0001001100100100
1100000011011110
1111000000100101
EOF

	note "input:"
	note <basic.1.txt

	"$EXECBIN" basic.1.txt >basic.1.out 2>basic.1.err

	note "output:"
	note <basic.1.out

	ok "bin2bit exits normally" || {
		diag "error: bin2bit exited with status $?"
		diag <basic.1.err
	}

	note "$ ls -l basic.1.*"
	# shellcheck disable=SC2012
	ls -l basic.1.* 2>&1 | note
	test -r basic.1.obj
	ok "object exists" || touch basic.1.obj
	note "$ hd -C basic.1.obj"
	hexdump -C basic.1.obj |
		tee basic.1.got | note
	printf '\x30\x00\x13\x24\xc0\xde\xf0\x25' |
		hexdump -C >basic.1.wnt
	is basic.1.got basic.1.wnt "object 3000 1324 C0DE F025"

	note "$ cat basic.1.err"
	note <basic.1.err
	cat <<EOF >basic.1.wnt
8 octets written
EOF
	is basic.1.err basic.1.wnt "stderr reports 8 octets"
fi

# vim: ft=sh:
