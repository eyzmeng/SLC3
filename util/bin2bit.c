/*
 * bin2bit.c
 *
 * A trivial machine code writer
 */

#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

/* Error message for incorrect usage. */
static char *USAGE = "usage: %s infile [outfile]\n";

/* Shared buffer for and error reporting. */
#define WIDTH       (80)
static char LINE[WIDTH];

/* Number of bits in a byte. Always 8. */
#define OCTET_BIT   (8)

/* Bit mask for an octet. */
#define OCTET_MASK  (0xFF)

/* Number of bytes in a word (16-bit = 2 bytes) */
#define WORD_SIZE   (2)

/* Shared state */
struct parse_state {
	char * infile;  /*  input file path (NULL if  stdin) */
	char *outfile;  /* output file path (NULL if stdout) */
	size_t h;  /* horizontal offset */
	size_t v;  /* vertical offset */
	size_t n;  /* number of bytes written */
	uint8_t c; /* comment? */
	uint8_t s; /* start of word? */
	uint8_t e; /* exponent (0 thru 7) */
	uint8_t b; /* current byte */
};

/*
 * Error codes.  See RETURN VALUE.
 */

#define RV_DEATH  1
#define RV_CROAK  255

/*
 * ASCII escape table for a single-quoted char.
 * (No - don't remind me of EBCDIC, please!)
 */
