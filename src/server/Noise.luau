-- Tiny pub/sub for sounds the monsters can hear.
local Noise = {}
local listeners = {}

function Noise.subscribe(fn)
	table.insert(listeners, fn)
	return function()
		local i = table.find(listeners, fn)
		if i then
			table.remove(listeners, i)
		end
	end
end

function Noise.emit(position: Vector3, radius: number, source)
	for _, fn in listeners do
		task.spawn(fn, position, radius, source)
	end
end

return Noise
