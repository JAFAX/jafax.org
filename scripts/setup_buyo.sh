#!/bin/bash

set -e
set -u
set -o pipefail

INSTALL_ROOT=/srv/buyo

# load our functions
. ${INSTALL_ROOT}/scripts/libs/get_os.shlib
. ${INSTALL_ROOT}/scripts/libs/opensuse.shlib
. ${INSTALL_ROOT}/scripts/libs/debian.shlib

# which OS are we on?
operatingsystem=$(get_os_name)

# ensure we have the latest version of the buyo site framework
cd ${INSTALL_ROOT}
git pull

# ensure our dependent packages are installed
if [[ ${operatingsystem} == "opensuse" ]]; then
  zyp_install_pkgs
elsif [[ ${operatingsystem} == "debian" ]]; then
  apt_install_pkgs ${INSTALL_ROOT}
fi

# link our systemd service unit into place
ln -s ${INSTALL_ROOT}/systemd/buyo.service /etc/systemd/system/buyo.service

# enable our service
systemctl daemon-reload
systemctl enable buyo.service
systemctl load buyo.service

