# arduino_rpi_openhab
This project provides python and bash scripts for providing connection between Arduino's and MQTT using NRF24L01 on both sides - Raspberry Pi 2 and Arduino. No WiFi/Ethernet arduino shield is needed. The MQTT can be used by Openhab.
Also there is helper bash script for rapid startup with automated installation of required libraries, also removing bloatware from Raspbian.

## How to start:
On Raspberry Pi 2 after Raspbian installation do:

```sh
git clone https://github.com/cz6ace/arduino_rpi_openhab.git
cd arduino_rpi_openhab/scripts
sudo ./postinstall
# service installation
cd ../rf24_service
sudo ./install
```
