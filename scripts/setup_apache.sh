#!/bin/bash

set -e
set -u
set -o pipefail

INSTALL_ROOT=/srv/buyo

# make sure we have the latest version of the buyo framework checked out
cd ${INSTALL_ROOT}
git pull

# link our apache site config into place
ln -s ${INSTALL_ROOT}/apache2/site/${hostname --fqdn}.conf /etc/apache2/sites-enabled/100-buyo.conf

# enable the modules we need
for MOD in 'proxy' 'proxy_http' 'proxy_balancer' 'lbmethod_byrequests'; do
  a2enmod ${MOD}
done

# enable apache and turn it on
systemctl enable apache2.service
systemctl start apache2.service

