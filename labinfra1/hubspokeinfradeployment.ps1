param(
[Switch]$DeleteConfig
)

#Global Variables
$ResourceGroup = "lab-resource-group-1"
$Location = "australiaeast"

#Global Arrays
#Global Arrays for networks
$ArrayofVnets = @("vnet0-hubgw","vnet0-spoke-infra02","vnet0-spoke-infra03")
$ArrayofSubnetNames = @("subnetconfig-hubgw","subnetconfig-spoke-infra01","subnetconfig-spoke-infra02")
$ArrayofSubnetPrefixes = @("10.0.1.0/24","10.10.0.0/24","10.20.0.0/24")
$ArrayofVnetPrefixes = @("10.0.0.0/16","10.10.0.0/16","10.20.0.0/16")

#Global Arrays for VMs
$ArrayofVMNames = @("LABJUMPBOX","LABLINUX01","LABLINUX02")
$ArrayofNIC = @("int0-LABJUMPBOX","int0-LABLINUX01","int0-LABLINUX02")
$ArrayofVMDiskNames = @("osdisk-LABJUMPBOX","osdisk-LABLINUX02","osdisk-LABLINUX03")

function Delete-Config
{ 
  $i = 0

  #Delete VMs and their interfaces
  foreach($VM in $ArrayofVMNames)
  {
    Stop-AZVM -Name $VM -Force -SkipShutdown -ResourceGroupName $ResourceGroup
    Remove-AzVM -Name $VM -Force -ResourceGroupName $ResourceGroup
    Remove-AzNetworkInterface -Name $ArrayofNIC[$i] -ResourceGroupName $ResourceGroup -Force
    Remove-AzDisk -Name $ArrayofVMDiskNames[$i] -ResourceGroupName $ResourceGroup -Force

    $i++

  }

  #Remove Public IP addresses
  Remove-AzPublicIpAddress -Name "pip-labjumpbox" -ResourceGroupName $ResourceGroup -Force

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
  $NSGInfraLab = Get-AzNetworkSecurityGroup -Name "nsg-infralabs"
  Remove-AzNetworkSecurityRuleConfig -Name "AllowPingInbound" -NetworkSecurityGroup $NSGInfraLab
  Remove-AzNetworkSecurityRuleConfig -Name "AllowSSHInbound" -NetworkSecurityGroup $NSGInfraLab
  Remove-AzNetworkSecurityGroup -Name "nsg-infralabs" -ResourceGroupName $ResourceGroup -Force

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
$NSGInfraLabSSHConfig = New-AzNetworkSecurityRuleConfig -Name "AllowSSHInbound" `
-Protocol Tcp `
-Priority 1000 `
-SourcePortRange * -SourceAddressPrefix * `
-DestinationPortRange 22 -DestinationAddressPrefix * `
-Access Allow -Direction "Inbound"

$NSGInfraLabICMPConfig = New-AzNetworkSecurityRuleConfig -Name "AllowPingInbound" `
-Protocol Icmp `
-Priority 1001 `
-SourcePortRange * -SourceAddressPrefix * `
-DestinationPortRange * -DestinationAddressPrefix * `
-Access Allow -Direction "Inbound"

#Security Group from SC profiles above
$NSGInfraLab = New-AzNetworkSecurityGroup -Name "nsg-infralabs" `
-ResourceGroupName $ResourceGroup `
-Location $Location `
-SecurityRules $NSGInfraLabSSHConfig,$NSGInfraLabICMPConfig

#Configure Vnets
$i = 0

foreach($VnetName in $ArrayofVnets)
{
  $SubnetConfigProfile = New-AzVirtualNetworkSubnetConfig -Name $ArrayofSubnetNames[$i] `
  -AddressPrefix $ArrayofSubnetPrefixes[$i] `
  -NetworkSecurityGroupId $NSGInfraLab.Id

  $Vnet = New-AzVirtualNetwork -Name $VnetName `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -AddressPrefix $ArrayofVnetPrefixes[$i] `
  -Subnet $SubnetConfigProfile

  $i++

}

#VM Config Profile

$i = 0

#VM Info
$Publisher = "Canonical"
$Offer = "UbuntuServer"
$SKU = "19.04"

#Create array of subnet ids from vnet
$ArrayOfSubnetIDfromVnet = @(((Get-AzVirtualNetwork).Subnets | Where { $_.ID -Like "*vnet0*" }).id)
$VMUserAccountCreds = Get-Credential

foreach($VM in $ArrayofVMNames)
{
  #Create VM NIC interface
  $VnetInterface = New-AzNetworkInterface -Name $ArrayofNIC[$i] `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -SubnetId $ArrayOfSubnetIDfromVnet[$i]
  
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

#Create Public IP address for LABJUMPBOX01 and Modify LABJUMPBOX VM NIC to obtain Public IP
$PublicIPAddy = New-AzPublicIpAddress -Name "pip-labjumpbox" -ResourceGroupName $ResourceGroup -Location $Location -SKU Basic -Tier Regional -AllocationMethod Static

${$ArrayofVnets[0]} = Get-AzVirtualNetwork -Name $ArrayofVnets[0] -ResourceGroupName $ResourceGroup
${$ArrayofSubnetNames[0]} = Get-AzVirtualNetworkSubnetConfig -Name $ArrayofSubnetNames[0] -VirtualNetwork ${$ArrayofVnets[0]}
$ipconfignamefornic = (Get-AzNetworkInterface -Name $ArrayofNIC[0] -ResourceGroupName $ResourceGroup).IpConfigurations.Name
${$ArrayofNIC[0]} = Get-AzNetworkInterface -Name $ArrayofNIC[0] -ResourceGroupName $ResourceGroup
${$ArrayofNIC[0]} | Set-AzNetworkInterfaceIpConfig -Name $ipconfignamefornic -PublicIpAddressId $PublicIPAddy.Id -SubnetId $ArrayOfSubnetIDfromVnet[0]
${$ArrayofNIC[0]} | Set-AzNetworkInterface