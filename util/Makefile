prog	= bin2bit bit2bin
docs	= bit2bin.1
CFLAGS  += -Wall -Wextra -Werror -Wpedantic
.SUFFIXES: .pl .1

all: ${prog} ${docs}

.PHONY: clean
clean:
	-rm -f ${prog} ${docs} ${bin}

.pl:
	cat <$< >$@
	chmod +x $@

.pl.1:
	pod2man --section=1 --date=$$(date +'%Y-%m-%d') $< >$@
