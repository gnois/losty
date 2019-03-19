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

# SRC path cannot end with $/ bcoz make cannot understand target $(SRC)%.lua without the slash as separator
SRC := .$/losty
LT := $(wildcard $(SRC)/*.lt) $(wildcard $(SRC)/sql/*.lt) 
LUA := $(patsubst $(SRC)/%.lt,$(SRC)/%.lua,$(LT))

.PHONY: all clean
all: $(LUA)

# Cannot use $< in recipe bcoz windows require backslash

$(SRC)/%.lua: $(SRC)/%.lt
	$(LUAJIT) -e $(PACKAGE) $(LTFLAGS) $(SRC)$/$*.lt .
# $(MAKE) -C $(SRC) $*.lua

clean:
	$(RM) $(SRC)$/*.lua
	$(RM) $(SRC)$/sql$/*.lua