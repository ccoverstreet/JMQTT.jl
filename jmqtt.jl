module JMQTT

function read_remaining_length(sock)
	rem::Int64 = 0
	pow = 0

	while true
		b = read(sock, UInt8)
		rem = rem + (b & 127) * 128^pow
		pow = pow + 1

		if b & 128 == 0
			break
		end
	end

	return rem
end

abstract type PubPacket end

struct CONNECTPacket
	protocol_level::UInt8			

	username_flag::Bool
	password_flag::Bool
	will_retain::Bool
	will_qos::UInt8
	will_flag::Bool
	clean_session::Bool

	keep_alive::UInt16

	client_id::Union{String, Nothing}
	will_topic::Union{String, Nothing}
	will_message::Union{Array{UInt8}, Nothing}
	username::Union{String, Nothing}
	password::Union{Array{UInt8}, Nothing}
end

@enum CONNECTReturnVal begin
	CONNECT_OK = 0
	CONNECT_WRONG_PROTOCOL = 1
	CONNECT_ID_REJECTED = 2
	CONNECT_SERVER_UNAVAILABLE = 3
	CONNECT_BAD_CREDENTIALS = 4
	CONNECT_NOT_AUTHORIZED = 5
end

struct CONNACKPacket
	session_present::Bool
	return_code::UInt8
end

struct PUBLISHPacket <: PubPacket
	dup_flag::Bool
	qos::UInt8
	retain::Bool
	topic::String
	packet_id::Union{UInt16, Nothing}
	payload::Array{UInt8, 1}
end

struct PUBACKPacket
	packet_id::UInt16
end

struct PUBRECPacket 
	packet_id::UInt16
end

struct PUBRELPacket
	packet_id::UInt16
end

struct PUBCOMPPacket
	packet_id::UInt16
end

struct TopicRequest
	topic::String
	qos::UInt8
end

struct SUBSCRIBEPacket
	packet_id::UInt16
	topic_reqs::Vector{Any}
end

struct SUBACKPacket
	packet_id::UInt16
	return_codes::Array{UInt8}
end

function read_CONNECT(sock, flags, rem_len)
	payload_len = rem_len - 10
	msb = read(sock, UInt8)
	lsb = read(sock, UInt8)
	len = msb * 256 + lsb

	protoname = String(read!(sock, Array{UInt8, 1}(undef, len)))
	if protoname != "MQTT"
		error("Invalid protocol name $protoname")
	end

	protocol_level = read(sock, UInt8)

	conn_flags = read(sock, UInt8)
	username_flag = Bool((conn_flags >>> 7) & 0b1)
	password_flag = Bool((conn_flags >>> 6) & 0b1)
	will_retain = (conn_flags >>> 5) & 0b1
	will_qos = (conn_flags >>> 4) & 0b11
	will_flag = Bool((conn_flags >>> 2) & 0b1)
	clean_session = (conn_flags >>> 1) & 0b1
	reserved = (conn_flags >>> 0) & 0b1

	keep_alive = UInt16(read(sock, UInt8) * 256) + UInt16(read(sock, UInt8))

	payload = read!(sock, Array{UInt8, 1}(undef, payload_len))

	# Default payload field values
	client_id = nothing
	will_topic = nothing
	will_message = nothing
	username = nothing
	password = nothing

	# Get client id
	# Client ID MUST be between 1 and 23 bytes long
	position = 1
	id_length = payload[position] * 256 + payload[position+1]
	position = position + 2

	client_id = (id_length < 1 || id_length > 23) ? "" : String(payload[position:position+id_length-1])
	position = position + id_length

	# Get will fields if flag is set
	if will_flag
		will_topic_length = payload[position]*256 + payload[position + 1]
		position = position + 2
		will_topic = String(payload[position:position+will_topic_length-1])
		position = position + will_topic_length

		will_message_length = payload[position]*256 + payload[position + 1]
		position = position + 2
		will_message = payload[position:position+will_message_length-1]
		position = position + will_message_length
	end

	if username_flag
		username_length = payload[position]*256 + payload[position + 1]
		position = position + 2
		username = String(payload[position:position+username_length-1])
		position = position + username_length
	end

	if password_flag
		password_length = payload[position]*256 + payload[position + 1]
		position = position + 2
		password = payload[position:position+password_length-1]
		position = position + password_length
	end

	packet = CONNECTPacket(
						   protocol_level,
						   username_flag,
						   password_flag,
						   will_retain,
						   will_qos,
						   will_flag,
						   clean_session,
						   keep_alive,
						   client_id,
						   will_topic,
						   will_message,
						   username,
						   password
						   )

	return packet
end

function read_CONNACK(sock, flags, rem_len)
	session_present = Bool(read(sock, UInt8) & 0b1)
	return_code = read(socket, UInt8)

	return CONNACKPacket(session_present, return_code)
end

