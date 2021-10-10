param(
[Switch]$NoPublicIP,
[Switch]$DeleteConfig
)

#General Information variables
#Global info
$ResourceGroup = "lab-resource-group-1"
$Location = "australiaeast"

#Global Arrays for networks
$ArrayofVnets = @("vnet-infra01","vnet-infra02","vnet-infra03")
$ArrayofSubnetNames = @("subnet-VnetInfra01","subnet-VnetInfra02","subnet-VnetInfra03")
$ArrayofSubnetPrefixes = @("10.110.0.0/24","10.120.0.0/24","10.130.0.0/24")
$ArrayofVnetPrefixes = @("10.110.0.0/16","10.120.0.0/16","10.130.0.0/16")

#Global Arrays for VMs
$ArrayofVMNames = @("LABLINUX01","LABLINUX02","LABLINUX03")
$ArrayofNIC = @("int0-LABLINUX01","int0-LABLINUX02","int0-LABLINUX03")
$ArrayofVMDiskNames = @("osdisk-LABLINUX01","osdisk-LABLINUX02","osdisk-LABLINUX03")

function Delete-Config
{ 
  $i = 0

  #Delete VMs, their interfaces and their cooresponding Public IP Addresses
  foreach($VM in $ArrayofVMNames)
  {
    $PubIPName = "publicipadd-lab" + $i
    Stop-AZVM -Name $VM -Force -SkipShutdown -ResourceGroupName $ResourceGroup 
    Remove-AzVM -Name $VM -Force -ResourceGroupName $ResourceGroup
    Remove-AzNetworkInterface -Name $ArrayofNIC[$i] -ResourceGroupName $ResourceGroup -Force
    Remove-AzDisk -ResourceGroupName $ResourceGroup -Name $ArrayofVMDiskNames[$i] -Force
    
    try
    {
      Remove-AzPublicIpAddress -Name $PubIPName -ResourceGroupName $ResourceGroup -Force

    }
    catch [Exception]
    {
      Write-Output "No Public IP address for $VM"

    }

    $i++

  }

  $x = 0

  #Using global arrays and loops to remove all subnets
  foreach($VNetName in $ArrayofVnets)
  {
    
    $VnetToDelete = Get-AZVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroup
    Remove-AzVirtualNetworkSubnetConfig -Name $ArrayofSubnetNames[$x] -VirtualNetwork $VnetToDelete

    #Don't ask why or how piping is needed but apparently it's needed for the subnets to actually be deleted properly
    $VnetToDelete | Set-AzVirtualNetwork

    $x++

  }

  #Remove security group NSG-InfraLabVnets for ping and ssh
  $NSGInfraLab = Get-AzNetworkSecurityGroup -Name "NSG-InfraLabVnets"
  Remove-AzNetworkSecurityRuleConfig -Name "AllowSSH" -NetworkSecurityGroup $NSGInfraLab 
  Remove-AzNetworkSecurityRuleConfig -Name "AllowPing" -NetworkSecurityGroup $NSGInfraLab 
  Remove-AzNetworkSecurityGroup -Name "NSG-InfraLabVnets" -ResourceGroupName $ResourceGroup -Force

  foreach($VNetName in $ArrayofVnets)
  {
    #Delete Vnet last since its associated with the above
    Remove-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroup -Force

  }

  #Sayonara
  exit

}

if($DeleteConfig)
{
  Delete-Config

}

#Create security group for ssh and ping. To be assigned to subnet later
#Security Group profile
$NSGInfraLabSSHConfig = New-AzNetworkSecurityRuleConfig -Name "AllowSSH" -Protocol Tcp -Priority 1000 `
-SourcePortRange * -SourceAddressPrefix * `
-DestinationPortRange 22 -DestinationAddressPrefix * `
-Access Allow -Direction Inbound

$NSGInfraLabICMPConfig = New-AzNetworkSecurityRuleConfig -Name "AllowPing" -Protocol Icmp -Priority 1001 `
-SourcePortRange * -SourceAddressPrefix * `
-DestinationPortRange * -DestinationAddressPrefix * `
-Access Allow -Direction Inbound

#Security Group
$NSGInfraLab = New-AzNetworkSecurityGroup -Name "NSG-InfraLabVnets" -ResourceGroupName $ResourceGroup -Location $Location `
-SecurityRules $NSGInfraLabSSHConfig,$NSGInfraLabICMPConfig

#Incremental variable for parsing through the global arrays (This only works because all the global arrays have the same amount of objects in it)
$x = 0

#Create Vnets with
foreach($VNetName in $ArrayofVnets)
{
  ${$ArrayofSubnetNames[$x]} = New-AzVirtualNetworkSubnetConfig -Name $ArrayofSubnetNames[$x] `
  -AddressPrefix $ArrayofSubnetPrefixes[$x] `
  -NetworkSecurityGroupId $NSGInfraLab.Id

  ${$VNetName} = New-AzVirtualNetwork -Name $VNetName `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -AddressPrefix $ArrayofVnetPrefixes[$x] `
  -Subnet ${$ArrayofSubnetNames[$x]} `
  
  $x++

}

  
#VM Config Profile

