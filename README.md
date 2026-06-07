# TempleOS Atari 2600 Emulator

A compact HolyC Atari 2600 emulator for TempleOS. It loads `CART.BIN` first,
then `SPECT1.BIN`, from a mounted transfer disk and falls back to an embedded
proof ROM when no cart is present.

The emulator is a HolyC port of a z26-style Atari 2600 architecture. It includes
6507 CPU execution, RIOT RAM/timer and controller paths, TIA display/audio
behavior, and a broad set of cartridge mappers including flat 2K/4K, F8/F6/F4,
SC/SARA, E0, 0840, 0FA0, 03E0, 3F/3E, E7, FA, FE, DPC/Pitfall II,
Supercharger, FA2, EF/DF/BF families, MDM, WD/WDSW, WF8, and others.
The Supercharger path includes the generic `$1FF9` tape/audio input surface
mapped to the right-difficulty switch and tracks 8448-byte load header/page
checksum validity; full cassette audio file sampling is not implemented.
The TIA audio core creates mixed samples into an internal ring buffer, while
TempleOS playback still uses a coarse one-tone `Snd()` PC-speaker fallback.

## Files

- `A2600.HC` - the launchable TempleOS/HolyC emulator.
- `run-templeos.sh` - starts a local TempleOS QEMU VM.
- `stop-templeos.sh` - stops the local TempleOS QEMU VM.
- `stage-transfer-disk.sh` - copies `A2600.HC` and an optional ROM to a mounted
  macOS transfer disk image.
- `qemu-type.py` - sends text and control keys through the QEMU monitor socket.

TempleOS disk images, Atari ROMs, generated test carts, screenshots, and save
files are intentionally not included.

## Quick Start

Requirements:

- macOS with `hdiutil`
- QEMU with `qemu-system-x86_64`
- a TempleOS hard disk image named `templeos-hdd.qcow2`
- a writable raw/FAT transfer disk image, for example `templeos-transfer.dmg`
- an Atari 2600 ROM you are legally allowed to use

Stage the emulator and a cart:

```sh
./stage-transfer-disk.sh templeos-transfer.dmg /path/to/game.bin
```

Boot TempleOS with the transfer disk:

```sh
TRANSFER_IMAGE=templeos-transfer.dmg ./run-templeos.sh
```

Connect VNC to:

```text
127.0.0.1::5902
```

In TempleOS, mount the transfer disk and run the emulator:

```c
ExeFile("C:/Kernel/KernelC.HH");
ExeFile("C:/Compiler/CompilerB.HH");
ATAMount(0x47,2,0x1F0,0x3F4,1);
Cd("G:/");;
ExeFile("A2600.HC");
```

The command above mounts the second IDE disk as `G:`. If you use
`MountIDEAuto` instead, TempleOS may choose a different drive letter; replace
`G:` with the mounted drive shown by TempleOS.

## Controls

- Player 0 movement: arrow keys
- Player 0 fire/jump: `F`, `Space`, or `Enter`
- Player 1 movement: `I`, `J`, `K`, `L`
- Player 1 fire: `M`
- Reset/start: `R` or `F1`
- Select: `U` or `F2`
- Color/BW and difficulty switches: `F3` through `F8`
- Quit: `Esc`

The runner also includes the left/right/both-port CX22 Trak-Ball, ST mouse, and
Amiga mouse quadrature pin path used by the accuracy-suite controller proofs.
That path is currently exposed through HolyC helper calls such as
`A2600TrakBallMode`, `A2600TrakBallPort`, and `A2600TrakBallQueue`; the default
live keyboard route remains joystick/paddle/driving focused.

For scripted QEMU input, `qemu-type.py` supports named tokens such as
`{right@2000}`, `{p0fire}`, `{space}`, `{enter}`, and Pitfall II helpers like
`{pitfallrightjump}`.

## License

This repository is GPLv2 because `A2600.HC` is derived from z26 4.07, Copyright
1997-2019 John Saeger and contributors. See `LICENSE`.
