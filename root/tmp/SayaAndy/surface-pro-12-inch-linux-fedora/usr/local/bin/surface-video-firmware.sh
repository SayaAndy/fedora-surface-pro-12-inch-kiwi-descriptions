#!/bin/bash
# Surface Pro 12" (Snapdragon X1P-42-100): install the video codec firmware.
#
# The iris video codec needs firmware TrustZone will accept. linux-firmware's
# qcom/vpu/vpu30_p1_s7.mbn is the same codec signed with Qualcomm's SecTools
# *test* key chain, which a retail Surface rejects:
#
#   qcom-iris aa00000.video-codec: error -22 initializing firmware qcom/vpu/vpu30_p1_s7.mbn
#
# The production-signed build ships only inside Microsoft's Surface driver
# package, which grants no redistribution right, so the image cannot carry it.
# What it can do is copy it out of a Windows install the owner already has a
# licence for, or out of a driver pack they downloaded themselves. This script
# does the copying; it never fetches anything the caller did not ask for.
#
# Usage: surface-video-firmware.sh [-m MSI] [-u URL] [-n]
#
#   (no options)  look for a Windows partition on this machine and copy the
#                 firmware out of its DriverStore. No network access.
#   -m MSI        extract from a Surface driver pack already on disk
#   -u URL        download a driver pack and extract from that
#   -n            say what would happen, change nothing
#
# The driver pack is a ~500 MB MSI from
#
#   https://www.microsoft.com/en-us/download/details.aspx?id=108199
#
# There is no stable direct link to hardcode: the Download Center hands out
# per-session URLs and the file name carries the driver release, so -u takes
# the URL the browser was given rather than guessing one that would rot.

set -euo pipefail

FW_DIR=/lib/firmware/qcom/x1p42100/Microsoft/Surface12
BLOB=qcvss8380_pa.mbn
DRIVERSTORE=Windows/System32/DriverStore/FileRepository
PAGE=https://www.microsoft.com/en-us/download/details.aspx?id=108199

msi=""
url=""
dry_run=false

while getopts ':m:u:nh' opt; do
	case "${opt}" in
		m) msi=${OPTARG} ;;
		u) url=${OPTARG} ;;
		n) dry_run=true ;;
		h) sed -n '2,31p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) echo "unknown option -${OPTARG}" >&2; exit 2 ;;
	esac
done

log() { printf 'surface-video-firmware: %s\n' "$*"; }
die() { printf 'surface-video-firmware: %s\n' "$*" >&2; exit 1; }

if [[ -f "${FW_DIR}/${BLOB}" ]]; then
	log "${FW_DIR}/${BLOB} is already installed"
	exit 0
fi

[[ ${EUID} -eq 0 ]] || die "must run as root"

cleanup_dirs=()
cleanup_mounts=()
cleanup() {
	local m d
	for m in ${cleanup_mounts[@]+"${cleanup_mounts[@]}"}; do
		mountpoint -q "${m}" && umount "${m}" || true
	done
	for d in ${cleanup_dirs[@]+"${cleanup_dirs[@]}"}; do
		rm -rf "${d}" || true
	done
}
trap cleanup EXIT

install_blob() {
	local src=$1
	if [[ ${dry_run} == true ]]; then
		log "would install ${src} as ${FW_DIR}/${BLOB}"
		return 0
	fi

	install -Dm644 "${src}" "${FW_DIR}/${BLOB}"
	log "installed ${FW_DIR}/${BLOB}"

	# The driver only asks for its firmware while probing, so it has to be
	# reloaded to pick this up. It refuses while a decode session holds it,
	# which is why a failure here is only worth a note.
	if lsmod | grep -q '^qcom_iris'; then
		if modprobe -r qcom_iris 2>/dev/null && modprobe qcom_iris 2>/dev/null; then
			log "reloaded qcom_iris"
		else
			log "could not reload qcom_iris; reboot to start using the firmware"
		fi
	fi
}

# Everything below hands find(1) the bare file name rather than a full path:
# the DriverStore directory carries a per-build hash, and the layout inside an
# extracted MSI is not documented anywhere worth trusting.
find_blob() {
	find "$1" -type f -name "${BLOB}" -print -quit 2>/dev/null
}

from_windows() {
	local dev fstype part_mnt mnt found

	while read -r dev fstype part_mnt; do
		[[ ${fstype} == ntfs* ]] || continue

		if [[ -n ${part_mnt} ]]; then
			mnt=${part_mnt}
		else
			mnt=$(mktemp -d)
			cleanup_dirs+=("${mnt}")
			if ! mount -t ntfs3 -o ro,noatime "/dev/${dev}" "${mnt}" 2>/dev/null &&
			   ! mount -o ro,noatime "/dev/${dev}" "${mnt}" 2>/dev/null; then
				log "/dev/${dev}: could not mount read-only, skipping"
				log "/dev/${dev}: if Windows is hibernated, shut it down fully and retry"
				continue
			fi
			cleanup_mounts+=("${mnt}")
		fi

		[[ -d "${mnt}/${DRIVERSTORE}" ]] || continue

		found=$(find_blob "${mnt}/${DRIVERSTORE}")
		if [[ -n ${found} ]]; then
			log "found ${BLOB} on /dev/${dev}"
			install_blob "${found}"
			return 0
		fi
		log "/dev/${dev}: a Windows install, but no ${BLOB} in its DriverStore"
	done < <(lsblk -rno NAME,FSTYPE,MOUNTPOINT)

	return 1
}

from_msi() {
	local pack=$1 work found

	command -v msiextract >/dev/null || die "msiextract is missing; install msitools"

	work=$(mktemp -d)
	cleanup_dirs+=("${work}")

	log "extracting ${pack}"
	( cd "${work}" && msiextract "${pack}" >/dev/null )

	found=$(find_blob "${work}")
	[[ -n ${found} ]] || die "no ${BLOB} inside ${pack}; is it the Surface Pro 12in driver pack?"

	log "found ${BLOB} in the driver pack"
	install_blob "${found}"
}

if [[ -n ${url} ]]; then
	dl=$(mktemp -d)
	cleanup_dirs+=("${dl}")
	msi="${dl}/driverpack.msi"
	log "downloading ${url}"
	curl -fL --retry 3 --progress-bar -o "${msi}" "${url}"
fi

if [[ -n ${msi} ]]; then
	[[ -f ${msi} ]] || die "${msi} does not exist"
	from_msi "${msi}"
	exit 0
fi

if from_windows; then
	exit 0
fi

# Nothing found, and nothing was asked for. Not an error: most of the time this
# is a machine with no Windows left on it, and the only thing left to do is say
# how to finish the job by hand.
log "no Windows install on this machine carries ${BLOB}"
log "hardware video decode stays off until it is installed. To finish by hand:"
log "  1. download the Surface Pro 12in driver pack (~500 MB) from"
log "     ${PAGE}"
log "  2. sudo surface-video-firmware.sh -m /path/to/SurfacePro_12in_*.msi"
exit 0
