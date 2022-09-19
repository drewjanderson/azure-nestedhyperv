# Format data disk
Get-Disk | Where-Object PartitionStyle -Eq "RAW" | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume

# Install Hyper-V GUI and PowerShell module
Install-WindowsFeature -Name Hyper-V-Tools
Install-WindowsFeature -Name Hyper-V-PowerShell

# Set network adapter policy to Private
$NetProfile = Get-NetConnectionProfile -InterfaceAlias Ethernet
$NetProfile.NetworkCategory = "Private"
Set-NetConnectionProfile -InputObject $NetProfile

# Enable Network Discovery and File & Printer Sharing
netsh advfirewall firewall set rule group=”Network Discovery” new enable=Yes
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

# Import Hyper-V PowerShell Module
Import-Module Hyper-V

# Create Internal switch for VMs
# New-VMSwitch -Name "InternalSwitchNAT" -SwitchType Internal

# Configure InternalSwitchNAT network
# $switchifindex = Get-NetAdapter -Name "vEthernet (InternalSwitchNat)"
$switchifindex = Get-NetAdapter -Name "vEthernet (nat)"
New-NetIPAddress -IPAddress 192.168.217.1 -PrefixLength 24 -InterfaceIndex $switchifindex.ifIndex
New-NetNat -Name "InternalNATnet" -InternalIPInterfaceAddressPrefix 192.168.217.0/24

# Configure firewall to allow InternalNATnet to connect to the internet
New-NetFirewallRule -RemoteAddress 192.168.217.0/24 -DisplayName "Allow217net" -Profile Any -Action Allow