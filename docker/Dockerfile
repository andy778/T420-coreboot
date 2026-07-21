# Builds a Libreboot t420 ROM for this specific machine:
#   Libreboot <RELEASE>  ->  ./mk inject (neutered ME + onboard NIC MAC)
#                        ->  cbfstool: add real Intel VBIOS, drop SeaVGABIOS
# Output is written to /output (mount a host directory there).
#
# Build (pin the release you want):
#   docker build -f docker/Dockerfile --build-arg RELEASE=26.01rev1 -t t420-rom .
# Run:
#   docker run --rm -v "$PWD/out:/output" t420-rom
#
# When a new Libreboot version comes out, just rebuild with a new RELEASE.

FROM debian:trixie

ARG RELEASE=26.01rev1
ENV RELEASE=${RELEASE}

# Runtime knobs (override with -e on `docker run`)
ENV BOARD=t420_8mb \
    VARIANT=seagrub_t420_8mb_libgfxinit_txtmode_svenska \
    MAC=00:21:cc:61:b8:5c \
    MIRROR=https://mirrors.mit.edu/libreboot/stable

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates wget xz-utils gnupg gosu \
    # lbmk's own `apt-get install` (in `./mk dependencies`) runs without -y;
    # auto-confirm it since there's no TTY to answer the [Y/n] prompt.
    && echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90assumeyes

# lbmk refuses to run as root, so build/inject happen as this user.
RUN useradd -m -u 1000 builder

# Clone + pin lbmk, install its build dependencies (root-only step).
# apt-get update again here: `./mk dependencies` runs its own apt-get install,
# so the package index must still be present.
RUN apt-get update \
    && git clone https://codeberg.org/libreboot/lbmk /home/builder/lbmk \
    && cd /home/builder/lbmk \
    && git fetch --tags \
    && git checkout "${RELEASE}" \
    && ./mk dependencies debian \
    && git config --global user.name "builder" \
    && git config --global user.email "builder@localhost" \
    && rm -rf /var/lib/apt/lists/*

# The real Intel VBIOS + the patch/entrypoint script from this repo.
COPY vgabios.bin /home/builder/vgabios.bin
COPY docker/build-rom.sh /usr/local/bin/build-rom.sh
RUN chmod +x /usr/local/bin/build-rom.sh

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME /output
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
