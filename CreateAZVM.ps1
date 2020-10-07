$WindowsAZVM = New-AzVMConfig -VMName CCVAZVMWI01 -VMSize Standard_B2S
Set-AzVMOperatingSystem -VM $WindowsAZVM -Windows -ComputerName CCVAZVMWI01 -Credential $Creds -TimeZone "AUS Eastern Standard Time"
Set-AzVMSourceImage -VM $WindowsAZVM -PublisherName MicrosoftWindowsDesktop -Offer "Windows-10" -Skus "19h2-pro" -Version "Latest"
Set-AzVMOSDisk -VM $WindowsAZVM -Windows -DiskSizeInGB 127 -CreateOption FromImage -Caching ReadWrite
Add-AzVMNetworkInterface -VM $WindowsAZVM -Id "/subscriptions/8681398b-3eff-4f81-9ec9-07e0c5f4745c/resourceGroups/CCV-GROUP-ITINFRA-TST01/providers/Microsoft.Network/virtualNetworks/Int0"

