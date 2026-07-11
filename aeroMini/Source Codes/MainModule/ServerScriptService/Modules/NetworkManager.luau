local NetworkManager = {}

function NetworkManager.GetNetworkOwner(rootAssembly : BasePart)
	local isGrounded = rootAssembly:IsGrounded()
	local inWorkspace = rootAssembly:IsDescendantOf(workspace)
	
	if isGrounded or not inWorkspace then
		return nil
	else
		return rootAssembly:GetNetworkOwner()
	end
end

function NetworkManager.SetNetworkOwner(
	player : Player,
	rootAssembly : BasePart,
	assembly
)
	if assembly then
		-- Set the network owner attribute if the assembly is found in case of it being anchored.
		assembly:SetAttribute("NetworkOwner", if player then player.UserId else nil)
	end
	
	local isGrounded = rootAssembly:IsGrounded()
	local inWorkspace = rootAssembly:IsDescendantOf(workspace)
	
	if not isGrounded and inWorkspace then
		-- Only change if the the assembly is unanchored and in workspace.
		rootAssembly:SetNetworkOwner(player)
	end
end

function NetworkManager.UpdateNetworkOwner(
	player : Player,
	rootAssembly : BasePart,
	assembly, 
	isClientControlled : boolean,
	canResetNetwork : boolean
)	
	-- Update network owner based on the current player found.
	local isGrounded = rootAssembly:IsGrounded()
	local inWorkspace = rootAssembly:IsDescendantOf(workspace)
	
	if not isGrounded and inWorkspace then
		local networkOwner = rootAssembly:GetNetworkOwner()
		
		if canResetNetwork then
			if player and isClientControlled then
				-- Force ownership to the player if they don't already have it
				if networkOwner ~= player then
					networkOwner = player
					rootAssembly:SetNetworkOwner(player)
				end
			elseif networkOwner ~= nil then
				-- Strip ownership back to the server if no player or client control is disabled
				networkOwner = nil
				rootAssembly:SetNetworkOwner(nil)
			end
		end
		
		if assembly then
			-- Update network owner's id into the assembly attribute even if it's anchored.
			assembly:SetAttribute("NetworkOwner", if networkOwner then networkOwner.UserId else nil)
		end
	end
end

return NetworkManager