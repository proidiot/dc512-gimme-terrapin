#!/bin/sh
set -eux

export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y devscripts debian-goodies dpkg-dev build-essential
apt build-dep -y `find . -name '*.dsc'`

cd `find . -maxdepth 2 -type d -name debian -exec dirname {} \;`
debuild -us -uc