static const char *QASC[] = {
	/* ASCII range */
	/* NUL     SOH     STX     ETX     EOT     ENQ     ACK     BEL */
	 "\\x00","\\x01","\\x02","\\x03","\\x04","\\x05","\\x06", "\\a" ,
	/* BS      HT      LF      VT      FF      CR      SO      SI  */
	  "\\b" , "\\t" , "\\n" , "\\v" , "\\f" , "\\r" ,"\\x0e","\\x0f",
	/* DLE     DC1     DC2     DC3     DC4     NAK     SYN     ETB */
	 "\\x10","\\x11","\\x12","\\x13","\\x14","\\x15","\\x16","\\x17",
	/* CAN     EM      SUB     ESC     FS      GS      RS      US  */
	 "\\x18","\\x19","\\x1a", "\\e" ,"\\x1c","\\x1d","\\x1e","\\x1f",
	/* x20     x21     x22     x23     x24     x25     x26     x27 */
	   " "  ,  "!"  ,  "\"" ,  "#"  ,  "$"  ,  "%"  ,  "&"  , "\\'" ,
	/* x28     x29     x2A     x2B     x2C     x2D     x2E     x2F */
	   "("  ,  ")"  ,  "*"  ,  "+"  ,  ","  ,  "-"  ,  "."  ,  "/"  ,
	/* x30     x31     x32     x33     x34     x35     x36     x37 */
	   "0"  ,  "1"  ,  "2"  ,  "3"  ,  "4"  ,  "5"  ,  "6"  ,  "7"  ,
	/* x38     x39     x3A     x3B     x3C     x3D     x3E     x3F */
	   "8"  ,  "9"  ,  ":"  ,  ";"  ,  "<"  ,  "="  ,  ">"  ,  "?"  ,
	/* x40     x41     x42     x43     x44     x45     x46     x47 */
	   "@"  ,  "A"  ,  "B"  ,  "C"  ,  "D"  ,  "E"  ,  "F"  ,  "G"  ,
	/* x48     x49     x4A     x4B     x4C     x4D     x4E     x4F */
	   "H"  ,  "I"  ,  "J"  ,  "K"  ,  "L"  ,  "M"  ,  "N"  ,  "O"  ,
	/* x50     x51     x52     x53     x54     x55     x56     x57 */
	   "P"  ,  "Q"  ,  "R"  ,  "S"  ,  "T"  ,  "U"  ,  "V"  ,  "W"  ,
	/* x58     x59     x5A     x5B     x5C     x5D     x5E     x5F */
	   "X"  ,  "Y"  ,  "Z"  ,  "["  ,  "\\" ,  "]"  ,  "^"  ,  "_"  ,
	/* x60     x61     x62     x63     x64     x65     x66     x67 */
	   "`"  ,  "a"  ,  "b"  ,  "c"  ,  "d"  ,  "e"  ,  "f"  ,  "g"  ,
	/* x68     x69     x6A     x6B     x6C     x6D     x6E     x6F */
	   "h"  ,  "i"  ,  "j"  ,  "k"  ,  "l"  ,  "m"  ,  "n"  ,  "o"  ,
	/* x70     x71     x72     x73     x74     x75     x76     x77 */
	   "p"  ,  "q"  ,  "r"  ,  "s"  ,  "t"  ,  "u"  ,  "v"  ,  "w"  ,
	/* x78     x79     x7A     x7B     x7C     x7D     x7E     DEL */
	   "x"  ,  "y"  ,  "z"  ,  "{"  ,  "|" ,   "}"  ,  "~"  ,"\\x7f",

	/* 8-bit wannabes */
	 "\\x80","\\x81","\\x82","\\x83","\\x84","\\x85","\\x86","\\x87",
	 "\\x88","\\x89","\\x8a","\\x8b","\\x8c","\\x8d","\\x8e","\\x8f",
	 "\\x90","\\x91","\\x92","\\x93","\\x94","\\x95","\\x96","\\x97",
	 "\\x98","\\x99","\\x9a","\\x9b","\\x9c","\\x9d","\\x9e","\\x9f",
	 "\\xa0","\\xa1","\\xa2","\\xa3","\\xa4","\\xa5","\\xa6","\\xa7",
	 "\\xa8","\\xa9","\\xaa","\\xab","\\xac","\\xad","\\xae","\\xaf",
	 "\\xb0","\\xb1","\\xb2","\\xb3","\\xb4","\\xb5","\\xb6","\\xb7",
	 "\\xb8","\\xb9","\\xba","\\xbb","\\xbc","\\xbd","\\xbe","\\xbf",
	 "\\xc0","\\xc1","\\xc2","\\xc3","\\xc4","\\xc5","\\xc6","\\xc7",
	 "\\xc8","\\xc9","\\xca","\\xcb","\\xcc","\\xcd","\\xce","\\xcf",
	 "\\xd0","\\xd1","\\xd2","\\xd3","\\xd4","\\xd5","\\xd6","\\xd7",
	 "\\xd8","\\xd9","\\xda","\\xdb","\\xdc","\\xdd","\\xde","\\xdf",
	 "\\xe0","\\xe1","\\xe2","\\xe3","\\xe4","\\xe5","\\xe6","\\xe7",
	 "\\xe8","\\xe9","\\xea","\\xeb","\\xec","\\xed","\\xee","\\xef",
	 "\\xf0","\\xf1","\\xf2","\\xf3","\\xf4","\\xf5","\\xf6","\\xf7",
	 "\\xf8","\\xf9","\\xfa","\\xfb","\\xfc","\\xfd","\\xfe","\\xff",
};


/*
 * In its 1-argument form, bin2bit takes the input file name
 * and figures out an output file name with an *.obj suffix.
 * Here we produce that output file name.
 *
 * This function always success unless malloc(3) fails.
 * Caller is responsible for freeing the returned string.
 *
 * It should work for file paths with directory components too.
 */

char *
translate(char *filename)
{
	/* Figure out the length of basename */
	size_t dot = strlen(filename);
	char *dotptr;
	if ((dotptr = strrchr(filename, '.'))
	    && strcmp(dotptr, ".obj") != 0)
	{
		dot = dotptr - filename;
	}
	size_t len = dot + 5; /* ".obj" and \0 */
	char *objectname;
	if (!(objectname = (char *) malloc(len * sizeof(char)))) {
		return NULL;
	}
	/*
	 * NOTE: strcpy(3) copies the terminating \0,
	 * so we shouldn't have to bring our own
	 */
	strncpy(objectname, filename, len);
	strcpy(objectname + dot, ".obj");
	return objectname;
}


