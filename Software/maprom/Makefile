PROJECT=maprom
CC=m68k-amigaos-gcc
CFLAGS=-lamiga -mcrt=nix13 -mcpu=68000 
.PHONY:	clean all
all:	$(PROJECT)

$(PROJECT):	$(PROJECT).c
	$(CC) $(CFLAGS) $^ -o $@

clean:
	-rm $(PROJECT)
