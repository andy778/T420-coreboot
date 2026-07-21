#!/bin/sh
# Runs as root: fix ownership of the lbmk tree and the mounted /output so the
# unprivileged `builder` user can write to both, then drop privileges.
set -eu

chown -R builder:builder /home/builder/lbmk
chown builder:builder /output 2>/dev/null || true

exec gosu builder /usr/local/bin/build-rom.sh
