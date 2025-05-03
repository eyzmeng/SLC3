package Mini::LC3;

use 5.010;
use strict;
use warnings;

use Carp;

use constant {
	# Opcode (bit masks)
	OP_BR   => 0x0001, OP_ADD  => 0x0002, OP_LD   => 0x0004, OP_ST   => 0x0008,
	OP_JSR  => 0x0010, OP_AND  => 0x0020, OP_LDR  => 0x0040, OP_STR  => 0x0080,
	OP_RTI  => 0x0100, OP_NOT  => 0x0200, OP_LDI  => 0x0400, OP_STI  => 0x0800,
	OP_JMP  => 0x1000, OP_RES  => 0x2000, OP_LEA  => 0x4000, OP_TRAP => 0x8000,

	# Service routines
	SR_GETC  => 0x0020, SR_OUT   => 0x0021, SR_PUTS  => 0x0022,
	SR_IN    => 0x0023, SR_PUTSP => 0x0024, SR_HALT  => 0x0025,

	# Condition codes
	CC_N => 4, CC_Z => 2, CC_P => 1,

	# Memory-mapped (built-in labels?)
	MM_KBSR => 0xFE00,
	MM_KBDR => 0xFE02,
	MM_DSR  => 0xFE04,
	MM_DDR  => 0xFE06,
};

sub new
{
	my $class = shift;
	my $self = bless {}, $class;
	# Register file (R0-7 PC CC)
	$self->{R} = "\0" x 20;
	# Memory array (2^16 words)
	$self->{M} = "\0" x 0x20000;
	# Service Routines
	$self->{T} = [];
	# Symbol table
	$self->{S} = {};
	# Last error OR "HALT"
	$self->{E} = undef;
	$self->{DEBUG} = 0;
	# Don't start at PC = 0 for goodness sake...
	$self->PC(0x3000);
	# Set CC to something so that Branch always
	# (0000 111[9-bit offset]) would actually branch
	$self->CC(CC_Z);

	# Define TRAPs
	$self->trap(
		(SR_GETC) => sub {
			my $self = shift;
			read STDIN, my $char, 1;
			my $data = ord($char);
			my $word = $data & 0xFF;
			$self->debug("    GET a char %X[%02X]\n",
				$data, $word);
			$self->R0($word);
			return;
		},
		(SR_OUT) => sub {
			my $self = shift;
			my $data = $self->R0();
			my $char = chr($data & 0xFF);
			$self->debug("    OUT a char %02X['%s']\n",
				$data, $char);
			print STDOUT $char;
			STDOUT->flush();
			return;
		},
		(SR_PUTS) => sub {
			my $self = shift;
			my $ptr = $self->R0();
			while (my $data = $self->M($ptr++)) {
				my $char = chr($data & 0xFF);
				$self->debug("    PUT a char %02X['%s']\n",
					$data, $char);
				print STDOUT $char;
			}
			STDOUT->flush();
			return;
		},
		(SR_IN) => sub {
			my $self = shift;
			print "Input a character: ";
			chomp my $input, <STDIN>;
			# Pretend we only read one character
			$self->R0(ord(substr $input, 0, 1) & 0xFF);
			return;
		},
		(SR_HALT) => sub {
			my $self = shift;
			return $self->halt();
		},
	);
	use Data::Dumper;
	return $self;
}

# Machine-code error
sub error
{
	my $self = shift;
	# "HALT" is not an error!
	return $self->{E} eq 'HALT' ? undef : $self->{E} unless @_;
	my ($error) = @_;
	$self->{E} = $error;
}

sub halt
{
	my $self = shift;
	$self->{E} = 'HALT';
	return;
}

sub unhalt
{
	my $self = shift;
	undef $self->{E};
	return;
}

sub debug
{
	my $self = shift;
	if ($self->{DEBUG}) {
		my $fmt = shift;
		print STDERR sprintf($fmt, @_);
	}
}

sub halted
{
	my $self = shift;
	defined $self->{E} && $self->{E} eq 'HALT';
}

