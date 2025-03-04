# ♨️ therm

Console interface with Unicode support for Windows and Linux

## Installation

Use dub: `dub add therm`.

## Usage

Create an interface, then call `readln` to read a line from stdin, or
`write(f)(ln)` to write to stdout:

```d
import therm;

Therm t = Therm.create();

string line = t.readln(prompt: "> ");
t.writefln!"you wrote: %s"(line);
```

`Therm` is a struct with a destructor that restores console state. While `Therm`
is alive, you probably shouldn’t write stuff without going through it, but it
may work. Additionally, Therm processes write/read for Windows so it can handle
Unicode I/O properly.

## Licence

[MIT](LICENSE.txt)
