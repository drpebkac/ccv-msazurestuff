$ResourceGroup = "lab-resource-group-1"
$Location = "australiaeast"

$PublicIPAddy = New-AzPublicIpAddress -Name "pip-vgw" -ResourceGroupName $ResourceGroup -Location $Location -SKU Basic -Tier Regional -AllocationMethod Dynamic


#Vnet and gateway subnet info
$Vnet = Get-AzVirtualNetwork -Name vnet0-hubgw
$subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet

$gwipconfig = New-AzVirtualNetworkGatewayIpConfig -Name "vgwipconfig1" -SubnetId $subnet.id -PublicIpAddressId $PublicIPAddy.Id

New-AzVirtualNetworkGateway -Name "vng-lab" `
-ResourceGroupName $ResourceGroup `
-Location $Location `
-VpnType "Routebased" `
-IpConfigurations $gwipconfig `
-GatewayType "Vpn" `
-GatewaySku "VpnGw1"