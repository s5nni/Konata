local Vararg = ...

if type(Vararg) ~= "string" then
    error("Expected string, got: " .. type(Vararg))
end

queue_on_teleport(Vararg)
