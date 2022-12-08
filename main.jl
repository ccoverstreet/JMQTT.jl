using Sockets
jmqtt =  include("./jmqtt.jl")


port = 1883
server = listen(1883)

while true
	sock = accept(server)


	errormonitor(@async while isopen(sock)
					 packet = jmqtt.read_packet(sock)
					 dump(packet)

					 if packet isa jmqtt.CONNECTPacket
					 	 connack = jmqtt.CONNACKPacket(false, UInt8(jmqtt.CONNECT_OK))
					 	 jmqtt.write_packet(sock, connack)

				 	 elseif packet isa jmqtt.PUBLISHPacket
				 	 	 if isnothing(packet.packet_id)
				 	 		 continue
				 	 	 end

						 # QOS 1 handle
						 if packet.qos == 1
				 	 	 	 puback = jmqtt.PUBACKPacket(packet.packet_id)
				 	 	 	 jmqtt.write_packet(sock, puback)
					 	 elseif packet.qos == 2
					 	 	 pubrec = jmqtt.PUBRECPacket(packet.packet_id)
				 	 	 	 jmqtt.write_packet(sock, pubrec)
						 end

					 elseif packet isa jmqtt.PUBRELPacket
						 pubcomp = jmqtt.PUBCOMPPacket(packet.packet_id)
				 	 	 jmqtt.write_packet(sock, pubcomp)

				 	 end
	   			 end)
end

