import paho.mqtt.client as mqtt

client = mqtt.Client("ASDASD")

client.connect("localhost", keepalive=60)
client.subscribe("fart")
client.publish("fart", payload="ASDA")
