# EARTH-4222 firmware and settings dump

Read-only dump of the router this project runs on: EARTH-4222 EPON ONT, Realtek RTL9607C (Luna SDK V4.0.0),
MIPS32r2 big-endian, Linux 4.4.140, BusyBox 1.22.1, firmware built 2023-02-10. Taken over SSH with `cat /dev/mtdN`
(no `dd` on the box). Nothing was written to the router.

## Flash layout (`/proc/mtd`)
| mtd | name | size | in this repo |
|---|---|---|---|
| 0 | boot | 768 KB | **no**: the vendor kernel refuses reads of the bootloader |
| 1 | env | 128 KB | `flash/mtd1-env.bin` (U-Boot environment) |
| 2 | env2 | 128 KB | `flash/mtd2-env2.bin` (U-Boot environment, copy) |
| 3 | static_conf | 128 KB | `flash/mtd3-static_conf.bin` |
| 4 | ubi_device | 124 MB | **no**: the whole UBI device, it contains the settings volume below |
| 5 | ubi_Config | 10.5 MB | **no** (raw): holds the live settings with credentials; included only as masked XML in `config/` |
| 6 | ubi_k0 | 3.4 MB | `flash/mtd6-ubi_k0.bin` (kernel, slot 0) |
| 7 | ubi_r0 | 9.4 MB | `flash/mtd7-ubi_r0.bin` (root filesystem, slot 0, squashfs) |
| 8 | ubi_k1 | 10 MB | `flash/mtd8-ubi_k1.bin` (kernel, slot 1) |
| 9 | ubi_r1 | 25 MB | `flash/mtd9-ubi_r1.bin` (root filesystem, slot 1) |

The bootloader picks slot 0 or 1 (`sw_active` / `sw_commit` in env). Inspect images with `binwalk` or `ubi_reader`.
The env holds only boot scripts and Realtek's placeholder MAC `00:E0:4C:86:70:01`.

## Settings (`config/`)
- `config.xml`, `config_bk.xml`: live settings and the router's own backup copy (an older state).
- `config_hs.xml`, `config_hs_bk.xml`: hardware/static settings and backup.
- `config_default.xml`, `config_factory.xml`, `config_default_hs.xml`: the vendor defaults from `/etc` in the firmware.

**Masked** (value replaced with `MASKED`) in every file: ISP login (`pppUser`, `pppPasswd`), every Wi-Fi key
(WPA, WPS, WEP fields), every Wi-Fi name (`SSID`/`ssid` and variants), every admin/user web and console login,
and any real value in the ISP-management (TR-069/CWMP), fibre-registration (LOID/PLOAM), FTP and proxy credential
fields. Factory placeholders were left as they are (`user`, `username`, `password`, `client`, `1234567890`, `http://`).
Note for owners of the same box: on this unit the web admin password (`WEB_SUSER_PASSWORD`) was the router's own
MAC address in capitals, and ISP remote management (TR-069) was not configured.

## Binaries (`bin/`)
- `boa`: the vendor's web server (admin UI compiled in), copied from `/bin/boa` for analysis. Also inside the rootfs images.

Firmware and binaries are the vendor's / ISP's work, published for research and interoperability.
`SHA256SUMS` lists checksums of everything here.
