#!/bin/bash

set -e
set -u
set -o pipefail

INSTALL_ROOT=/srv/buyo
. ${INSTALL_ROOT}/scripts/libs/link.shlib

# make sure we have the latest version of the buyo framework checked out
cd ${INSTALL_ROOT}
git pull

# link our apache site config into place
softlink ${INSTALL_ROOT}/apache2/site/$(hostname -f).conf /etc/apache2/sites-enabled/100-buyo.conf

# enable the modules we need
for MOD in 'proxy' 'proxy_http' 'proxy_balancer' 'lbmethod_byrequests'; do
  a2enmod ${MOD}
done

# enable apache and turn it on
systemctl enable apache2.service
systemctl start apache2.service

