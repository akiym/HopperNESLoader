# HopperNESLoader

This is Hopper file loader plugin for NES (Nintendo Entertainment System/Family Computer).

Most of code which make up this plugin are taken from [agatti/hopper-plugins](https://github.com/agatti/hopper-plugins).

## Installation

### 1) Install 6502 CPU plugin from [agatti/hopper-plugins](https://github.com/agatti/hopper-plugins)

```
% xcodebuild -workspace HopperPlugins.xcworkspace -scheme 6502 -configuration Release build
```

Open `6502.hopperCPU` plugin you build.

### 2) Open `NESLoader.hopperLoader` plugin

### 3) Restart `Hopper.app`

Enjoy happy reversing.

Sometimes NES crackme is one of the reversing challenge in CTF. One more good challenge?

- [Hacking Time - CSAW CTF 2015](https://github.com/ctfs/write-ups-2015/tree/master/csaw-ctf-2015/reverse/hacking-time-200)
- [retro crackme - akictf](http://ctf.katsudon.org/)
- [Good Old Days - tkbctf1 (writeup)](http://akiym.hateblo.jp/entry/2013/05/06/013509)

## TODO

- [x] Trainer support
- [ ] Mappers