sub R {
	my $self = shift;
	my ($off, $arg) = @_;
	# This used to be an assertion... until it isn't
	# (because my rule of thumb: if it is well-defined enough,
	# it can be a public function.  I don't really see a reason
	# to hide it.  (Although in this circumstance it is only
	# guaranteed that $self->R(0 .. 7) would make sense...)
	0 <= $off < 10 or croak("Register index of bounds: $off");
	if (defined $arg) {
		$arg %= 0x10000;
		return vec($self->{R}, $off << 4, 16) = $arg;
	}
	else {
		return vec($self->{R}, $off << 4, 16);
	}
}

# API get/setter (some for us)
sub R0 { my $self = shift; $self->R(0, @_); }
sub R1 { my $self = shift; $self->R(1, @_); }
sub R2 { my $self = shift; $self->R(2, @_); }
sub R3 { my $self = shift; $self->R(3, @_); }
sub R4 { my $self = shift; $self->R(4, @_); }
sub R5 { my $self = shift; $self->R(5, @_); }
sub R6 { my $self = shift; $self->R(6, @_); }
sub R7 { my $self = shift; $self->R(7, @_); }
sub PC { my $self = shift; $self->R(8, @_); }

# CC only cares about the CC_N CC_Z CC_P bits.
sub CC {
	my $self = shift;
	my $MASK = CC_N | CC_Z | CC_P;
	if (@_) {
		my $arg = shift;
		$self->R(9, $arg & $MASK);
	}
	else {
		$self->R(9) & $MASK;
	}
}

sub M {
	my $self = shift;
	my ($off, $arg) = @_;
	0 <= $off < 0x10000 or die(sprintf(
		"Memory index of bounds: 0x%X", $off
	));
	if (defined $arg) {
		# Setting is only allowed in user space...
		$arg %= 0x10000;
		0x3000 <= $off < 0xFE00 or croak(sprintf(
			"Segmentation fault: 0x%04X", $off
		));
		vec($self->{R}, $off << 4, 16) = $arg;
	}
	else {
		# Access outside of user space not allowed.
		0x3000 <= $off < 0xFE00 or croak(sprintf(
			"Not implemented: 0x%04X", $off
		));
		vec($self->{R}, $off << 4, 16);
	}
}

# M with no memory restrictions
sub _M {
	my $self = shift;
	my ($off, $arg) = @_;
	0 <= $off < 0x10000 or die(sprintf(
		"Memory index of bounds: 0x%X", $off
	));
	if (defined $arg) {
		vec($self->{R}, $off << 4, 16) = $arg;
	}
	else {
		vec($self->{R}, $off << 4, 16);
	}
}

sub step
{
	my $self = shift;
	my $PC = $self->PC();
	my $IR = $self->M($PC);
	$self->debug("STEP %04X %04X\n", $PC, $IR);
	$self->PC(++$PC);
	$self->exec($IR);
}

#
# They call this *sign extension*....
# I'm a math nerd, so I'll call it modulo 2^n :)
#
sub _modulo
{
	my ($word, $bits) = @_;
	my $mod = 1 << $bits;
	$$word %= $mod;
	# Anything >= $mod/2 is negative
	$$word -= $mod unless $$word + $$word < $mod;
}

# Compute NZP bits...
sub _nzp
{
	my ($word) = @_;
	my $code = 0;
	$word %= 0x10000; # Just in case...
	$code |= CC_N if 0x8000 & $word;
	$code |= CC_Z if $word == 0;
	$code |= CC_P if $code == 0;
	$code;
}

