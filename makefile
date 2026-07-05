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
LUAJIT := $/bin$/resty$/luajit.exe
LAUFLAGS := $/git$/lauzy$/bin$/lau.zy -f -t -d ngx


# https://unix.stackexchange.com/questions/140912/no-target-error-using-make
# https://stackoverflow.com/questions/2908057/can-i-compile-all-cpp-files-in-src-to-os-in-obj-then-link-to-binary-in/2908351#2908351

# SRC and DST path cannot end with $/ bcoz gnu make cannot understand target $(SRC)%.lua without the slash as separator
SRC := .$/lau
DST := .$/losty
BIN := .$/bin
BIN_CLI_LAU := .$/bin$/new$/lau
BIN_CLI_LUA := .$/bin$/new$/lua
LAU := $(wildcard $(SRC)/*.lau) $(wildcard $(SRC)/sql/*.lau) $(wildcard $(BIN)/*.lau)
#LUA := $(patsubst $(DST)/%.lau,$(DST)/%.lua,$(LAU))
LUA := $(patsubst %.lau,%.lua,$(subst $(SRC)/,$(DST)/,$(LAU)))
TXT := $(DST)/stops_en.txt
LAU_NEW := $(wildcard $(BIN_CLI_LAU)/*.lau) $(wildcard $(BIN_CLI_LAU)/views/*.lau)
LUA_NEW := $(patsubst $(BIN_CLI_LAU)/%.lau,$(BIN_CLI_LUA)/%.lua,$(LAU_NEW))


.PHONY: all clean
#all: ; $(info $$LUA is [${LUA}]) $(info $$LAU is [${LAU}])
all: $(LUA) $(TXT) $(LUA_NEW)

# Cannot use $< in recipe bcoz windows require backslash
$(DST)/%.lua: $(SRC)/%.lau
	$(LUAJIT) $(LAUFLAGS) $(SRC)$/$*.lau $(DST)$/$*.lua

$(DST)/stops_en.txt: $(SRC)/stops_en.txt
	$(CP) $(SRC)$/stops_en.txt $(DST)$/

$(BIN)/%.lua: $(BIN)/%.lau
	$(LUAJIT) $(LAUFLAGS) $(BIN)$/$*.lau $(BIN)$/$*.lua

$(BIN_CLI_LUA)/%.lua: $(BIN_CLI_LAU)/%.lau
	$(LUAJIT) $(LAUFLAGS) $(BIN_CLI_LAU)$/$*.lau $(BIN_CLI_LUA)$/$*.lua


clean:
	$(RMD) $(DST)
	$(RM) $(BIN)$/*.lua
