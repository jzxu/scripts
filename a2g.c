#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

enum { BUFSIZE = 4096 };

int main(int argc, char *argv[]) {
	char buf[BUFSIZE], temp, *start, *end, *endp;
	double x;
	FILE *input;

	if (argc >= 2) {
		if (!(input = fopen(argv[1], "r"))) {
			perror("");
			exit(1);
		}
	} else {
		input = stdin;
	}
	while (fgets(buf, BUFSIZE, input)) {
		end = buf;
		while (1) {
			for (start = end; *start != '\0' && isspace(*start); ++start) {
				fputc(*start, stdout);
			}
			if (*start == '\0') {
				break;
			}
			for (end = start + 1; *end != '\0' && !isspace(*end); ++end)
				;
			if (*end == '\0') {
				fprintf(stderr, "overflow\n");
				exit(1);
			}
			temp = *end;
			*end = '\0';
			x = strtod(start, &endp);
			if (endp != end) {
				printf("%s", start);
			} else {
				printf("%g", x);
			}
			*end = temp;
		}
	}
	return 0;
}

