# `zshim`

zshim is the [`shim`](https://github.com/71/scoop-better-shimexe/) written in Zig.

## Building

Requirements:
- [Zig](https://ziglang.org/)
- git

Once you have those, then it's as easy as:

``` shell
git clone https://github.com/bradms/zshim.git
cd zshim
zig build -Drelease-safe
```

## Limitations

Does not handle elevation of any kind. (PRs welcomed)


## Similar works

- https://github.com/71/scoop-better-shimexe
- https://github.com/zoritle/rshim

## License

This work is dual-licensed under MIT and The Unlicense.

You can choose between one of them if you use this work.

`SPDX-License-Identifier: MIT OR Unlicense`
