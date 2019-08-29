#!/bin/bash

set -e
set -u
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. ${DIR}/libs/get_os.shlib
. ${DIR}/libs/opensuse.shlib
. ${DIR}/libs/debian.shlib
. ${DIR}/libs/link.shlib

cd ${DIR}/..
INSTALL_ROOT=$(pwd)

# which OS are we on?
operatingsystem=$(get_os_name)

# ensure we have the latest version of the buyo site framework
cd ${INSTALL_ROOT}
git pull

# ensure our dependent packages are installed
if [[ ${operatingsystem} == "opensuse" ]]; then
  zyp_install_pkgs
elif [[ ${operatingsystem} == "debian" ]]; then
  apt_install_pkgs ${INSTALL_ROOT}
fi

# link our systemd service unit into place
softlink ${INSTALL_ROOT}/systemd/buyo.service /etc/systemd/system/buyo.service

# enable our service
systemctl daemon-reload
systemctl enable buyo.service
systemctl start buyo.service

