#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/_version_common.sh"

echo "$CUR_SEMVER"
exit 0
