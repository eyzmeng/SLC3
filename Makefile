prog	= bin2bit bit2bin
docs	= bin2bit.1 bit2bin.1

.PHONY: all test clean
all: ${prog} ${docs}

.FORCE:

# XXX: how do i make recursive make less noisy???

util/bin2bit: .FORCE
	${MAKE} -C util bin2bit
bin2bit: util/bin2bit
	cp util/bin2bit bin2bit

util/bit2bin: .FORCE
	${MAKE} -C util bit2bin
bit2bin: util/bit2bin
	cp util/bit2bin bit2bin

bin2bit.1: util/bin2bit.1
	cp util/bin2bit.1 bin2bit.1

util/bit2bin.1: .FORCE
	${MAKE} -C util bit2bin.1
bit2bin.1: util/bit2bin.1
	cp util/bit2bin.1 bit2bin.1

test: ${prog}
	prove

clean:
	-rm -f ${prog} ${docs}
	${MAKE} -C util clean
