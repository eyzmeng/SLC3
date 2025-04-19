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

	cat >basic.2.txt <<'EOF'
0011 ; STI
  000 ; R0 ;;!;!;!;!;!;!;!;;;
    0.0.0 ; nonsense
       0   ; what
         0   .
           0   .
        0    .
       _ . ;h
   _.0  ;e
     _     ;ll
    0    ; o?
     .
;;;; ???
;;;;; oh wait I forgot that was just x3000
;
; lol

1111 ; oh no, a TRAP
0000 ; what's it going to do?
0010 ; hmm
0 ; oh no....
1 ; it'd better not
0 ; quit my program
1 ; Aw really? <:(
EOF

	note "input:"
	note <basic.2.txt

	"$EXECBIN" basic.2.txt >basic.2.out 2>basic.2.err

	note "output:"
	note <basic.2.out

	ok "bin2bit exits normally, again" || {
		diag "error: bin2bit exited with status $?"
		diag <basic.2.err
	}

	note "$ ls -l basic.2.*"
	# shellcheck disable=SC2012
	ls -l basic.2.* 2>&1 | note
	test -r basic.2.obj
	ok "object exists, again" || touch basic.2.obj
	note "$ hd -C basic.2.obj"
	hexdump -C basic.2.obj |
		tee basic.2.got | note
	printf '\x30\x00\xf0\x25' |
		hexdump -C >basic.2.wnt
	is basic.2.got basic.2.wnt "object 3000 F025"

	note "$ cat basic.2.err"
	note <basic.2.err
	cat <<EOF >basic.2.wnt
4 octets written
EOF
	is basic.2.err basic.2.wnt "stderr reports 4 octets"
else
	skip 8 "no $EXEPATH"
fi

conclude

# vim: ft=sh:
