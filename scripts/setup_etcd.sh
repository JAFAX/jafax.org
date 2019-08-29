#!/bin/bash

set -e
set -u
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DATA="$DIR/../data"
. ${DIR}/libs/color.shlib
. ${DIR}/libs/say.shlib
. ${DIR}/libs/get_os.shlib
. ${DIR}/libs/debian.shlib
. ${DIR}/libs/opensuse.shlib

function install_etcd {
  os_name=$(get_os_name)

  say "${FG_L_GREEN}INSTALLING etcd${NORMAL}"
  if [[ $os_name == "debian" ]]; then
    apt_inst etcd
  elif [[ $os_name == "opensuse" ]]; then
    zyp_inst etcd
  fi
}