# The LC-3 ISA:
#              B  A  9  8  7  6  5  4  3  2  1  0
#             ------------------------------------
#    BR 0001  [- NZP -][-   PC OFFSET (9-bit)   -]
#   ADD 0001  [- DST -][- SRC -][% ALU  operand %]
#    LD 0010  [- DST -][-   PC OFFSET (9-bit)   -]
#    ST 0011  [- SRC -][-   PC OFFSET (9-bit)   -]
#   JSR 0100   1 [-     PC OFFSET  (11-bit)     -]
#  JSRR 0100   0  0  0 [- BAE -] 0  0  0  0  0  0
#   AND 0101  [- DST -][- SRC -][% ALU  operand %]
#   LDR 0110  [- DST -][- BAE -][- OFFS (6-bit) -]
#   STR 0111  [- SRC -][- BAE -][- OFFS (6-bit) -]
#   RTI 1000  (Not implemented)
#   NOT 1001  [- DST -][- SRC -][% ALU  operand %]
#   LDI 1010  [- DST -][-   PC OFFSET (9-bit)   -]
#   STI 1011  [- SRC -][-   PC OFFSET (9-bit)   -]
#   JMP 1100   0  0  0 [- BAE -] 0  0  0  0  0  0
#   RES 1101  (Unused)
#   LEA 1110  [- DST -][-   PC OFFSET (9-bit)   -]
#  TRAP 1111   0  0  0  0 [-    TRAP  VECTOR    -]
#
# ALU operand                    1 [- IMMED (5) -]
#                                0  0  0 [- SR2 -]
#
sub exec
{
	my $self = shift;
	my ($IR) = @_;
	my $PC = $self->PC;

	# Take the most significant 4 bits,
	# and decode into a 16-bit flag.
	my $opcode = 1 << (($IR >> 12) & 0xF);

	# I'll do this in a bit.
	if ($opcode & OP_TRAP) {
		my $vec = $IR & 0xFF;
		$self->debug("  TRAP %02X\n", $vec);
		return $self->trap($vec);
	}

	#
	# Offset represents 9-bit PC offsets in:
	#
	#   BR
	#   LD LDI LEA
	#   ST STI
	#
	# As well as Base + 6-bit offset in:
	#
	#   LDR STR
	#
	# Handling this first because I want
	# to do BR as early as possible.
	#
	my $off;
	my $OFFMASK = OP_BR | OP_LEA
		| OP_LD | OP_LDR | OP_LDI
		| OP_ST | OP_STR | OP_STI
		;

	if ($opcode & $OFFMASK) {
		# Bit 0:9 (offset 0 width 9)
		$off = $IR & 0777;
	}

	my $lhs;
	#
	# Left-hand operand represents:
	#
	#   DST   in ADD AND NOT
	#   DST   in LD LDR LDI LEA
	#   SRC   in ST STR STI
	#   NZP   in BR
	#
	my $ALUMASK = OP_ADD | OP_AND | OP_NOT;
	my $LHSMASK = $ALUMASK | $OFFMASK;

	if ($opcode & $LHSMASK) {
		# Bit 9:3 (offset 9 width 3)
		$lhs = ($IR >> 9) & 0007;
	}

	my $rhs;
	#
	# Right-hand operand represents:
	#
	#   SRC   in ADD AND NOT
	#   BASE  in LDR STR
	#            JMP JSSR
	#
	# They should be derivable from both $IR and $offset.
	# We'll do it in the more straightforward way...
	# (That is, do not assume the knowledge of $offset.)
	#
	my $RHSMASK = $ALUMASK
		| OP_LDR | OP_STR
		| OP_JMP | OP_JSR
		;

	if ($opcode & $RHSMASK) {
		# Bit 6:3 (offset 6 size 3)
		$rhs = ($IR >> 6) & 0007;
	}

	# Handle PC-offset stuff
	if ($opcode & $OFFMASK) {
		if ($opcode & OP_BR) {
			_modulo(\$off, 9);
			$self->debug("  BR   %s%s%s off=%03X[%04X]\n",
				$lhs & CC_N ? "n" : " ",
				$lhs & CC_Z ? "z" : " ",
				$lhs & CC_P ? "p" : " ",
				$off & 0x1FF, $PC + $off);
			$self->PC($PC + $off) if $self->CC & $lhs;
			return;
		}
		if ($opcode & OP_LEA) {
			_modulo(\$off, 9);
			$self->debug("  LEA  R%d off=%03X => %04X\n",
				$lhs, $off & 0x1FF, $PC + $off);
			$self->R($lhs, $PC + $off);
			return;
		}
		# Effective address...
		#    PC + OFF9       for LD, ST
		#    M[PC + OFF9]    for LDI, STI
		#    R[BASE] + OFF6  for LDR, STR
		my $addr;
		if ($opcode & (OP_LDR | OP_STR)) {
			_modulo(\$off, 5);
			$addr = $self->R($rhs) + $off;
		} else {
			_modulo(\$off, 9);
			$addr = $PC + $off;
		}
		if ($opcode & (OP_LDI | OP_STI)) {
			$addr = $self->M($addr);
		}
		# LD loads M[PC + $off] into R[$lhs]
		# CC is updated to the sign of this word.
		if ($opcode & (OP_LD | OP_LDI | OP_LDR)) {
			my $word = $self->M($addr);
			$self->R($lhs, $word);
			$self->CC(_nzp($word));
			return;
		}
		# ST stores R[$lhs] into M[PC + $off]
		# CC updated similarly.
		if ($opcode & (OP_ST | OP_STI | OP_STR)) {
			my $word = $self->R($lhs);
			$self->M($addr, $word);
			$self->CC(_nzp($word));
			return;
		}
		# Unreachable
		die;
	}

	# Handle jump operations
	if ($opcode & (OP_JSR | OP_JMP)) {
		# Use Base in $rhs if JMP OR JSSR (Bit 11 = 0)
		if ($opcode & OP_JMP || !($IR & (1 << 11))) {
			my $tmp = $self->R($rhs);
			$self->R7($PC) if OP_JSR;
			$self->PC($tmp);
		}
		# JSR
		else {
			my $jmp = $IR;
			_modulo(\$jmp, 11);
			$self->R7($PC);
			$self->PC($PC + $jmp);
		}
	}

	# Handle ALU operations
	if ($opcode & $ALUMASK) {
		my $opl = $self->R($rhs);
		my ($opr, $res);

		# ALU NOT is the sole unary operation.
		unless ($opcode & OP_NOT) {
			# Immediate? (Bit 5)
			if ($IR & (1 << 5)) {
				$opr = $IR & 0x1F;
				_modulo(\$opr, 5);
			}
			# Or get SRC2 from bit 0:3...
			else {
				my $src = $IR & 0007;
				$opr = $self->R($src);
			}
		}

		if ($opcode & OP_AND) {
			my $res = $opl & $opr;
			$self->debug("  AND  R%d = (%04X & %04X) => %04X\n",
				$lhs, $opl % 0x10000,
				$opr % 0x10000, $res % 0x10000);
			$self->R($lhs, $res);
			$self->CC(_nzp($res));
			return;
		}
		if ($opcode & OP_ADD) {
			my $res = ($opl + $opr) % 0x10000;
			$self->debug("  ADD  R%d = (%04X + %04X) => %04X\n",
				$lhs, $opl % 0x10000,
				$opr % 0x10000, $res % 0x10000);
			$self->R($lhs, $res);
			$self->CC(_nzp($res));
			return;
		}
		if ($opcode & OP_NOT) {
			$self->debug("  NOT R%d = ~ (%04X) => %04X\n",
				$lhs, $opl % 0x10000,
				$res % 0x10000);
			my $res = ~$opl & 0x10000;
			$self->R($lhs, $res);
			$self->CC(_nzp($res));
			return;
		}
		# Unreachable
		die;
	}
}

