#!/usr/bin/env sh
set -eu

VM_NAME="${SYSTEMD_LIMA_VM:-systemd-test}"
PROJECT_DIR="${SYSTEMD_PROJECT_DIR:-/Users/dannote/Development/systemd}"
REMOTE_DIR="${SYSTEMD_REMOTE_DIR:-~/systemd-test-src}"

~/.local/bin/limactl shell "$VM_NAME" -- sh -lc "
  rm -rf $REMOTE_DIR &&
  mkdir -p $REMOTE_DIR &&
  tar -C '$PROJECT_DIR' --exclude=_build --exclude=deps --exclude=doc -cf - . | tar -C $REMOTE_DIR -xf - &&
  cd $REMOTE_DIR &&
  mix deps.get >/dev/null &&
  SYSTEMD_INTEGRATION=1 mix test
"
