CC ?= cc
CFLAGS ?= -Os
LDFLAGS ?=
PREFIX ?= /usr

all: hello-make

hello-make: main.o
	$(CC) $(LDFLAGS) -o $@ $^

main.o: src/main.c
	$(CC) $(CFLAGS) -c -o $@ $<

install: hello-make
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 0755 hello-make $(DESTDIR)$(PREFIX)/bin/hello-make

clean:
	rm -f hello-make main.o

.PHONY: all install clean