# trap (0x25)            => executes TRAP
# trap (0x25, &SUB, ...) => defines TRAP
sub trap
{
	my $self = shift;
	my ($vec, $sir) = @_;
	0 < $vec < 0x100 or croak ("trap vector out of range: $vec");
	if (@_ == 1) {
		my $goodsub = ${$self->{T}}[$vec];
		if (defined $goodsub) {
			return $goodsub->($self, $vec);
		}
		# The Service Routine is at least above 0x200...
		# (i.e. the Trap table and Interrupt table)
		my $goodsir = $self->_M($vec);
		unless ($goodsir < 0x200) {
			$self->PC($goodsir);
			return;
		}
		$self->error(sprintf "Bad trap: 0x%02x", $vec);
		return 1;
	}
	if (@_ % 2) {
		croak ("trap() should be called with an even number "
			. "of arguments (got @{[scalar(@_)]})");
	}
	my %set = @_;
	while (($vec, $sir) = each %set) {
		if (!(defined $sir)) {
			$self->{T}->[$vec] = $sir;
			return;
		}
		ref($sir) eq 'CODE' or croak ("Service routine " .
			"should be a Perl CODE ref (for now...)");
		$self->{T}->[$vec] = $sir;
	}
}

sub load
{
	my $self = shift;
	my ($file, $fh) = @_;
	my $w;     # word (as binary string)
	my $n = 0; # position
	my $s = _read2(\$n, $fh, \$w, $file);
	croak "$file: $!" unless defined $s;
	croak "$file: missing ORIG address" unless $s;
	my $PC = vec $w, 0, 16;
	$self->PC($PC);
	my $offset = 0;
	while (!eof($fh)) {
		$s = _read2(\$n, $fh, \$w, $file);
		croak "$file: $!" unless defined $s;
		my $word = vec $w, 0, 16;
		$self->M($PC + $offset++, $word);
	}
	return $offset;
}

