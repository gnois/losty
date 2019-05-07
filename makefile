# On Windows use mingw64\bin\mingw32-make.exe

# *nix
#/ = $(strip /)
#RM := rm
# Windows
/ = $(strip \)
RM := del

# Change path as needed
LUAJIT := $/app$/lua$/luajit.exe
LTFLAGS := $/luaty$/lt.lua -f -t -d ngx
PACKAGE := "package.path=package.path .. '/luaty/?.lua'"


# https://unix.stackexchange.com/questions/140912/no-target-error-using-make
# https://stackoverflow.com/questions/2908057/can-i-compile-all-cpp-files-in-src-to-os-in-obj-then-link-to-binary-in/2908351#2908351

# SRC and DST path cannot end with $/ bcoz gnu make cannot understand target $(SRC)%.lua without the slash as separator
SRC := .$/lt
DST := .$/losty
LT := $(wildcard $(SRC)/*.lt) $(wildcard $(SRC)/sql/*.lt)
#LUA := $(patsubst $(DST)/%.lt,$(DST)/%.lua,$(LT))
LUA := $(patsubst $(DST)/%.lt,$(DST)/%.lua,$(subst $(SRC)/,$(DST)/,$(LT)))


.PHONY: all clean
#all: ; $(info $$LUA is [${LUA}])echo Hello
all: $(LUA)

# Cannot use $< in recipe bcoz windows require backslash

$(DST)/%.lua: $(SRC)/%.lt
	$(LUAJIT) -e $(PACKAGE) $(LTFLAGS) $(SRC)$/$*.lt $(DST)$/$*.lua
# $(MAKE) -C $(SRC) $*.lua

clean:
	$(RM) $(DST)$/*.lua
	$(RM) $(DST)$/sql$/*.lua