HEADERS = $(wildcard ../*.inc) $(wildcard ../inc/*.inc) $(wildcard ../mgtk/*.inc) $(wildcard *.inc)

include ../res/Makefile.common

TARGETS = $(OUTDIR)/desktop.built

.PHONY: clean all
all: $(OUTDIR) $(TARGETS)

$(OUTDIR):
	mkdir -p $(OUTDIR)

clean:
	rm -f $(OUTDIR)/*.o
	rm -f $(OUTDIR)/*.list
	rm -f $(TARGETS)

$(OUTDIR)/desktop.o: desktop.s $(HEADERS) loader.s desktop_*.s init.s ovl*.s invoker.s ../mgtk/mgtk.s
	ca65 $(CAFLAGS) --listing $(basename $@).list -o $@ $<

# Built segments
$(OUTDIR)/%.built: $(OUTDIR)/%.o ../res/asm.cfg
	ld65 $(LDFLAGS) -o '$@' $<
