# Nested Hyper-V on Azure with Terraform

This is a practical project to apply the knowledge I have gained from going through a Terraform training course. The intent is to build out a nested Hyper-V host on an Azure VM that allows you to build customized VM images for systems installed from an ISO image vs. an existing Azure Marketplace image.

## Virtual Machine Guest Configuration

Configure all guest NICs on the 192.168.217.0/24 network starting at 192.168.217.2 like the following example:

* IP Address: 192.168.217.2
* Subnet Mask: 255.255.255.0
* Default gateway: 192.168.217.1
* Primary DNS: 8.8.8.8
* Secondary DNS: 1.1.1.1
