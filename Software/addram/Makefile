PROJECT=addram
CC=m68k-amigaos-gcc
CFLAGS=-lamiga -mcrt=nix13 -mcpu=68000 -Wall
.PHONY:	clean all
all:	$(PROJECT)

OBJ = config.o \
	addram.o

SRCS = $(OBJ:%.o=%.c)

addram: $(SRCS)	*.h
	${CC} -o $@ $(CFLAGS) $(SRCS)

clean:
	-rm $(PROJECT)
