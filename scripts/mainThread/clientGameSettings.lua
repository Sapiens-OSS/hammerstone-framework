local mod = {
    loadOrder = 0
}

function mod:onload(clientGameSettings)
    
    clientGameSettings.values["renderLog"] = true
	
end

return mod