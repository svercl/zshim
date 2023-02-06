# `zshim`

zshim is the [`shim`](https://github.com/71/scoop-better-shimexe/) written in
Zig.

## Building

Requirements:

- [Zig 0.11.0-dev.1568+c9b957c93](https://ziglang.org/)
- git

Once you have those, then it's as easy as:

```shell
git clone https://github.com/svercl/zshim.git
cd zshim
zig build -Doptimize=ReleaseSafe
```

## Installation

The easiest way to install this is to replace the `shim.exe` in your scoop
install folder. If you use vanilla, this will be
`$SCOOP/support/shimexe/bin/shim.exe` and running the command `scoop reset *`
will replace all shims with this one.

## Limitations

Does not handle elevation of any kind. (PRs welcomed)

## Similar works

- https://github.com/71/scoop-better-shimexe
- https://github.com/zoritle/rshim

## License

This work is dual-licensed under MIT and The Unlicense.

You can choose between one of them if you use this work.

`SPDX-License-Identifier: MIT OR Unlicense`
