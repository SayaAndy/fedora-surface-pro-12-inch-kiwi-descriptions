#!/bin/bash
set -e

# Wait for /dev/media0 to appear (MSM VFE driver may need firmware to probe)
# Timeout after 10 seconds to avoid infinite hangs on systems without camera hardware
MAX_WAIT=10
WAIT_COUNT=0
while [ ! -e /dev/media0 ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ ! -e /dev/media0 ]; then
    echo "wireupcameras: /dev/media0 not found after ${MAX_WAIT}s, skipping" >&2
    exit 0
fi

SENSOR="ov13858 1-0010"

# Tell each pad in the path what format to expect
media-ctl -V "\"$SENSOR\":0[fmt:SGRBG10_1X10/4224x3136]"
media-ctl -V '"msm_csiphy0":0[fmt:SGRBG10_1X10/4224x3136]'
media-ctl -V '"msm_csiphy0":1[fmt:SGRBG10_1X10/4224x3136]'
media-ctl -V '"msm_csid0":0[fmt:SGRBG10_1X10/4224x3136]'
media-ctl -V '"msm_csid0":1[fmt:SGRBG10_1X10/4224x3136]'
media-ctl -V '"msm_vfe0_rdi0":0[fmt:SGRBG10_1X10/4224x3136]'

# Disable the OV02C10 path so it doesn't fight for csid0
media-ctl -l '"msm_csiphy4":1->"msm_csid0":0[0]'

# Enable the rear path
media-ctl -l '"msm_csiphy0":1->"msm_csid0":0[1]'
