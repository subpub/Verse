include config.unix

ifndef SQUISH
  $(error Please run ./configure first)
endif

SOURCE_FILES=$(shell $(SQUISH) --list-files)
MISSING_FILES=$(shell $(SQUISH) --list-missing-files)

all: verse.lua

verse.lua: $(SOURCE_FILES)
	./buildscripts/squish

install: verse.lua
	install -t $(LUA_DIR) -m 644 $^

clean:
	rm verse.lua

$(MISSING_FILES):
	mkdir -p "$(@D)"
	wget "$(PROSODY_URL)$@" -O "$@"

rsm.lib.lua:
	wget https://hg.prosody.im/prosody-modules/raw-file/tip/mod_mam/rsm.lib.lua -O rsm.lib.lua

release: $(MISSING_FILES)
	rm config.unix

.PHONY: all release clean install
