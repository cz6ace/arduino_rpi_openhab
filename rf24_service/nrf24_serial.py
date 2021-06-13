#!/usr/bin/python3
# nrf24l01 serial gateway using Arduino nano 

import serial

"""
 Sending data
 byte 0: >
 byte 1: length of data + 1 (address)
 byte 2: address of tgt device
 byte 3..n: payload


 Receiving data
 byte 0: >
 byte 1: length of the data
 byte 2..n: payload
"""


class Proxy:
    def __init__(self, port, verbose=False):
        self.serial = serial.Serial(port)
        self.verbose = verbose

    def write(self, addr, data):
        packet = bytearray()
        packet.append(ord(">"))
        packet.append(len(data) + 1)
        packet.append(addr & 255)
        for b in data:
            packet.append(b)

        if self.verbose:
            print("TX:", packet)
        self.serial.write(packet)

    def available(self):
        return self.serial.in_waiting

    def read(self):
        preambule = self.serial.read()[0]
        if preambule != ord(">"):
            print("wrong character: " + chr(preambule))
            return None
        count = self.serial.read()[0]
        packet = self.serial.read(count)
        if self.verbose:
            print(f"count={count}, read={len(packet)}")
            print("RX:", packet)
        return packet

    def close(self):
        self.serial.close()


if __name__ == "__main__":
    proxy = Proxy('/dev/ttyUSB0')  # open serial port
    print(proxy.serial.name) # check which port was really used
    try:
        while True:
            if proxy.available():
                proxy.read()
    finally:
        proxy.close()
