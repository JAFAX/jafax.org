#!/bin/bash

pushd /srv/jafax.org > /dev/null 2>&1
  # ensure we're in the release branch
  git checkout release
  # sync
  git pull
popd > /dev/null 2>&1