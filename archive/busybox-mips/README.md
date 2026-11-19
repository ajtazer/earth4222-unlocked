# Archived: official BusyBox MIPS builds (don't work on this router)

The router's BusyBox 1.22.1 has no `httpd` and its `nc` can't do UDP, so the first plan was to copy a full static BusyBox over.
Both official builds from busybox.net fail on the RTL9607C (MIPS32r2 big-endian, no FPU):

| File | Source | Result |
|---|---|---|
| `busybox-1.21.1-mips` | https://busybox.net/downloads/binaries/1.21.1/busybox-mips | `Illegal instruction` on start |
| `busybox-1.31.0-musl-mips` | https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-mips | runs `true`/`echo`, every real applet (`sed`, `date`, `nc`, `httpd`) exits 132 (SIGILL) |

BusyBox is GPL-2.0; source: https://busybox.net/downloads/. The fix that worked was the router's own GNU netcat 0.7.1 (see the main README).
`SHA256SUMS` has the checksums.
