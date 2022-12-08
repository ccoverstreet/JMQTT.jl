

struct Fields
	packet_id::Union{UInt8, Nothing}
end

x = Fields(nothing)
println(x)
println(something(x.packet_id, 1))
