#!/usr/bin/env bash

set -eu -o pipefail

TMPDIR=$(mktemp -d)

trap 'rm -f -- "$TMPDIR"' EXIT

# Download version data
curl --silent --show-error --fail --location --retry 10 --retry-connrefused https://go.dev/dl/?mode=json > $TMPDIR/version.json

LOCAL_VERSION=$(make print-go-version | cut -d= -f2)

MAJOR_MINOR_VERSION=$(echo "$LOCAL_VERSION" | grep -Eo "[0-9]+.[0-9]+")

NEW_VERSION=$(<$TMPDIR/version.json jq -r ".[] | select(.version? | match(\"$MAJOR_MINOR_VERSION.*\")) | .version | sub(\"go\";\"\")")

# Don't want to update a minor version - only want to update patch versions!
if [[ $NEW_VERSION == "" ]]; then
	echo "failed to fetch the latest version of go $MAJOR_MINOR_VERSION.*"
	echo "this could mean the go version is very old or that go versioning has changed"
	exit 1
fi

# Check if there's nothing to do
if [[ $NEW_VERSION == $LOCAL_VERSION ]]; then
	echo "go version is up to date; exiting"
	exit 0
fi

TARGET=modules/tools/00_mod.mk

echo "updating go version to $NEW_VERSION in $TARGET"

sed -i '' "s/^VENDORED_GO_VERSION := $LOCAL_VERSION$/VENDORED_GO_VERSION := $NEW_VERSION/" $TARGET