# This reads two raw bytes.
sub _read2 {
	my ($nref, $fh, $wref, $file) = @_;
	my $s = read $fh, $$wref, 2;
	if (defined $s) {
		$$nref += $s;
		if ($s < 2) {
			croak "$file:$$nref: deficient word size"
		}
	}
	return $s;
}

sub symload
{
	my $self = shift;
	my ($file, $fh) = @_;
	my $symb = 0;
	while (my $levi = <$fh>) {
		chomp $levi;
		$levi =~ s[^//\t*][];
		next unless length $levi;
		# Skip obvious garbage lines
		next if $levi =~ /Symbol table/i;
		next if $levi =~ /Scope level 0/i;
		next if $levi =~ /^[- ]+$/;
		next if $levi =~ /Symbol Name +Page Address/i;
		# Reverse string...
		my $evil = join '', reverse split //, $levi;
		# Split out the very last chunk, by any whitespace
		# (Note split ' ' rather than split / /, we're gracious...)
		my @plot = reverse
			map { join '', reverse split // }
			split ' ', $evil, 2;
		@plot == 2 or
			croak ("$file:$.: expected two columns");
		# A valid LC-3 address is a 4-digit hexadecimal number
		(my $addr = $plot[1]) =~ /[[:xdigit:]]{4}/i or
			croak ("$file:$.: expected address '$plot[1]'");
		# This returns the old address, if defined.
		# In scalar context, becomes 0/1....?
		$symb += !(defined $self->symbol($plot[0], hex $addr));
	}
	return $symb;
}

sub symbol
{
	my $self = shift;
	my $name = shift;

	if (@_) {
		my $addr = shift;
		my $old = $self->{S}->{$name};
		$self->{S}->{$name} = $addr;
		return $old;
	}

	return $self->{S}->{$name};
}

# Package ourselves
my @OPCODE = qw(
	OP_BR  OP_ADD OP_LD  OP_ST
	OP_JSR OP_AND OP_LDR OP_STR
	OP_RTI OP_NOT OP_LDI OP_STI
	OP_JMP OP_RES OP_LEA OP_TRAP
);

my @SYSCAL = qw(
	SR_GETC SR_OUT   SR_PUTS
	SR_IN   SR_PUTSP SR_HALT
);

my @NZPBIT = qw(
	CC_N CC_Z CC_P
);

our @ISA = 'Exporter';
our @EXPORT_OK = (@OPCODE, @SYSCAL, @NZPBIT);
our %EXPORT_TAGS = (
	OPCODE => \@OPCODE,
	SYSCAL => \@SYSCAL,
	NZPBIT => \@NZPBIT,
);

1;
