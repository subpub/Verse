SQUISH=./buildscripts/squish
PROSODY_URL=https://hg.prosody.im/0.9/raw-file/tip/
SOURCE_FILES=$(shell $(SQUISH) --list-files)
MISSING_FILES=$(shell $(SQUISH) --list-missing-files)

all: verse.lua

verse.lua: $(SOURCE_FILES)
	./buildscripts/squish

clean:
	rm verse.lua

$(MISSING_FILES):
	mkdir -p "$(@D)"
	wget "$(PROSODY_URL)$@" -O "$@"

rsm.lib.lua:
	wget https://hg.prosody.im/prosody-modules/raw-file/tip/mod_mam/rsm.lib.lua -O rsm.lib.lua

release: $(MISSING_FILES)

.PHONY: all release clean