function read_PUBLISH(sock, flags, rem_len)
	# Parse flags
	dup_flag = Bool((flags >>> 3) & 0b1)
	qos = (flags >>> 1) & 0b11
	if qos == 3
		error("Invalid QOS of $qos")
	end
	retain = Bool(flags & 0b1)

	topic_length = read_var_length(sock)
	topic = String(read!(sock, Array{UInt8, 1}(undef, topic_length)))

	packet_id = qos > 0 ? read_var_length(sock) : nothing
	header_len = qos > 0 ? 7 : 5
	payload_len = rem_len - header_len
	payload = payload_len > 0 ? read!(sock, Array{UInt8, 1}(undef, payload_len)) : []

	packet = PUBLISHPacket(
						   dup_flag,
						   qos,
						   retain,
						   topic,
						   packet_id,
							payload
						   )

	return packet
end

function read_PUBACK(sock, flags, rem_len)
	error("Not implemented")
end

function read_PUBREC(sock, flags, rem_len)
	error("Not implemented")
end

function read_PUBREL(sock, flags, rem_len)
	id = read_var_length(sock)

	return PUBRELPacket(id)
end

function read_PUBCOMP(sock, flags, rem_len)
	error("Not implemented")
end

function read_SUBSCRIBE(sock, flags, rem_len)
	packet_id = read_var_length(sock)	
	payload_len = rem_len - 2
	println("packet_id: $packet_id")
	println("payload_len: $payload_len")

	#payload = read!(sock, Array{UInt8, 1}(undef, payload_len))

	read_amount = 0

	topics::Vector{TopicRequest} = []
	while read_amount < payload_len
		t_length = read(sock, UInt8)*256 + read(sock, UInt8)
		read_amount = read_amount + 2
		println("topic length: $t_length")

		topic = String(read!(sock, Array{UInt8, 1}(undef, t_length)))
		read_amount = read_amount + t_length


		qos = read(sock, UInt8)
		read_amount = read_amount + 1

		println("QOS: $qos")


		push!(topics, TopicRequest(topic, qos))
	end

	return SUBSCRIBEPacket(packet_id, topics)
end


# Reads the two byte length for a given variable field length from a socket
function read_var_length(sock)
	return UInt16(read(sock, UInt8) * 256) + UInt16(read(sock, UInt8))
end

PACKET_FUNCTIONS = [
					read_CONNECT,
					read_CONNACK,
					read_PUBLISH,
					read_PUBACK,
					read_PUBREC,
					read_PUBREL,
					read_PUBCOMP,
					read_SUBSCRIBE
				   	]

function read_packet(sock)
	first = read(sock, UInt8)

	control = (first >>> 4) & 0b00001111
	flags = (first & 0b00001111)
	println("Control $control")

	# Read remaining length
	rem_len = read_remaining_length(sock)
	println("Remaining length: $rem_len")

	packet = PACKET_FUNCTIONS[control](sock, flags, rem_len)
	return packet
end

function write_packet(sock, packet)
	write(sock, serialize_packet(packet))
end

function serialize_packet(packet::CONNACKPacket)
	out::Array{UInt8, 1} = [0b00100000,
							0b00000010,
							UInt8(packet.session_present),
							packet.return_code
							]

	return out
end

function serialize_rem_len(len::Int)
	out::Array{UInt8} = []
	while len > 0
		byte = len % 128
		len = UInt(trunc(len / 128))
		if len > 0
			byte = byte | 128
		end

		append!(out, byte)
	end
	return out
end

function serialize_packet(packet::PUBACKPacket)
	msb = trunc(UInt8, packet.packet_id / 256)
	lsb = packet.packet_id % 256

	out::Array{UInt8} = [0b01000000, 2, msb, lsb]
	return out
end

function serialize_packet(packet::PUBRECPacket)
	msb = trunc(UInt8, packet.packet_id / 256)
	lsb = packet.packet_id % 256

	out::Array{UInt8} = [0b01010000, 2, msb, lsb]
	return out
end

function serialize_packet(packet::PUBRELPacket)
	msb = trunc(UInt8, packet.packet_id / 256)
	lsb = packet.packet_id % 256

	out::Array{UInt8} = [0b01100010, 2, msb, lsb]
	return out
end

function serialize_packet(packet::PUBCOMPPacket)
	msb = trunc(UInt8, packet.packet_id / 256)
	lsb = packet.packet_id % 256

	out::Array{UInt8} = [0b01110000, 2, msb, lsb]
	return out
end

function serialize_packet(packet::SUBACKPacket)
	msb = trunc(UInt8, packet.packet_id / 256)
	lsb = packet.packet_id % 256

	println("LENGTH: $(packet.return_codes)")
	rem_len = serialize_rem_len(length(packet.return_codes)+2)
	println(rem_len)

	out::Array{UInt8, 1} = vcat([0b10010000], rem_len, [msb, lsb], packet.return_codes)
	println(out)

	return out
end


end
