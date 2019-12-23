#!/bin/bash

set -x
set -e
set -u
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DATA="$DIR/../data"
. ${DIR}/libs/color.shlib
. ${DIR}/libs/say.shlib
. ${DIR}/libs/os.shlib
. ${DIR}/libs/debian.shlib
. ${DIR}/libs/opensuse.shlib

function install_etcd {
  os_name=$(get_os_name)

  say "${FG_L_GREEN}INSTALLING etcd${NORMAL}"
  if [[ $os_name == "debian" ]]; then
    apt_inst etcd
  elif [[ $os_name == "opensuse" ]]; then
    zypp_inst etcd
  fi
}

function configure_etcd {
  os_name=$(get_os_name)

  if [[ $os_name == "debian" ]]; then
    if [[ ! -f /etc/default/etcd.original ]]; then
      say "${FG_L_GREEN}CONFIGURING etcd${NORMAL}"
      mv /etc/default/etcd /etc/default/etcd.original
      cat << EOF > /etc/default/etcd
ETCD_NAME="localhost"
ETCD_DATA_DIR="/srv/buyo/etcd/data/localhost"
ETCD_SNAPSHOT_COUNT="1000"
ETCD_HEARTBEAT_INTERVAL="100"
ETCD_LISTEN_PEER_URLS="http://localhost:2380,http://localhost:7001"
ETCD_LISTEN_CLIENT_URLS="http://localhost:2379,http://localhost:4001"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://localhost:2380,http://localhost:7001"
ETCD_INITIAL_CLUSTER="default=http://localhost:2380,default=http://localhost:7001"
ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379,http://localhost:4001"
DAEMON_ARGS=""
EOF
    else
      say "${FG_L_CYAN}etcd ALREADY CONFIGURED. SKIPPING${NORMAL}"
    fi
  elif [[ $os_name == "opensuse" ]]; then
    if [[ ! -f /etc/sysconfig/etcd.original ]]; then
      say "${FG_L_GREEN}CONFIGURING etcd${NORMAL}"
      mv /etc/sysconfig/etcd /etc/sysconfig/etcd.original
      cat << EOF > /etc/sysconfig/etcd
ETCD_NAME="localhost"
ETCD_DATA_DIR="/srv/buyo/etcd/data/localhost"
ETCD_SNAPSHOT_COUNT="1000"
ETCD_HEARTBEAT_INTERVAL="100"
ETCD_LISTEN_PEER_URLS="http://localhost:2380,http://localhost:7001"
ETCD_LISTEN_CLIENT_URLS="http://localhost:2379,http://localhost:4001"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://localhost:2380,http://localhost:7001"
ETCD_INITIAL_CLUSTER="default=http://localhost:2380,default=http://localhost:7001"
ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379,http://localhost:4001"
DAEMON_ARGS=""
EOF
    else
      say "${FG_L_CYAN}etcd ALREADY CONFIGURED. SKIPPING${NORMAL}"
    fi
  fi
  # write our override unit file
  mkdir -pv /etc/systemd/system/
  if [[ $os_name == "debian" ]]; then
    cat << EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd - highly-available key value store
Documentation=https://github.com/coreos/etcd
Documentation=man:etcd
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%p
WorkingDirectory=/var/lib/etcd/
User=etcd
PermissionsStartOnly=true
Restart=on-abnormal
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/sbin/etcd --name=\"${ETCD_NAME}\" --data-dir=\"${ETCD_DATA_DIR}\" --listen-client-urls=\"${ETCD_LISTEN_CLIENT_URLS}\" $DAEMON_ARGS"
LimitNOFILE=65536
Nice=-10
IOSchedulingClass=best-effort
IOSchedulingPriority=2

[Install]
WantedBy=multi-user.target
EOF
  elif [[ $os_name == "opensuse" ]]; then
    cat << 'EOF' > /etc/systemd/system/etcd.service
[Unit]
Description=etcd - highly-available key value store
Documentation=https://github.com/coreos/etcd
Documentation=man:etcd
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/%p
WorkingDirectory=/var/lib/etcd/
User=etcd
PermissionsStartOnly=true
Restart=on-abnormal
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/sbin/etcd --name=\"${ETCD_NAME}\" --data-dir=\"${ETCD_DATA_DIR}\" --listen-client-urls=\"${ETCD_LISTEN_CLIENT_URLS}\" $DAEMON_ARGS"
LimitNOFILE=65536
Nice=-10
IOSchedulingClass=best-effort
IOSchedulingPriority=2

[Install]
WantedBy=multi-user.target
EOF
  fi
}

install_etcd
configure_etcd

say "${FG_L_CYAN}Register and Start etcd${NORMAL}"
systemctl daemon-reload
systemctl enable etcd.service
systemctl start etcd.service

say "${FG_L_GREEN}etcd has been started${NORMAL}"
