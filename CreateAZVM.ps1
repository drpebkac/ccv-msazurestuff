$LinuxAZVM = New-AzVMConfig -VMName "CCVAZVMLI01" -VMSize "Standard_B1S"
Set-AzVMOperatingSystem -VM $LinuxAZVM -Linux -ComputerName "CCVAZVMLI01" -Credential $Creds
Set-AzVMSourceImage -VM $LinuxAZVM -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "19.04" -Version "Latest"
Set-AzVMOSDisk -VM $LinuxAZVM -Linux -DiskSizeInGB 30 -CreateOption FromImage -Caching ReadWrite
Add-AzVMNetworkInterface -VM $LinuxAZVM -Id "/subscriptions/8681398b-3eff-4f81-9ec9-07e0c5f4745c/resourceGroups/GRP-AZ-TST/providers/Microsoft.Network/networkInterfaces/int0"

