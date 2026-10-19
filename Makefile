SALAM ?= salam
BIN   ?= todolist

.PHONY: run build fmt check clean

run:
	$(SALAM) run

build:
	$(SALAM) build --output=$(BIN)

fmt:
	$(SALAM) format -r .

check:
	$(SALAM) format -r . --check

clean:
	rm -rf .salam-build $(BIN)
