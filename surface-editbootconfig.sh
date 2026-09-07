#!/bin/bash
# Surface Pro 12" (Snapdragon X1P-42-100): put the device tree on the ISO.
#
# kiwi has no device tree support of its own, and the ISO's GRUB needs the dtb
# as a plain file it can read: it loads it with a "devicetree" line before the
# kernel (see grub-arm.cfg.iso-template), it cannot read the erofs root image,
# and kiwi copies only the kernel and the initrd into the ISO's loader
# directory.
#
# editbootconfig is the one hook that reaches the ISO tree. kiwi's live builder
# calls it with "iso:<media dir>" as the first argument and the image root as
# the working directory, after setup_media_loader_directory has created the
# loader directory and the GRUB config has been written. So the dtb can be
# taken straight out of the kernel-surface RPM installed in the image root,
# which is why config-cdroot.tar is no longer needed to carry a committed copy.

set -euo pipefail

target="${1:-}"
case "${target}" in
	iso:*) media_dir="${target#iso:}" ;;
	*)
		echo "surface-editbootconfig: expected an iso: target, got '${target}'" >&2
		exit 1
		;;
esac

dtb_name=x1p42100-microsoft-sp12in.dtb

# The working directory is the image root, so this is kernel-surface's own copy,
# under a directory named for the kernel version because that package is
# installonly. config.sh has already failed the build if it is not there.
dtb_src=$(ls -1 usr/lib/surface-dtb/*/"${dtb_name}" 2>/dev/null | sort -V | tail -n1)
if [[ -z "${dtb_src}" ]]; then
	echo "surface-editbootconfig: no ${dtb_name} under usr/lib/surface-dtb/ in the image root" >&2
	exit 1
fi

# ${bootpath} in the GRUB template is /boot/<kiwi platform name>/loader. Read
# the directory back off the media tree rather than recomputing that name, so
# the dtb cannot end up somewhere the GRUB config does not look.
loader_dirs=("${media_dir}"/boot/*/loader)
if [[ ${#loader_dirs[@]} -ne 1 || ! -d "${loader_dirs[0]}" ]]; then
	echo "surface-editbootconfig: expected one ${media_dir}/boot/*/loader, found ${#loader_dirs[@]}" >&2
	exit 1
fi

install -Dm644 "${dtb_src}" "${loader_dirs[0]}/${dtb_name}"
echo "surface-editbootconfig: staged ${loader_dirs[0]}/${dtb_name}"
