#!/usr/bin/python
# raspberry pi nrf24l01 hub
# more details at http://blog.riyas.org
# Credits to python port of nrf24l01, Joao Paulo Barrac & maniacbugs original c library

from nrf24 import NRF24
import time
from time import gmtime, strftime

import paho.mqtt.client as mqtt
import threading
import Queue
from time import sleep
import logging
import os, struct, anyconfig
import argparse

#constants
MODE_BINARY = 1
INDEX_MODE = 0
INDEX_ID = 1
INDEX_COMMAND = 2
INDEX_TYPE = 3
INDEX_SIZE = 4
INDEX_DATA = 5

# data types
TYPE_BYTE=1
TYPE_BOOL=2
TYPE_INT=3
TYPE_FLOAT=4
TYPE_STRING=5

# Define and parse command line arguments
LOG_FILENAME = ""
parser = argparse.ArgumentParser(description="My simple Python service")
parser.add_argument("-l", "--log", help="file to write log to")
# If the log file is specified on the command line then override the default
args = parser.parse_args()
if args.log:
	LOG_FILENAME = args.log
	logging.basicConfig(level=logging.DEBUG, filename=LOG_FILENAME, format='%(asctime)s:%(levelname)s:%(message)s', datefmt='%m/%d/%Y %H:%M:%S')
else:
	# log to console
	logging.basicConfig(level=logging.DEBUG, format='%(asctime)s:%(levelname)s:%(message)s', datefmt='%m/%d/%Y %H:%M:%S')

#               TGT address                 OUR address
pipes = [[0xf0, 0xf0, 0xf0, 0xf0, 0xe1], [0xf0, 0xf0, 0xf0, 0xf0, 0x00]]

radio = NRF24()
radio.begin(0, 0,25,18) #set gpio 25 as CE pin
radio.setRetries(5,15)
radio.setPayloadSize(32)
radio.setChannel(0x40)
radio.setDataRate(NRF24.BR_250KBPS)
radio.setPALevel(NRF24.PA_MAX)
radio.setAutoAck(1)
radio.openWritingPipe(pipes[0])
radio.openReadingPipe(1, pipes[1])

radio.startListening()
radio.stopListening()

radio.printDetails()
radio.startListening()

cmdQ = Queue.Queue()
conf_file = "rf24_proxy.conf"
if not os.path.isfile(conf_file):
	conf_file = "/etc/" + conf_file
config = anyconfig.load(conf_file, "properties") if os.path.isfile(conf_file) else anyconfig.container()


class MQ(threading.Thread):
	"""
	Class for communicating with MQTT. Publishing and also subscribing to particular topics
	"""
	client = mqtt.Client()
	queue = Queue.Queue()
	on_message_callback = None

	def __init__(self):
		threading.Thread.__init__(self)
		#
		self.client.on_connect = self.on_connect
		self.client.on_message = self.on_message
		self.client.connect("localhost", 1883, 60)

	def run(self):
		""" runs loop reading from queue the topic and payload, publishing it to the MQTT """
		self.client.loop_start()
		while True:
			#sleep(10)
			#if not self.queue.empty():
			topic, payload = self.queue.get()
			self.client.publish(topic, payload)
			logging.debug("Read from RF24 queue " + topic + " " + payload)

	def put(self, topic, payload):
		""" Puts topic and payload into the queue for later publishing """
		self.queue.put((topic, payload))

	def on_connect(self, client, userdata, flags, rc):
		""" Event callback when client is connected to the MQTT """
		logging.info("Connected to MQTT with result code "+str(rc))
		# Subscribing in on_connect() means that if we lose the connection and
		# reconnect then subscriptions will be renewed.
		#self.client.subscribe("$SYS/#")
		self.client.subscribe("command/#")

	def on_message(self, client, userdata, msg):
		""" Callback when message arrives into the subscribed topic """
		#logging.debug(msg.topic+" "+str(msg.payload))
		if self.on_message_callback != None:
			self.on_message_callback(msg)

	def set_on_message(self, callback):
		""" Setter of the user callback function when the subscription receives message """
		self.on_message_callback = callback


