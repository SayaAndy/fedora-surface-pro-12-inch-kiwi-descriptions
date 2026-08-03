
# Fedora KIWI image descriptions, modified to build & launch for Surface Pro 12" Gen 1

It is the fork of the original [KIWI image descriptions](https://forge.fedoraproject.org/releng/kiwi-descriptions), modified for launching Fedora Linux Rawhide Live ISO on Surface Pro 12" Gen 1 (and further installing it on the device).

I bought this device as I viewed it as a great Linux GNOME tablet, but after several days, many hours of work of trying to do so, I must say that installing a distribution here (and then having it work fine) is a huge pain in the ass.

> Special thanks to [harrisonvanderbyl](https://github.com/harrisonvanderbyl), this project wouldn't be possible without his huge contribution to this whole Linux on Surface ARM business!

## How to run

**The compiled ISOs can be downloaded [here](https://dist.sayag.it/surface-pro-12in-ports/fedora/rawhide).**

This KIWI project is built mainly on the base of Fedora Workstation Rawhide LiveCD ISO. Trying a stable version (the latest is Fedora 44 at the time of writing this) is possible, but not tested for now.

If you want to compile this image manually, **the build arch must be `aarch64`**. It means that if you are on an `amd64` machine, you would have to use aarch64 instructions emulation tools like `binfmt`. Unfortunately, such a tool will drastically increase the compilation time.

To build this on Fedora Linux:

```bash
# Install kiwi
[]$ sudo dnf --assumeyes install kiwi kiwi-systemdeps distribution-gpg-keys
# Run the image build
[]$ sudo ./kiwi-build --kiwi-file=Fedora.kiwi --image-type=<image_type> --image-profile=<image_profile> --output-dir ./outdir
# An example for Workstation Live CD ISO
[]$ sudo ./kiwi-build --kiwi-file=Fedora.kiwi --image-type=iso --image-profile=Workstation-Live --output-dir ./outdir
```

## What is left out (for now)

* Live CD has to run in RAM, so `rd.live.ram=1` is set for cmdline. Otherwise, at least on my ancient flash drive, it fails to load multiple necessary services, including `polkit`.
* No rescue vmlinuz.
* No secure boot possible for this ISO for now, as the platform used is `efi` and not `uefi`.
* No GRUB auto hidden menu. Trying to have the menu hidden results in system simply crashing after trying to boot it.
* `wireupcameras.service` fails on installed system (not in Live CD though).

## Image variants

Please look at [`VARIANTS`](VARIANTS.md) for details on the available configurations that can be built.

## CI information

This project is yet to adapt CI, but it is coming.

For now the images are being built and tested manually on my personal Surface Pro 12" Gen 1 (16 GB RAM, 512 GB storage).

## Licensing

This is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, under version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
