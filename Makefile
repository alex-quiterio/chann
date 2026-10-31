all: test

test:
	cargo test

ctags:
	ctags --recurse --options=ctags.rust --languages=Rust

docs:
	cargo doc

.PHONY: all test ctags docs
