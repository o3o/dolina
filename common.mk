###############
# Common part
###############
DEFAULT: all
BIN = bin
DC = dmd
BASE_NAME = $(basename $(NAME))
NAME_TEST = test
DSCAN = $(D_DIR)/Dscanner/bin/dscanner
MKDIR = mkdir -p
RM = -rm -f

BITS ?= $(shell getconf LONG_BIT)
DCFLAGS += -m$(BITS)

getSources = $(shell find $(ROOT_SOURCE_DIR) -name "*.d")

# Version flag
# use: make VERS=x
# -----------
VERSION_FLAG += $(if $(VERS), -version=$(VERS), )

.PHONY: all clean clobber test testv run pkg pkgsrc tags syn style loc var ver help

all: builddir $(BIN)/$(NAME)

builddir:
	@$(MKDIR) $(BIN)

$(BIN)/$(NAME): $(SRC) $(LIB)| builddir
	$(DC) $^ $(DCFLAGS) $(DCFLAGS_IMPORT) $(DCFLAGS_LINK) $(VERSION_FLAG) -of$@

run: all
	$(BIN)/$(NAME)

## with unit_threaded:
## make test T=test_name
test: build_test
	@$(BIN)/$(NAME_TEST) $(T)

testv: build_test
	@$(BIN)/$(NAME_TEST) -d $(T)

build_test: $(BIN)/$(NAME_TEST)

$(BIN)/$(NAME_TEST): $(SRC_TEST) $(LIB_TEST)| builddir
	$(DC) $^ $(DCFLAGS_TEST) $(DCFLAGS_IMPORT_TEST) $(DCFLAGS_LINK) $(VERSION_FLAG) -of$@

pkgdir:
	$(MKDIR) pkg

pkg: $(PKG) | pkgdir
	tar -jcf pkg/$(BASE_NAME)-$(VERSION).tar.bz2 $^
	zip pkg/$(BASE_NAME)-$(VERSION).zip $^

pkgsrc: $(PKG_SRC) | pkgdir
	tar -jcf pkg/$(BASE_NAME)-$(VERSION)-src.tar.bz2 $^

tags: $(SRC)
	$(DSCAN) --ctags $^ > tags

style: $(SRC)
	$(DSCAN) --styleCheck $^

syn: $(SRC)
	$(DSCAN) --syntaxCheck $^

loc: $(SRC)
	$(DSCAN) --sloc $^

clean:
	$(RM) $(BIN)/*.o
	$(RM) $(BIN)/__*

clobber:
	$(RM) -f $(BIN)/*

ver:
	@echo $(VERSION)

var:
	@echo D_DIR:$(D_DIR)
	@echo SRC:$(SRC)
	@echo DCFLAGS_IMPORT: $(DCFLAGS_IMPORT)
	@echo LIB: $(LIB)
	@echo
	@echo DCFLAGS: $(DCFLAGS)
	@echo DCFLAGS_LINK: $(DCFLAGS_LINK)
	@echo VERSION: $(VERSION_FLAG)
	@echo
	@echo NAME_TEST: $(NAME_TEST)
	@echo SRC_TEST: $(SRC_TEST)
	@echo DCFLAGS_IMPORT_TEST: $(DCFLAGS_IMPORT_TEST)
	@echo LIB_TEST: $(LIB_TEST)
	@echo
	@echo T: $(T)


# Help Target
help:
	@echo "The following are some of the valid targets for this Makefile:"
	@echo "... all (the default if no target is provided)"
	@echo "... test"
	@echo "... testv Runs unitt_threded test in verbose (-debug) mode"
	@echo "... run"
	@echo "... clean"
	@echo "... clobber"
	@echo "... pkg"
	@echo "... pkgsrc"
	@echo "... tags Generates tag file"
	@echo "... style Che"
	@echo "... syn"
	@echo "... loc Counts lines of code"
	@echo "... var Lists all variables"
