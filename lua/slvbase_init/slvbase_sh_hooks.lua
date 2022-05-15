hook.Add("ShouldCollide", "HLR_ShouldCollide", function(entA, entB)
	return entA:CanCollide(entB)
end)
