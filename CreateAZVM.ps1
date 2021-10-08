param(
[switch]$CreatePublicIPAddress,
[Switch]$DeleteConfig
)

#General Information variables
$ResourceGroup = "lab-resource-group-1"
$Location = "australiaeast"
$Vnet = Get-AzVirtualNetwork -Name vnet-lab01

function Delete-VM-Config
{
  $SecurityGroupToDelete = Get-AzNetworkSecurityGroup -Name SecurityGroup-Lablinux01
  
  Remove-AzVM -Name "LABLINUX01" -Force -ResourceGroupName $ResourceGroup -ErrorAction Ignore
  Remove-AzNetworkInterface -Name "int0lablinux01" -ResourceGroupName $ResourceGroup -ErrorAction Ignore
  Remove-AzNetworkSecurityRuleConfig -Name "SecurityRule-SSH-Inbound" -NetworkSecurityGroup $SecurityGroupToDelete -ErrorAction Ignore
  Remove-AzNetworkSecurityGroup -Name "SecurityGroup-Lablinux01" -ResourceGroupName $ResourceGroup -ErrorAction Ignore
  Remove-AzDisk -ResourceGroupName $ResourceGroup -Name "DiskOSLabLinux"
  Remove-AzPublicIpAddress -Name "publicipadd-lablinux01" -ResourceGroupName $ResourceGroup -ErrorAction Ignore
  exit

}

if($DeleteConfig)
{
  Delete-VM-Config

}

#Source image variables
$Publisher = "Canonical"
$Offer = "UbuntuServer"
$SKU = "19.04"

#SSH Security groups
#Security Group profile
$LabLinux01SecurityGroupConfig = New-AzNetworkSecurityRuleConfig -Name SecurityRule-SSH-Inbound -Protocol Tcp -Priority 1000 `
-SourcePortRange * -SourceAddressPrefix * `
-DestinationPortRange 22 -DestinationAddressPrefix * `
-Access Allow -Direction Inbound

#Security Group
$LabLinux01SecurityGroup = New-AzNetworkSecurityGroup -Name SecurityGroup-Lablinux01 -ResourceGroupName $ResourceGroup -Location $Location `
-SecurityRules $LabLinux01SecurityGroupConfig

if($CreatePublicIPAddress)
{
  #Create public IP Address for accessing the VM.
  $PublicIPAddy = New-AzPublicIpAddress -Name publicipadd-lablinux01 -ResourceGroupName $ResourceGroup -Location $Location -SKU Basic -Tier Regional -AllocationMethod Static

  #Create new Network interface for VM
  $VnetInterface = New-AzNetworkInterface -Name int0lablinux01 -ResourceGroupName $ResourceGroup -Location $Location -PublicIpAddressId $PublicIPAddy.Id `
  -NetworkSecurityGroupId $LabLinux01SecurityGroup.id -SubnetId $Vnet.Subnets[0].Id #Or just get the ResourceID of the Subnet from azure web portal
  ls
}
elseif(!$CreatePublicIPAddress)
{
  #Create new Network interface for VM
  $VnetInterface = New-AzNetworkInterface -Name int0lablinux01 -ResourceGroupName $ResourceGroup -Location $Location `
  -NetworkSecurityGroupId $LabLinux01SecurityGroup.id -SubnetId $Vnet.Subnets[0].Id #Or just get the ResourceID of the Subnet from azure web portal

}

#VM Config Profile
$VMUserAccountCreds = Get-Credential
$VMConfigProfile = New-AzVMConfig -VMName "LABLINUX01" -VMSize "Standard_B1ls"
$VMOS = Set-AzVMOperatingSystem -VM $VMConfigProfile -Linux -ComputerName "LABLINUX01" -Credential $VMUserAccountCreds
$VMImage = Set-AzVMSourceImage -VM $VMConfigProfile -PublisherName $Publisher -Offer $Offer -Skus $SKU -Version Latest 
$VMDisk = Set-AzVMOSDisk -VM $VMConfigProfile -Name "DiskOSLabLinux" -Linux -DiskSizeInGB 30 -Caching ReadWrite -CreateOption FromImage -StorageAccountType Standard_LRS
$VMNetworkInterface = Add-AzVMNetworkInterface -VM $VMConfigProfile -Id $VnetInterface.Id #Or just get the ID of the Interface from azure web portal


#Create VM from profile
New-AZVM -VM $VMConfigProfile -ResourceGroupName $ResourceGroup -Location $Location