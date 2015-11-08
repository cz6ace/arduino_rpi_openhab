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
  cd py-spidev
  sudo make install
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
  sudo wget https://bintray.com/artifact/download/openhab/bin/distribution-1.7.1-runtime.zip
  sudo unzip distribution-1.7.1-runtime.zip
  sudo rm -f distribution-1.7.1-runtime.zip
  cd addons/
  sudo wget https://bintray.com/artifact/download/openhab/bin/distribution-1.7.1-addons.zip
  sudo unzip distribution-1.7.1-addons.zip
  sudo rm -f distribution-1.7.1-addons.zip
  sudo wget https://bintray.com/artifact/download/openhab/bin/distribution-1.7.1-demo.zip
  #sudo unzip distribution-1.7.1-demo.zip
  #sudo rm -f distribution-1.7.1-demo.zip
  cd ..
  sudo cp configurations/openhab_default.cfg configurations/openhab.cfg
  # unzip demo ?
  sudo chmod +x start.sh
  popd
}

#
# main
#
echo Post-install
#test_root
remove_bloat
system_update
inst_dev_packages
inst_opt_packages

inst_fix_gpio
inst_nrf_example
# not needed ?
#inst_rf24
#
#sudo update-alternatives --set editor /usr/bin/vim.basic
#pushd /etc
#git remote add origin ssh://admin@nas/share/homes/libor/git/etc_pi.git
#git push -u origin master
#popd
#
#inst_openhab
echo DONE.
