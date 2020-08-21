#!/usr/bin/env make

#------------------------------------------------------------------------------
# Make configuration
#------------------------------------------------------------------------------
SHELL := /bin/bash -o errexit -o errtrace -o functrace -o pipefail -o nounset
DBG_MAKEFILE ?=
ifeq ($(DBG_MAKEFILE),1)
    $(warning ***** starting Makefile for goal(s) "$(MAKECMDGOALS)")
    $(warning ***** $(shell date))
else
    MAKEFLAGS += -s
endif

.DEFAULT_GOAL := help
default: help
## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ {                                                                                      \
	  helpMessage = match(lastLine, /^## (.*)/);                                                                      \
	  if (helpMessage) {                                                                                              \
	    helpCommand = substr($$1, 0, index($$1, ":")-1);                                                              \
	    helpMessage = substr(lastLine, RSTART + 3, RLENGTH);                                                          \
	    printf "  ${YELLOW}%-30s${RESET}${GREEN}%s${RESET}\n", helpCommand, helpMessage;                              \
	  }                                                                                                               \
	}                                                                                                                 \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)


#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------
WORKDIR ?= $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST)))) 
UTXO_DIR ?= ~/.bitcoind/chainstate
MIN_SATOSHIS ?= 999999

FILE_PREFIX ?= utxodump
FILE_DUMP ?= ${FILE_PREFIX}.csv
FILE_FILTERED ?= ${FILE_PREFIX}.gt1M.csv
FILE_SORTED ?= ${FILE_PREFIX}.gt1M.sorted.csv
FILE_UNIQ ?= ${FILE_PREFIX}.gt1M.sorted.uniq.csv
FILE_VERSION_1 ?= ${FILE_PREFIX}.gt1M.sorted.uniq.P2PKH.txt
FILE_VERSION_3 ?= ${FILE_PREFIX}.gt1M.sorted.uniq.P2SH.txt
FILE_VERSION_BC1 ?= ${FILE_PREFIX}.gt1M.sorted.uniq.Bech32.txt
FILE_VERSION_OTHER ?= ${FILE_PREFIX}.gt1M.sorted.uniq.other.txt
FILES_VERSIONS ?= ${FILE_VERSION_1} ${FILE_VERSION_3} ${FILE_VERSION_BC1} ${FILE_VERSION_OTHER}

#------------------------------------------------------------------------------
# Binaries
#------------------------------------------------------------------------------
GO ?= go
BITCOIN_UTXO_DUMP ?= bitcoin-utxo-dump
PV ?= pv
VANITYSEARCH ?= VanitySearch

CMD_EXISTS := $(shell $(PV) -V 2>/dev/null)
ifndef CMD_EXISTS
    $(warning "No pv found in PATH, commands will have no progress shown")
    PV := cat
endif


#------------------------------------------------------------------------------
# Targets
#------------------------------------------------------------------------------
.PHONY: dump_utxo
## Extract unspent transactions balances into a csv
dump_utxo: $(FILE_DUMP)
$(FILE_DUMP):
	# check dependencies
	if ! $(BITCOIN_UTXO_DUMP) -version >/dev/null 2>&1; then                                                          \
	    if $(GO) version >/dev/null 2>&1; then                                                                        \
	        echo "Installing bitcoin-utxo-dump ...";                                                                  \
	        $(GO) get -v github.com/in3rsha/bitcoin-utxo-dump;                                                        \
	    fi;                                                                                                           \
	    if ! $(BITCOIN_UTXO_DUMP) -version >/dev/null 2>&1; then                                                      \
	        >&2 echo "No bitcoin-utxo-dump found in PATH, nor goland binary to build it";                             \
	        >&2 echo "Either install golang or bitcoin-utxo-dump";                                                    \
	        >&2 echo "You can point to the correct command using environment variable GO or BITCOIN_UTXO_DUMP";       \
	        exit 1;                                                                                                   \
	    fi;                                                                                                           \
	fi
	# ensure bitcoind is stopped
	if pidof bitcoind >/dev/null 2>&1; then                                                                           \
	    >&2 echo "bitcoind is running, stop it before we can extract unspent transactions";                           \
	    exit 1;                                                                                                       \
	fi
	# check chainstate exists
	if [ ! -d "$(UTXO_DIR)" ]; then                                                                                   \
	    >&2 echo "Chainstate folder '$(UTXO_DIR)' does not exists";                                                   \
	    >&2 echo "Please provide the correct path using environment variable UTXO_DIR";                               \
	    exit 1;                                                                                                       \
	fi
	# extract balances
	echo "Extracting chainstate balance into '$(FILE_DUMP)' (about 30mins)"
	$(BITCOIN_UTXO_DUMP) -db "$(UTXO_DIR)" -f "amount,address" -o /dev/stderr 3>&1 1>&2 2>&3 3>&-                     \
	  | tail -n+2                                                                                                     \
	> $(FILE_DUMP)


.PHONY: filter_utxo_balance
## Filter unspent transactions balances with a minimum of Satochis in their balance
filter_utxo_balance: $(FILE_FILTERED)
$(FILE_FILTERED): dump_utxo
	pv $(FILE_DUMP)                                                                                                   \
	  | awk -F, '{ if ( $$1 > $(MIN_SATOSHIS) ) { if ( length($$2) > 0) print $$1 "," $$2; }}'                        \
	> $(FILE_FILTERED)


.PHONY: sort_utxo_balances
## Sort unspent transactions balances from richest to poorest
sort_utxo_balances: $(FILE_SORTED)
$(FILE_SORTED): filter_utxo_balance
	pv $(FILE_FILTERED)                                                                                               \
	  | LC_ALL=C sort -nr                                                                                             \
	> $(FILE_SORTED)


.PHONY: remove_utxo_duplicates
## Remove duplicates in unspent transactions balances (require input file to be sorted)
remove_utxo_duplicates: $(FILE_UNIQ)
$(FILE_UNIQ): sort_utxo_balances
	pv $(FILE_SORTED)                                                                                                 \
	  | uniq                                                                                                          \
	> $(FILE_UNIQ)


.PHONY: split_utxo_versions
## Split the transaction into list of addresses files, grouped by address versions
split_utxo_versions: $(FILES_VERSIONS)
$(FILES_VERSIONS): remove_utxo_duplicates
	pv $(FILE_UNIQ)                                                                                                   \
	  | awk -F, '{                                                                                                    \
	      switch ($$2) {                                                                                              \
	        case /^1/:   print $$2 > "$(FILE_VERSION_1)";     break;                                                  \
	        case /^3/:   print $$2 > "$(FILE_VERSION_3)";     break;                                                  \
	        case /^bc1/: print $$2 > "$(FILE_VERSION_BC1)";   break;                                                  \
	        default:     print $$2 > "$(FILE_VERSION_OTHER)"; break;                                                  \
	      }                                                                                                           \
	    }'


.PHONY: run
## Launch the brute force cracking for a list of addresses
run:
	# check dependencies
	if ! $(VANITYSEARCH) -v >/dev/null 2>&1; then \
	    >&2 echo "No VanitySearch found in PATH, please install it";                                                  \
	    >&2 echo "or point to the correct command using environment variable VANITYSEARCH";                           \
	    exit 1;                                                                                                       \
	fi
	if [ ! -f "$(FILE_VERSION_1)" ]; then                                                                             \
	    $(make) "$(FILE_VERSION_1)";                                                                                  \
	fi
	$(VANITYSEARCH) -gpu -i $(FILE_VERSION_1)
