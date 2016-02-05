#!/bin/bash
#
# Post install script for Raspbian preparing OpenHAB + Arduino integration
#
verbose=0

#
# test if user is root
# 
test_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Must run as root"
    exit 1
  fi
}

#
# system update
#
system_update() {
  echo "System upgrade"
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo apt-get -y install etckeeper
}

#
# optional packages, nice to have
#
inst_opt_packages() {
  echo "Install optional packages"
  paks="
byobu
mc
wget
screen
xrdp
bash-completion
telnet
vim
htop
apt-transport-https
"
  sudo apt-get -y install $paks
}

#
# packages for development with Arduino, OpenHAB
#
inst_dev_packages() {
  echo "Install python development packages"
  paks="
git
python-smbus 
i2c-tools
python2.7-dev
python-dev
python-rpi.gpio
mosquitto
mosquitto-clients
"
  sudo apt-get -y install $paks
  sudo pip install spidev
  sudo pip install paho-mqtt
  sudo pip install anyconfig
}

#
# Installs fixed GPIO
# https://www.raspberrypi.org/forums/viewtopic.php?f=32&t=98070&p=681410#p681410
#
inst_fix_gpio() {
  echo "Install spi driver for python library"
  git clone https://github.com/Gadgetoid/py-spidev
  pushd py-spidev
  sudo make install
  popd
}

#
# downloads example for spi & nrf24
#
inst_nrf_example() {
  git clone https://github.com/riyas-org/nrf24pihub
}

#
# Installs RF24 libs
#
inst_rf24() {
  wget http://tmrh20.github.io/RF24Installer/RPi/install.sh
  chmod +x install.sh
  sudo ./install.sh
}

#
# Removes bloatware
#
remove_bloat() {
  echo "Remove bloatware"
  paks="
minecraft-pi
wolfram-*
timidity
sonic-pi
"
  sudo apt-get -y remove --purge $paks
  sudo apt-get -y autoremove
}

inst_openhab() {
  openhab=/opt/openhab
  sudo mkdir -p $openhab
  pushd $openhab
  oh_version=1.7.1
  sudo wget https://bintray.com/artifact/download/openhab/bin/distribution-${oh_version}-runtime.zip
  sudo unzip distribution-${oh_version}-runtime.zip
  sudo rm -f distribution-${oh_version}-runtime.zip
  cd addons/
  sudo wget https://bintray.com/artifact/download/openhab/bin/distribution-${oh_version}-addons.zip
  unzip -l distribution-${oh_version}-addons.zip "*homematic*" "*gpio*" "*mqtt-*" "*pushover*" "*mail*" "*ntp*" "*mysql*" "*rrd4j*" "*mail*" "*wol*" "*exec*" "*logging*" "*http*"
  #sudo unzip distribution-${oh_version}-addons.zip
  sudo rm -f distribution-${oh_version}-addons.zip
  sudo wget https://bintray.com/artifact/download/openhab/bin/distribution-${oh_version}-demo.zip
  #sudo unzip distribution-${oh_version}-demo.zip
  #sudo rm -f distribution-${oh_version}-demo.zip
  cd ..
  sudo cp configurations/openhab_default.cfg configurations/openhab.cfg
  # unzip demo ?
  sudo chmod +x start.sh
  popd
}

inst_homegear() {
  # hmland
  sudo apt-get install -y libusb-1.0-0-dev build-essential git
  if [ ! -d /opt ]; then
    sudo mkdir -p /opt
  fi
  pushd /opt
  if [ ! -d hm ]; then
    mkdir hm
    cd hm
    sudo git clone git://git.zerfleddert.de/hmcfgusb
    cd hmcfgusb
    sudo make
    sudo cp hmcfgusb.rules /etc/udev/rules.d/
    # startup scripts 
    cp debian/hmland.init /etc/init.d/hmland
    chmod +x /etc/init.d/hmland
    cp debian/hmland.default /etc/default/hmland
    #TODO vim /etc/default/hmland
    systemctl enable hmland
    cd ..
  fi
  popd
  # homegear
  wget https://homegear.eu/packages/Release.key && sudo apt-key add Release.key && rm Release.key
  echo 'deb https://homegear.eu/packages/Raspbian/ jessie/' | sudo tee /etc/apt/sources.list.d/homegear.list
  sudo apt-get update
  sudo apt-get install -y homegear
}

#
# main
#
echo Post-install
if [[ $# -eq 0 ]]; then
  echo "Specify install type. Options are (only one at a time)"
  echo "-all -bloat -update -dev -opt -gpio -nrf -homegear -openhab"
  exit 1
fi
#test_root
install_all=0
if [[ "$1" = "-all" ]]; then
  install_all=1
fi
if [[ $install_all == 1 || "-bloat" = "$1" ]]; then
  remove_bloat
fi
if [[ $install_all == 1 || "-update" = "$1" ]]; then
  system_update
fi
if [[ $install_all == 1 || "-dev" = "$1" ]]; then
  inst_dev_packages
fi
if [[ $install_all == 1 || "-opt" = "$1" ]]; then
  inst_opt_packages
fi
if [[ $install_all == 1 || "-gpio" = "$1" ]]; then
  inst_fix_gpio
fi
if [[ $install_all == 1 || "-nrf" = "$1" ]]; then
  inst_nrf_example
fi
if [[ $install_all == 1 || "-homegear" = "$1" ]]; then
  inst_homegear
fi
if [[ $install_all == 1 || "-openhab" = "$1" ]]; then
  inst_openhab
fi
# not needed ?
#inst_rf24
#
#sudo update-alternatives --set editor /usr/bin/vim.basic
#pushd /etc
#git remote add origin ssh://admin@nas/share/homes/libor/git/etc_pi.git
#git push -u origin master
#popd
#
echo DONE.
