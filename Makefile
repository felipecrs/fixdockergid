CFILE = fixdockergid.c
HFILE = fixdockergid.h
SHFILE = fixdockergid.sh
EXEC = fixdockergid

all: $(EXEC)

$(EXEC): $(CFILE) $(HFILE)
	gcc -m32 -o $@ $(CFILE)

$(HFILE): $(SHFILE)
	xxd -i $(SHFILE) $@

clean:
	rm -rf $(HFILE) $(EXEC)