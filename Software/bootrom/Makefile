PROGRAM=bootrom

INCLUDE=/opt/amiga/m68k-amigaos/ndk-include
AS=vasmm68k_mot
ASFLAGS=-Fhunk -I$(INCLUDE) -quiet -align
LINKER=vlink
LINKFLAGS=-bamigahunk -s -sc -sd -mrel
OBJDIR=obj

.PHONY: all clean rom

SRCS = $(PROGRAM).s
OBJS = $(SRCS:%.s=$(OBJDIR)/%.o)

all:	$(PROGRAM)
rom:	$(ROMNAME)

$(OBJDIR)/%.o: %.s
	mkdir -p $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(PROGRAM): $(OBJS)
	$(LINKER) $(LINKFLAGS) -o $@ $<

clean:
	rm -f $(OBJDIR)/*.o
	rm -f $(PROGRAM)
