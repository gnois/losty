# On Windows use  mingw64\bin\mingw32-make.exe SHELL=cmd
# Else its behaviour changes based on %PATH% env
# See https://stackoverflow.com/questions/47874932/why-does-make-exe-try-to-run-usr-bin-sh-on-windows


# *nix
#/ := $(strip /)
#RMD := rm -fr
#RM := rm
#CP := cp
# Windows
/ := $(strip \)
RMD := rmdir /s /q
RM := del
CP := copy

# Change path as needed
LUAJIT := $/app$/lua$/luajit.exe
LTFLAGS := $/luaty$/lt.lua -f -t -d ngx
PACKAGE := "package.path=package.path .. '/luaty/?.lua'"


# https://unix.stackexchange.com/questions/140912/no-target-error-using-make
# https://stackoverflow.com/questions/2908057/can-i-compile-all-cpp-files-in-src-to-os-in-obj-then-link-to-binary-in/2908351#2908351

# SRC and DST path cannot end with $/ bcoz gnu make cannot understand target $(SRC)%.lua without the slash as separator
SRC := .$/lt
DST := .$/losty
BIN := .$/bin
LT := $(wildcard $(SRC)/*.lt) $(wildcard $(SRC)/sql/*.lt) $(wildcard $(BIN)/*.lt)
#LUA := $(patsubst $(DST)/%.lt,$(DST)/%.lua,$(LT))
LUA := $(patsubst %.lt,%.lua,$(subst $(SRC)/,$(DST)/,$(LT)))
TXT := $(DST)/stops_en.txt


.PHONY: all clean
#all: ; $(info $$LUA is [${LUA}]) $(info $$LT is [${LT}])
all: $(LUA) $(TXT)

# Cannot use $< in recipe bcoz windows require backslash
$(DST)/%.lua: $(SRC)/%.lt
	$(LUAJIT) -e $(PACKAGE) $(LTFLAGS) $(SRC)$/$*.lt $(DST)$/$*.lua

$(DST)/stops_en.txt: $(SRC)/stops_en.txt
	$(CP) $(SRC)$/stops_en.txt $(DST)$/

$(BIN)/%.lua: $(BIN)/%.lt
	$(LUAJIT) -e $(PACKAGE) $(LTFLAGS) $(BIN)$/$*.lt $(BIN)$/$*.lua


clean:
	$(RMD) $(DST)
	$(RM) $(BIN)$/*.lua