$i = 0

#VM Info
$Publisher = "Canonical"
$Offer = "UbuntuServer"
$SKU = "19.04"

$ArrayOfSubnetIDfromVnet = @(((Get-AzVirtualNetwork).Subnets | Where { $_.ID -Like "*VNET-INFRA*" }).id)
$VMUserAccountCreds = Get-Credential

foreach($VM in $ArrayofVMNames)
{
  #Create new Network interface and public IP for VM if defined
  if($NoPublicIP -eq $true)
  {
    $VnetInterface = New-AzNetworkInterface -Name $ArrayofNIC[$i] -ResourceGroupName $ResourceGroup -Location $Location -SubnetId $ArrayOfSubnetIDfromVnet[$i]
  
  }
  else
  {
    $PubIPName = "publicipadd-lab" + $i
    $PublicIPAddy = New-AzPublicIpAddress -Name $PubIPName -ResourceGroupName $ResourceGroup -Location $Location -SKU Basic -Tier Regional -AllocationMethod Static
    $VnetInterface = New-AzNetworkInterface -Name $ArrayofNIC[$i] -ResourceGroupName $ResourceGroup -Location $Location -SubnetId $ArrayOfSubnetIDfromVnet[$i] -PublicIpAddressId $PublicIPAddy.id

  }

  #Create VM
  $VMConfigProfile = New-AzVMConfig -VMName $VM -VMSize "Standard_B1ls"
  $VMOS = Set-AzVMOperatingSystem -VM $VMConfigProfile -Linux -ComputerName $VM -Credential $VMUserAccountCreds
  $VMImage = Set-AzVMSourceImage -VM $VMConfigProfile -PublisherName $Publisher -Offer $Offer -Skus $SKU -Version Latest 
  $VMDisk = Set-AzVMOSDisk -VM $VMConfigProfile -Name $ArrayofVMDiskNames[$i] -Linux -DiskSizeInGB 30 -Caching ReadWrite -CreateOption FromImage -StorageAccountType Standard_LRS
  $VMNetworkInterface = Add-AzVMNetworkInterface -VM $VMConfigProfile -Id $VnetInterface.Id

  #Create VM from profile
  New-AZVM -VM $VMConfigProfile -ResourceGroupName $ResourceGroup -Location $Location

  $i++

}

#Create Peering network
#Adding this last since peering can't be created if vnets are not ready
#I got too lazy to put these into an array so its gonna be linear for now
$VnetSource = Get-AzVirtualNetwork -Name vnet-gw01
$VnetRemote = Get-AzVirtualNetwork -Name vnet-infra01
Add-AzVirtualNetworkPeering -Name vpeering-vnet-gw01-vnet-infra01 -VirtualNetwork $VNetSource -RemoteVirtualNetworkId $VNetRemote.Id -AllowForwardedTraffic -AllowGatewayTransit
Add-AzVirtualNetworkPeering -Name vpeering-vnet-infra01-vnet-gw01 -VirtualNetwork $VNetRemote -RemoteVirtualNetworkId $VNetSource.Id -AllowForwardedTraffic -UseRemoteGateways

$VnetSource = Get-AzVirtualNetwork -Name vnet-infra01
$VnetRemote = Get-AzVirtualNetwork -Name vnet-infra02
Add-AzVirtualNetworkPeering -Name vpeering-vnet-infra01-vnet-infra02 -VirtualNetwork $VNetSource -RemoteVirtualNetworkId $VnetRemote.Id -AllowForwardedTraffic
Add-AzVirtualNetworkPeering -Name vpeering-vnet-infra02-vnet-infra01 -VirtualNetwork $VnetRemote -RemoteVirtualNetworkId $VnetSource.Id -AllowForwardedTraffic

$VnetSource = Get-AzVirtualNetwork -Name vnet-infra02
$VnetRemote = Get-AzVirtualNetwork -Name vnet-infra03
Add-AzVirtualNetworkPeering -Name vpeering-vnet-infra02-vnet-infra03 -VirtualNetwork $VNetSource -RemoteVirtualNetworkId $VnetRemote.Id -AllowForwardedTraffic
Add-AzVirtualNetworkPeering -Name vpeering-vnet-infra03-vnet-infra02 -VirtualNetwork $VnetRemote -RemoteVirtualNetworkId $VnetSource.Id -AllowForwardedTraffic