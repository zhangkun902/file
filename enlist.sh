#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.

edge_dir=$HOME/edge

if [ -d "$edge_dir" ]; then
  if [ "$1" == "-f" ]; then
    rm -rf $edge_dir
  else
    echo "ERROR: Edge Enlistment already exists at $edge_dir, use -f to force override" >&2
    exit 1;
  fi
fi

# install pre-reqs, will prompt for root password
# disable service restart checks while installing libraries
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
sudo add-apt-repository -y ppa:git-core/ppa
sudo apt -y update
sudo apt-get -y install git
sudo apt-get -y install curl
sudo apt-get -y install wget
sudo apt-get -y install lsof
sudo apt-get -y install python
sudo apt-get -y install python-pip
python -m pip install psutil
echo '* libraries/restart-without-asking boolean false' | sudo debconf-set-selections

mkdir $edge_dir
cd $edge_dir

git config --global credential.helper store

# Will prompt if the user hasn't entered credentials for microsoft.visualstudio.com
# Need to use username/password from "Generate Git Credentials" in VSO "Clone Repository" dialog
git clone https://microsoft.visualstudio.com/DefaultCollection/Edge/_git/chromium.depot_tools depot_tools

PATH=$PATH:$edge_dir/depot_tools/scripts:$edge_dir/depot_tools

# Run cipd script to download mscipd client
$edge_dir/depot_tools/cipd version 2> /dev/null
if [ $? -ne 0 ]; then
  # Run mscipd client to authenticate before fetching
  $edge_dir/depot_tools/cipd auth-login
fi

# Don't try to update goma during the initial gclient sync

export MSGOMA_UPDATE=0

$edge_dir/depot_tools/vpython $edge_dir/depot_tools/scripts/setup/enlist.py $edge_dir $edge_dir/setup_log.txt

$edge_dir/src/build/install-build-deps.sh

pushd $edge_dir/src
gclient sync --nohooks
gclient runhooks
popd

echo "if [ -v \$EDGE_ENV ]; then" >> $HOME/.bashrc
echo "  export PATH=\$PATH:$edge_dir/depot_tools/scripts:$edge_dir/depot_tools" >> $HOME/.bashrc
echo "  export GOMACLIENTDIR=$edge_dir/depot_tools/.cipd_bin" >> $HOME/.bashrc
echo "  export GOMA_COMPILER_PROXY_PORT=8089" >> $HOME/.bashrc
echo "  ulimit -n 4096" >> $HOME/.bashrc
echo "  python \$GOMACLIENTDIR/goma_ctl.py ensure_start" >> $HOME/.bashrc
echo "  export EDGE_ENV=1" >> $HOME/.bashrc
echo "fi" >> $HOME/.bashrc

# Finish setting up the environment
source $HOME/.bashrc
