param(
[Switch]$DeleteConfig
)

#General Information variables
$ResourceGroup = "lab-resource-group-1"
$Location = "australiaeast"

function Delete-VM-Config
{
  Remove-AzVirtualNetwork -Name $VnetName vnet-gw01 -ResourceGroupName $ResourceGroup
  exit

}

if($DeleteConfig)
{
  Delete-VM-Config

}

#Create subnet object for Vnet vnet-gw01
$SubnetGW = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix 10.20.0.0/27 
#Create Vnet vnet-gw01 and assign subnet object $SubnetGW
$vnetgw01 = New-AzVirtualNetwork -Name "vnet-gw01" -ResourceGroupName $ResourceGroup -Location $Location -AddressPrefix 10.20.0.0/16 -Subnet $SubnetGW 

#Create subnet object for Vnet vnet-gw01
$SubnetLab = New-AzVirtualNetworkSubnetConfig -Name "subnet-lab" -AddressPrefix 10.100.0.0/24
#Create Vnet vnet-gw01 and assign subnet object $SubnetGW
$vnetinfra01 = New-AzVirtualNetwork -Name "vnet-infra" -ResourceGroupName $ResourceGroup -Location $Location -AddressPrefix 10.100.0.0/16 -Subnet $SubnetLab

#Create virtual gateway on subnet-gw
#Requires public IP
$PublicIP = New-AzPublicIpAddress -Name publicip01 -ResourceGroupName $ResourceGroup -Location australiaeast -Sku Basic -Tier Regional -AllocationMethod Static
$NGWconfig = New-AzVirtualNetworkGatewayIpConfig -Name NGWIPConfig -SubnetId $SubnetGW.id -PublicIpAddressId $PublicIP.id
New-AzVirtualNetworkGateway -Name "ngw-lab01" -ResourceGroupName $ResourceGroup -Location australiaeast -IpConfigurations $NGWconfig -GatewayType Vpn -VpnType PolicyBased -GatewaySku Basic


#Peer Vnets between vnet-gw01 and vnet-infra
Add-AzVirtualNetworkPeering -Name "vnetpeering-vnet-gw01-vnet-infra" -VirtualNetwork $vnetgw01 -RemoteVirtualNetworkId $vnetinfra01.id -AllowForwardedTraffic -AllowGatewayTransit -UseRemoteGateways 
Add-AzVirtualNetworkPeering -Name "vnetpeering-vnet-vnet-infra-gw01" -VirtualNetwork $vnetinfra01 -RemoteVirtualNetworkId $vnetgw01.id -AllowForwardedTraffic -AllowGatewayTransit -UseRemoteGateways 

#Create Security group for subnet subnet-lab
#$NSGSSHINConfig = New-AzNetworkSecurityRuleConfig -Name "nsg-sshin-config" -Protocol tcp -SourcePortRange * -DestinationPortRange * -SourceAddressPrefix  -DestinationAddressPrefix
#$NSGSSHIN = New-AzNetworkSecurityGroup -Name "nsg-sshin" -ResourceGroupName $ResourceGroup -Location australiaeast -SecurityRules 