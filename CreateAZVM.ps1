$WindowsAZVM = New-AzVMConfig -VMName CCVAZVMWI01 -VMSize Standard_B2S
Set-AzVMOperatingSystem -VM $WindowsAZVM -Windows -ComputerName CCVAZVMWI01 -Credential $Creds -TimeZone "AUS Eastern Standard Time"
Set-AzVMOSDisk -Windows -VM $WindowsAZVM -Name "OSDisk"
Set-AzVMSourceImage
Add-AzVMNetworkInterface