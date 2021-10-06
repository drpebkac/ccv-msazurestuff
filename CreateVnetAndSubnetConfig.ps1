param(
[switch]$DeleteConfig
)

#Prerequsites: Resource Group
#What this script creates and do:
# - VNET
# - Virtual Subnet
# - Assigns Virtual Subnet to VNET

#Global variables
$ResourceGroup = "lab-resource-group-1"

#If -DeleteConfig parameter is called, delete the vnet-lab01 vnet and its resources
function Delete-Network-Infra
{
  $VNet = Get-AZVirtualNetwork | Where { $_.Name -eq "vnet-lab01" }
  $CheckSubnetlabExist = Get-AzVirtualNetworkSubnetConfig -Name Networksubnet-lab -VirtualNetwork $VNet -ErrorAction Ignore

  if($CheckSubnetlabExist)
  {
    Remove-AzVirtualNetworkSubnetConfig -Name Networksubnet-lab -VirtualNetwork $VNet
     
  }

  Remove-AzVirtualNetwork -Name "vnet-lab01" -ResourceGroupName $ResourceGroup -Force -Confirm:$false

}

if($DeleteConfig -eq $true)
{
  Delete-Network-Infra
  exit

}
 
#Create new Virtual Network vnet-lab01 if it doesn't exist
$CheckVNetExist = Get-AZVirtualNetwork -Name vnet-lab01

#If exist, define vnet and run function to add subnet in vnet
if($CheckVNetExist)
{
  Write-Output "VNet Vnet-lab01 exists. Skipping Vnet creation"
  $Vnet = Get-AZVirtualNetwork | Where { $_.Name -eq "vnet-lab01" }
  $SubnetConfigInternal = Add-AzVirtualNetworkSubnetConfig -Name Networksubnet-lab -AddressPrefix 10.0.1.0/24 -VirtualNetwork $Vnet
  $SubnetConfigInternal | Set-AzVirtualNetwork

}
#If not exist, create vnet and create new subnet in vnet
elseif(!$CheckVNetExist)
{
  Write-Output "VNet Vnet-lab01 does not exists. Creating subnet and Vnet"
  $SubnetConfigInternal = New-AzVirtualNetworkSubnetConfig -Name Networksubnet-lab -AddressPrefix 10.0.1.0/24
  $VNet = New-AzVirtualNetwork -Name vnet-lab01 -ResourceGroupName $ResourceGroup -Location australiaeast -AddressPrefix 10.0.0.0/16 -Subnet $SubnetConfigInternal

}