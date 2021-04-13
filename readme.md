# SVD to Zig

This converts [System View Description](https://www.keil.com/pack/doc/CMSIS/SVD/html/index.html) (SVD) files into Zig, providing a nice API against memory-mapped peripheral registers on embedded systems.
It solves the same problem as [svd2rust](https://github.com/rust-embedded/svd2rust).

The generated Zig code has only been lightly tested on nRF52 hardware as part of my [keyboard firmware](https://kevinlynagh.com/rust-zig/).
It's checked in under [target/](target/) so you can just download and run it if you want to get right to playing with nRF52 chips using Zig.

This project was a collaboration with Jamie Brandon, see [his writeup](https://scattered-thoughts.net/writing/mmio-in-zig) on this project.

## Usage example

The register API is defined by [registers.zig](registers.zig), which is inlined at the top of the generated Zig files.

```zig
usingnamespace @import("register-generation/target/nrf52840.zig");

pub const led = .{ .port = p0, .pin = 11 };

fn main() void {

    //calling modify will preserve other fields of register
    led.port.pin_cnf[led.pin].modify(.{
        .dir = .output,
        .input = .disconnect,
    });
    
    //calling write will set unspecified fields to their reset value
    led.port.pin_cnf[led.pin].write(.{
        .dir = .input,
    });
    
}
```


## Generating Zig definitions from SVD

The API and generation script assumes 32-bit word size and likely contains bugs and conceptual misunderstandings.
Read the [300 lines of source](generate_registers.clj) and decide for yourself.
It's written in Clojure because...hahaha I'm not going to try parsing XML in Zig =P

Run `./build.sh` to download SVD files to `vendor/` and generate formatted Zig definitions for every SVD found in that directory.
You'll need `clojure` and `zig` on your path.
