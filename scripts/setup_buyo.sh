#!/bin/bash

set -x
set -e
set -u
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. ${DIR}/libs/os.shlib
. ${DIR}/libs/opensuse.shlib
. ${DIR}/libs/debian.shlib
. ${DIR}/libs/link.shlib

cd ${DIR}/..
INSTALL_ROOT=$(pwd)

# which OS are we on?
operatingsystem=$(get_os_name)

# ensure we have the latest version of the buyo site framework
cd ${INSTALL_ROOT}
say "${FG_L_CYAN}Configuring Buyo${NORMAL}"
say "${FG_WHITE}CWD: $(pwd)${NORMAL}"
git pull
exit

# ensure our dependent packages are installed
if [[ ${operatingsystem} == "opensuse" ]]; then
  zypp_install_pkgs ${INSTALL_ROOT}
elif [[ ${operatingsystem} == "debian" ]]; then
  apt_install_pkgs ${INSTALL_ROOT}
fi

# link our systemd service unit into place
softlink ${INSTALL_ROOT}/systemd/buyo.service /etc/systemd/system/buyo.service

cd ${INSTALL_ROOT}/scripts
./setup_etcd.sh
cd -

# inject initial data
etcdctl mkdir /com
etcdctl mkdir /com/yggdrasilsoft
etcdctl mkdir /com/yggdrasilsoft/buyo
etcdctl mkdir /com/yggdrasilsoft/buyo/users
etcdctl mkdir /com/yggdrasilsoft/buyo/roles

# set up the etcd roles and users for the system
# NOTE: This is setting a default password for the etcd root user. Remember to
#       change this in a production environment
echo "adminpass" | etcdctl user add root --interactive=false
etcdctl role add buyo-ro
etcdctl role add buyo-rw
# NOTE: This is setting default passwords for the buyo-ro and buyo-rw users.
#       Remeber to change these in a production environment
echo "buyo-ro" | etcdctl user add buyo-ro
echo "buyo-rw" | etcdctl user add buyo-rw
etcdctl user grant-role buyo-ro buyo-ro
etcdctl user grant-role buyo-rw buyo-rw

# grant access rights to the tress
etcdctl role grant-permission buyo-ro --prefix=true read /com/yggdrasilsoft/buyo
etcdctl role grant-permission buyo-rw --prefix=true readwrite /com/yggdrasilsoft/buyo

# enable authentication
etcdctl auth enable

# enable our service
systemctl daemon-reload
systemctl enable buyo.service
systemctl start buyo.service
