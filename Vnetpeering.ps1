param(
[string]$PeeringName,
[string]$SourceVnet,
[string]$RemoteVnet,
[switch]$AllowGatewayTransit,
[switch]$RemoteGateway,
[switch]$ListVnets
)

if($ListVnets -eq $True)
{
  Get-AZVirtualNetwork | Select Name,ResourceGroupName
  exit

}

if($SourceVnet -and $RemoteVnet -and $PeeringName)
{
  $VNetSource = Get-AzVirtualNetwork -Name $SourceVnet
  $VNetRemote = Get-AzVirtualNetwork -Name $RemoteVnet

  if($RemoteGateway -and $AllowGatewayTransit)
  {
    Write-Output "Cannot use both parameters -RemoteGateway and -AllowGatewayTransit. Choose one only."
    exit

  }
  elseif($AllowGatewayTransit)
  {
    Add-AzVirtualNetworkPeering -Name $PeeringName `
    -VirtualNetwork $VNetSource `
    -RemoteVirtualNetworkId $VNetRemote.id `
    -AllowForwardedTraffic `
    -AllowGatewayTransit

  }
  elseif($RemoteGateway)
  {
    Add-AzVirtualNetworkPeering -Name $PeeringName `
    -VirtualNetwork $VNetSource `
    -RemoteVirtualNetworkId $VNetRemote.id `
    -AllowForwardedTraffic `
    -UseRemoteGateways

  }
  else
  {
    Add-AzVirtualNetworkPeering -Name $PeeringName `
    -VirtualNetwork $VNetSource `
    -RemoteVirtualNetworkId $VNetRemote.id `
    -AllowForwardedTraffic `
    
  }

}
else
{
  Write-Output "Parameters -PeeringName, -SourceVnet and -RemoteVnet must be defined"
  exit

}

