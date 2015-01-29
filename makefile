NAME = libdolina.a
VERSION = 0.1.0

ROOT_SOURCE_DIR = src
SRC = $(getSources)

SRC_TEST = $(filter-out $(ROOT_SOURCE_DIR)/app.d, $(SRC)) 
SRC_TEST += $(wildcard tests/*.d)

# Compiler flag
# -----------
DFLAGS += -lib
DFLAGS += -debug #compile in debug code
#DFLAGS += -g # add symbolic debug info
#DFLAGS += -w # warnings as errors (compilation will halt)
DFLAGS += -wi # warnings as messages (compilation will continue)

DFLAGS_TEST += -unittest
# DFLAGS_TEST += -main -quiet

# Linker flag
# -----------
#LDFLAGS += 
#LDFLAGS += -L-L/usr/lib/

# Version flag
# -----------
# VERSION_FLAG = -version=use_gtk

# Packages
# -----------
PKG = $(wildcard $(BIN)/$(NAME))
PKG_SRC = $(PKG) $(SRC) makefile

# -----------
# Libraries
# -----------


# serial
# -----------
LIB += $(D_DIR)/serial-port/libserial-port.a
INCLUDES += -I$(D_DIR)/serial-port/source

# -----------
# Test  library
# -----------

# unit-threaded
# -----------
LIB_TEST += $(D_DIR)/unit-threaded/libunit-threaded.a
INCLUDES_TEST += -I$(D_DIR)/unit-threaded/source

# dmocks-revived
# -----------
LIB_TEST += $(D_DIR)/DMocks-revived/libdmocks-revived.a
INCLUDES_TEST += -I$(D_DIR)/DMocks-revived

LIB_TEST += $(LIB)
INCLUDES_TEST += $(INCLUDES)

include common.mk