int
readabit(struct parse_state *st, char const o)
{
	/* Start word */
	if (   o == '\t' || o == ' ' || o == '\r'
	    || o == '.'  || o == '_' )
	{
		st->s = 1;
		return 0;
	}
	/* Start word + exit comment */
	if (o == '\n') {
		st->s = 1;
		st->c = 0;
		st->v++;
		st->h = 0;
		return 0;
	}
	/* In comment */
	if (st->c) {
		return 0;
	}
	/*
	 * For every word (even number of octets), we
	 * should have read a word boundary.  This
	 * guards against basic programming slip-ups
	 * like mixing two instructions on one line.
	 */
	if (st->n % WORD_SIZE == 0 && st->e == 0 && !st->s) {
		strncpy(LINE,
			"start of word should be "
			"separated by something",
			WIDTH - 1);
		LINE[WIDTH] = '\0';
		return 1;
	}
	/* Enter comment */
	if (o == ';' || o == '#') {
		st->c = 1;
		return 0;
	}
	/* Exit word */
	if (o == '0' || o == '1') {
		st->b |= (o - '0') << (OCTET_BIT - 1 - st->e);
		st->e++;
		st->s = 0;
		return 0;
	}
	snprintf(LINE, WIDTH - 1,
		"error: invalid character: `%s'",
		QASC[o & OCTET_MASK]);
	return 1;
}

int
writedat(struct parse_state *st, FILE *fout)
{
	/* Don't WRITE if in comment or not enough bits. */
	if (st->c || st->e < OCTET_BIT) {
		return 0;
	}
#ifdef BIN2BIT_DEBUG
	fprintf(stderr, "WRITE %02hhx\n", st->b);
#endif
	size_t w = fwrite(&st->b, sizeof(char), 1, fout);
	if (w < 1) {
		return 1;
	}
	st->b = 0;
	st->n += w;
	st->e = 0;
	return 0;
}


/*
 * The main function delegates to us when the
 * command-line args are parsed and the parser
 * is initialized to all zeros.
 */

