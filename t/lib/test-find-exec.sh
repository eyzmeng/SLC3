#!/bin/sh
#
# t/lib/test-find-exec: test whether we can find executables
#
# This module defines just one function.
#

#
# find_exec() hears no arguments.
# To make it work set the following variables:
#
#    $EXEPATH       relative path to executable (the readable one)
#    $EXECBIN       absolute path to executable (the canonical one)
#    $EXENAME       name of the executable itself
#
# If structured decently, we should be able to assume
# that tests for $EXENAME live in t/$EXENAME*...
#
find_exec () {
	test -x "$EXECBIN"
	if ok "$EXEPATH is executable by us"
	then
		return 0
	fi
	diag "error: $EXENAME isn't there"
	diag <<EOM
I am a test for ${EXENAME} but I cannot execute \`${EXEPATH}'.
Either skip the t/${EXENAME}* tests or compile the requested program.
EOM
	return 1
}

return 0
