#!/bin/bash
# Common version handling for ci/cd scripts
# https://semver.org/

set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
SOURCE_DIR=$(dirname "${SCRIPT_DIR}")

if [ -n "$(git status -s "${SOURCE_DIR}")" ]; then
    SEMVER_PREFIXED_PRERELEASE="-dirty"
    REPO_CLEAN=false
else
    SEMVER_PREFIXED_PRERELEASE=""
    REPO_CLEAN=true
fi

PRIMARY_VERSION_FILE="${SOURCE_DIR}/.versions"
if [ ! -f "${PRIMARY_VERSION_FILE}" ]; then
    echo >&2 "ERROR: Version file ${PRIMARY_VERSION_FILE} not found"
    echo "FAULT"
    exit 1
fi

LAST_VERSION=$(grep "^[0-9]\+\.[0-9]\+\.[0-9]\+[[:space:]]\+[0-9a-f]\+$" "${PRIMARY_VERSION_FILE}" | tail -n 1)

SEMVER_VERSION_MAJOR=$(echo "$LAST_VERSION" | awk '{print $1}' | cut -f 1 -d .)
SEMVER_VERSION_MINOR=$(echo "$LAST_VERSION" | awk '{print $1}' | cut -f 2 -d .)
SEMVER_VERSION_PATCH=$(echo "$LAST_VERSION" | awk '{print $1}' | cut -f 3 -d .)
VERSION_LAST_SHA=$(echo "$LAST_VERSION" | awk '{print $2}')

# Patch is the count of commits since the last Version file line sha
# ~1 is because git omits the trailing newline when outputting to a pipe, making it imposible to tell 0 commits from 1 with wc alone,
#  And to make sure something is output to avoid a pipefail
# The grep ensures each line has a newline.
SEMVER_NEW_VERSION_PATCH=$(git log --pretty=format:"%H" "${VERSION_LAST_SHA}"~1.. "${SOURCE_DIR}" | wc -l)

if [ $SEMVER_NEW_VERSION_PATCH -lt $SEMVER_VERSION_PATCH -a $REPO_CLEAN == "true" ]; then
    echo >&2 "ERROR: Git patch version $SEMVER_NEW_VERSION_PATCH less than released patch version $SEMVER_VERSION_PATCH"
    echo ERROR
    exit 1
fi

CUR_SEMVER="${SEMVER_VERSION_MAJOR}.${SEMVER_VERSION_MINOR}.${SEMVER_VERSION_PATCH}"
