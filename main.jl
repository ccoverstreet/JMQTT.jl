using Sockets
jmqtt =  include("./jmqtt.jl")


function some_processing_queue(id::Number, c::Channel)
	while true
		x = take!(c)
		println("Processing queue $id found a packet")
		if x isa jmqtt.PubPacket
			println("QOS: $(x.qos)")
		end
	end
end


function main()
	port = 1883
	server = listen(1883)

	packet_queue = Channel()

	errormonitor(Threads.@spawn some_processing_queue(1, packet_queue))
	errormonitor(Threads.@spawn some_processing_queue(2, packet_queue))

	while true
		sock = accept(server)

		errormonitor(@async while isopen(sock)
					 	 packet = jmqtt.read_packet(sock)
					 	 dump(packet)

					 	 if packet isa jmqtt.CONNECTPacket
					 	 	 connack = jmqtt.CONNACKPacket(false, UInt8(jmqtt.CONNECT_OK))
					 	 	 jmqtt.write_packet(sock, connack)

				 	 	 elseif packet isa jmqtt.PUBLISHPacket
				 	 	 	 put!(packet_queue, packet)
				 	 	 	 if isnothing(packet.packet_id)
				 	 		 	 continue
				 	 	 	 end

						 	 # QOS 1 handle
						 	 if packet.qos == 0
				 	 	 	 	 puback = jmqtt.PUBACKPacket(packet.packet_id)
				 	 	 	 	 jmqtt.write_packet(sock, puback)
					 	 	 elseif packet.qos == 2
					 	 	 	 pubrec = jmqtt.PUBRECPacket(packet.packet_id)
				 	 	 	 	 jmqtt.write_packet(sock, pubrec)
						 	 end

					 	 elseif packet isa jmqtt.PUBRELPacket
						 	 pubcomp = jmqtt.PUBCOMPPacket(packet.packet_id)
				 	 	 	 jmqtt.write_packet(sock, pubcomp)

				 	 	 elseif packet isa jmqtt.SUBSCRIBEPacket
				 	 	 	 suback = jmqtt.SUBACKPacket(packet.packet_id, [0])
				 	 	 	 println(suback)
				 	 	 	 jmqtt.write_packet(sock, suback)
				 	 	 end
	   			 	 end)
	end
end

main()
