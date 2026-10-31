chann
=====

Multi-producer, multi-consumer channels for Rust, with a `chan_select!`
macro that can wait on any mix of send and receive operations. The crate
inside this repository is named `chan`.

The semantics follow Go's channels: rendezvous, buffered and unbounded
channels, a `select` with an optional `default` arm, timers (`after`,
`tick`) and a `WaitGroup`. Every "goroutine" is an OS thread, and the crate
contains no `unsafe` code.


### Status

This is a copy of Andrew Gallant's
[`chan`](https://github.com/BurntSushi/chan) crate at version 0.1.23.
Upstream has declared it end of life and recommends
[`crossbeam-channel`](https://github.com/crossbeam-rs/crossbeam), which has a
very similar API, a better `select!`, and better performance. Use this crate
for learning or for code that already depends on it, not for new projects.

The code builds and its tests pass on current stable Rust without warnings.
The crate stays on the 2015 edition because one of its public functions is
called `async`, which became a keyword in the 2018 edition.


### Requirements

* Rust stable and Cargo (checked with Rust 1.99).
* The only runtime dependency is `rand` 0.3, used to shuffle the arms of
  `chan_select!`.
* The benchmarks need a nightly compiler (they use `#![feature(test)]`).


### Install

The crate is not published from this repository, so depend on it through git:

```toml
[dependencies]
chan = { git = "https://github.com/alex-quiterio/chann" }
```

To build it locally:

```sh
git clone https://github.com/alex-quiterio/chann
cd chann
cargo build
```


### Usage

Create a channel with one of three constructors. Each returns a
`(Sender<T>, Receiver<T>)` pair, and both halves can be cloned freely and
moved to other threads.

| Constructor     | Kind                | `send` blocks                  |
|-----------------|---------------------|--------------------------------|
| `chan::sync(0)` | rendezvous          | until a `recv` takes the value |
| `chan::sync(n)` | buffered, `n` slots | while the buffer is full       |
| `chan::async()` | unbounded           | never                          |

A channel closes when its last `Sender` is dropped. After that, `recv`
drains whatever is still buffered and then returns `None` at once. There is
no explicit `close`.

Selecting on a ticker, a timeout and a non-blocking `default` arm, in a crate
using the 2018 or 2021 edition:

```rust
use std::thread;
use std::time::Duration;

use chan::chan_select;

fn main() {
    let tick = chan::tick(Duration::from_millis(100));
    let boom = chan::after(Duration::from_millis(500));
    loop {
        chan_select! {
            default => thread::sleep(Duration::from_millis(50)),
            tick.recv() => println!("tick."),
            boom.recv() => { println!("BOOM!"); return; },
        }
    }
}
```

In a 2015-edition crate, use `#[macro_use] extern crate chan;` instead of the
`use` line. In 2018 and later, the unbounded constructor has to be written
`chan::r#async()`.

`chan_select!` has a few strict rules. Breaking them gives an unhelpful
"recursion limit reached" error:

* every arm ends with a comma, braces or not;
* `default`, if present, must be the first arm;
* each operation must be `ident.recv()` or `ident.send(expr)`, so bind
  channels to a name first;
* `recv()` arms can bind the result with `-> name`, which is an `Option<T>`.

Other behaviour worth knowing:

* Dropping every `Receiver` does not close a channel. A send that has to wait
  for a receiver (a full buffer, or any rendezvous send) then blocks forever.
* `tick` and `tick_ms` start a thread that is never reclaimed.
* There is no public `try_send` or `try_recv`. Use `chan_select!` with a
  `default` arm instead.
* `chan_select!` cannot rendezvous with another `chan_select!` on the same
  unbuffered channel. One side must be a plain blocking `send` or `recv`.

The crate documentation (`cargo doc --open`) covers all of this in more
depth, with examples for each pattern.

More runnable examples are in `examples/`:

```sh
cargo run --example default        # the select loop above
cargo run --example fibonacci      # select on a send and a receive
cargo run --example leaky_buffer   # Go's "leaky buffer" free list
cargo run --example nested_select  # nested selects to prioritise a channel
```


### Project layout

```
src/lib.rs          channel types, constructors, timers, chan_select!, unit tests
src/select.rs       Select, the type-erased engine behind chan_select!
src/notifier.rs     lets a blocked select subscribe to channel activity
src/tracker.rs      counts senders and receivers so the last sender closes
src/wait_group.rs   WaitGroup
examples/           runnable examples
benches/            throughput benchmarks against std::sync::mpsc (nightly)
BENCHMARKS.md       one recorded benchmark run from upstream
```


### Tests

```sh
cargo test
```

This runs the unit tests in `src/lib.rs` and the documentation examples.
Some tests use real sleeps, so the suite takes a few seconds.

Benchmarks need nightly:

```sh
cargo +nightly bench
```


### License

Dual-licensed under MIT or the [Unlicense](https://unlicense.org). See
`COPYING`, `LICENSE-MIT` and `UNLICENSE`.
