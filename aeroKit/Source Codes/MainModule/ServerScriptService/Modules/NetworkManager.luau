-- Network Manager Module
-- by SKYtech

local NetworkManager = {}

function NetworkManager.GetNetworkOwner(rootAssembly : BasePart)
	return if not rootAssembly:IsGrounded() and rootAssembly:IsDescendantOf(workspace) then rootAssembly:GetNetworkOwner() else nil
end

function NetworkManager.SetNetworkOwner(player : Player, rootAssembly : BasePart, assembly)
	if assembly then
		assembly:SetAttribute("NetworkOwner", if player then player.UserId else nil)
	end
	
	if not rootAssembly:IsGrounded() and rootAssembly:IsDescendantOf(workspace) then
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
	if not rootAssembly:IsGrounded() and rootAssembly:IsDescendantOf(workspace) then
		local networkOwner = rootAssembly:GetNetworkOwner()
		
		if canResetNetwork then
			if player and isClientControlled then
				if networkOwner ~= player then
					networkOwner = player
					rootAssembly:SetNetworkOwner(player)
				end
			elseif networkOwner ~= nil then
				networkOwner = nil
				rootAssembly:SetNetworkOwner(nil)
			end
		end
		
		if assembly then
			assembly:SetAttribute("NetworkOwner", if networkOwner then networkOwner.UserId else nil)
		end
	end
end

return NetworkManager