def on_mq_message(msg):
	"""Implementation when subscription receives message. 
	The payload is parsed and put into the queue for delivering to the arduino 
	"""
	print (msg.topic + " " + str(msg.payload))
	fields = msg.topic.split("/")
	if len(fields) < 2:
		logging.error("Expects 2 or more params of topic")
		return
	addr = int(fields[1])
	bindata = []
	for i in range(0, len(fields) - 2):
		bindata.append(int(fields[i+2]))
	# add comd to queue for NRF24
	cmdQ.put((addr, bindata, msg.payload))


def get_topic(command, client_id):
	""" Returns text topic from the mapping table from binary message """
	global config
	topic = config.get(str(client_id) + "." + str(command))
	if topic != None:
		return topic
	return "raw/" + str(client_id) + "/" + str(command)

def parseCommand(buff):
	""" Parses binary command from arduino and converts the primitive variable into the python variable """
	if buff[INDEX_MODE] == MODE_BINARY:
		logging.debug("parsing binary data");
		command = buff[INDEX_COMMAND]
		cid = buff[INDEX_ID]
		dtype = buff[INDEX_TYPE]
		size = buff[INDEX_SIZE]
		data = buff[INDEX_DATA:INDEX_DATA + size]
		strdata = ''.join(chr(i) for i in data)
		logging.debug("sender=" + str(cid) + ", command=" + str(command) + ", dtype=" + str(dtype) + ", len=" + str(size));
		if dtype == TYPE_BYTE:
			return (get_topic(command, cid), str(struct.unpack('B', strdata)[0]))
		elif dtype == TYPE_BOOL:
			return (get_topic(command, cid), str(struct.unpack('?', strdata)[0]))
		elif dtype == TYPE_INT:
			return (get_topic(command, cid), str(struct.unpack('i', strdata)[0]))
		elif dtype == TYPE_FLOAT:
			return (get_topic(command, cid), str(struct.unpack('f', strdata)[0]))
		elif dtype == TYPE_STRING:
			return (get_topic(command, cid), strdata)
		else:
			logging.error("Unknown data type " + str(dtype))
	else:
		logging.debug("parsing text data");
		out = ''.join(chr(i) for i in recv_buffer)
		logging.debug("parsing text data: " + out);
		arr = out.split("#")
		if len(arr) == 2:
			return (arr[0], arr[1])
		else:
			return (None, None)

#
# Main
#
mq = MQ()
mq.setDaemon(True)
mq.start()
mq.set_on_message(on_mq_message)

cntr = 0
while True:
	pipe = [0]
	while not radio.available(pipe, True):
		# when no data available, process commands queue
		if not cmdQ.empty():
			addr, bindata, value = cmdQ.get()
			payload = ''.join(chr(i) for i in bindata)
			payload = payload + value
			logging.info("Transmit: addr=" + str(addr) +", bindata=" + str(bindata) + ", value=" + value + ", payload=" + payload)
			# open writing pipe for proper node address
			outPipe = pipes[0]
			outPipe[4] = addr
			radio.stopListening();
			radio.openWritingPipe(outPipe)
			ok = radio.write(payload)
			radio.startListening()
			if not ok:
				logging.error("Transmit (write) command failed, no ack received.")

		#
		time.sleep(2.0/1000.0)
	recv_buffer = []
	radio.read(recv_buffer)
	out = ''.join(chr(i) for i in recv_buffer)
	topic, value = parseCommand(recv_buffer)
	# put the topic fo the queue to be published to the MQTT
	if (topic is not None):
		mq.put(topic, value)
		logging.debug("Received frame: " + str(cntr) + " " + topic + ":" + value)
	else:
		logging.error("Corrupted data received?")
	cntr += 1
# EOF