int
encode(struct parse_state* st)
{
	int lasterr = 0;
	int lastret = 0;
	char *lastwrd;
	char *blame = NULL;
	FILE *fin   = NULL;
	FILE *fout  = NULL;

	if (st->infile) {
		if (!(fin = fopen(st->infile, "r"))) {
			lasterr = errno;
			lastret = RV_DEATH;
			blame = st->infile;
			goto PANIC;
		}
	}
	else {
		fin = stdin;
	}
	if (st->outfile) {
		if (!(fout = fopen(st->outfile, "w"))) {
			lasterr = errno;
			lastret = RV_DEATH;
			blame = st->outfile;
			goto PANIC;
		}
	}
	else {
		fout = stdout;
	}

	/*
	 * Begin parsing.  Errors from this point on
	 * will report a line number and column number.
	 */
	st->h = 1;
	st->v = 1;
	int z;
	while (!feof(fin)) {
		z = fread(LINE, sizeof(char), WIDTH, fin);
		if (z < WIDTH && ferror(fin)) {
			lasterr = errno;
			lastret = RV_DEATH;
			blame = NULL;
			for (int i = 0; i < z; ++i) {
				if (LINE[i] == '\n') {
					st->v++;
					st->h = 1;
				}
				else {
					st->h++;
				}
			}
			goto PANIC;
		}
		for (int i = 0; i < z; ++i) {
#ifdef BIN2BIT_DEBUG
			fprintf(stderr,
				"PROC %zu:%02zu(c=%d, s=%d) "
				"%02d/%02d [%02o] '%s' / %02hhx\n",
				st->v, st->h, st->c, st->s, i, z,
				st->e, QASC[LINE[i]], st->b);
#endif /* BIN2BIT_DEBUG */
			if (readabit(st, LINE[i])) {
				lasterr = 0;
				lastret = RV_CROAK;
				blame = NULL;
				goto PANIC;
			}
			st->h++;
			if (writedat(st, fout)) {
				lasterr = 0;
				lastret = RV_DEATH;
				blame = st->outfile;
				goto PANIC;
			}
		}
	}

	if (st->outfile) {
		fclose(fout);
	}
	if (st->infile) {
		fclose(fin);
	}
	return lastret;

PANIC:
	/* LINE is unset for system errors; use strerror(3). */
	if (lasterr) {
		lastwrd = strerror(lasterr);
	}
	else {
		lastwrd = LINE;
	}
	/*
	 *                  0          len
	 *                  |-----------|
	 *     <blame> ": "   <lastwrd>
	 *   |--------------|-----------|
	 *   0             off         W-1
	 */
	size_t len = strnlen(lastwrd, WIDTH - 1);
	size_t off = blame ? strlen(blame) + 2 : 0;
	if (len > WIDTH - 1) {
		len = WIDTH - 1;
		off = 0;
	}
	else if (off > WIDTH - 1 - len) {
		off = WIDTH - 1 - len;
	}
	assert(off + len <= WIDTH - 1);
	if (off > 2) {
		memmove(LINE + off, lastwrd, len * sizeof(char));
		/* GCC won't let me do this :( */
		/* strncpy(LINE + off - 2, ": ", 2); */
		LINE[off + 0] = ':';
		LINE[off + 1] = ' ';
		strncpy(LINE, blame, off - 2);
	}
	/*
	 * This shouldn't happen, since we always have
	 * someone to blame in a system error.  But ok...
	 */
	else {
		memmove(LINE, lastwrd, len * sizeof(char));
	}
	LINE[off + len] = '\0';

	/* These files may not be open yet. */
	if (fout && st->outfile) {
		fclose(fout);
	}
	if (fin && st->infile) {
		fclose(fin);
	}

	return lastret;
}


int
main(int argc, char **argv)
{
	char *prog;
	struct parse_state st = {
		NULL, /* .infile */
		NULL, /* .outfile */
		0,    /* .h */
		0,    /* .v */
		0,    /* .n */
		0,    /* .c */
		1,    /* .s */
		0,    /* .e */
		0,    /* .b */
	};

	/*
	 * Obtain program name from argv[0], if one exists.
	 * (argv[0] holds the filename to us conventionally; but
	 * that is only convention.  Someone could make exec us
	 * without setting one (though we'd die anyways...))
	 */
	if (argc > 0) {
		prog = argv[0];
		argv++; argc--;
	}
	else {
		prog = "bin2bit";
	}

	int outfile_new = 0;
	if (argc == 1) {
		st.infile = argv[0];
		if (strcmp(st.infile, "-") == 0) {
			st.infile = NULL;
			st.outfile = NULL;
		}
		else if (!(st.outfile = translate(st.infile))) {
			perror(NULL);
			return RV_DEATH;
		}
		outfile_new = 1; /* remember to free */
	}
	else if (argc == 2) {
		st.infile = argv[0];
		if (strcmp(st.infile, "-") == 0) {
			st.infile = NULL;
		}

		st.outfile = argv[1];
		if (strcmp(st.outfile, "-") == 0) {
			st.outfile = NULL;
		}
	}
	else {
		fprintf(stderr, USAGE, prog);
		return RV_DEATH;
	}

	int rv;
	if ((rv = encode(&st))) {
		if (st.v && st.h) {
			fprintf(stderr, "%s:%zu:%zu: ",
				st.infile ? st.infile : "<stdin>",
				st.v, st.h);
		}
		fprintf(stderr, "%.*s\n", WIDTH, LINE);
	}

	fprintf(stderr, "%zu octet%s written\n", st.n, st.n == 1 ? "" : "s");
	if (outfile_new) {
		free(st.outfile);
	}
	return rv;
}
