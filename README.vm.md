# Azure Terraform Complete Infrastructure Guide

### PART 1: REUSABLE CHECKLIST FOR ANY AZURE RESOURCE

#### **Essential Foundation Layer (ALWAYS needed)**

- [ ] **Resource Group** → Container for ALL resources (MANDATORY)
- [ ] **Provider configuration** → Azure authentication (MANDATORY)
- [ ] **Terraform backend** → State management (for production)

#### **Networking Layer (for VMs)**

- [ ] **VNet** → Virtual network for communication
- [ ] **Subnet** → Logical subdivision of VNet
- [ ] **Network Interface (NIC)** → Connection point for VM to subnet
- [ ] **Public IP** → Internet-accessible address (if needed externally)
- [ ] **Network Security Group (NSG)** → Firewall rules
- [ ] **NSG Association** → Link NSG to NIC (CRITICAL!)

#### **Compute Layer (VMs)**

- [ ] **Linux/Windows Virtual Machine** → The actual server
- [ ] **OS Disk configuration** → Storage for OS
- [ ] **SSH Key / Password** → Authentication method
- [ ] **Source Image Reference** → Which OS to install

#### **Operational Layer (Best Practices)**

- [ ] **Outputs** → Display important values after creation
- [ ] **Variables** → Parameterize the infrastructure
- [ ] **Tags** → Label resources for organization
- [ ] **Naming convention** → Consistent resource naming

---

## PART 2: COMPLETE AZURE INFRASTRUCTURE BREAKDOWN

### **TERRAFORM PROVIDER & AUTHENTICATION**

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}
```

**What is it ?** Tells Terraform how to connect to Azure.

**Why ?** Without this, Terraform cannot authenticate with Azure.

**Analogy:** It's the "key" to unlock Azure.

---

### **RESOURCE GROUP**

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "myTFResourceGroup"
  location = var.location  ## e.g., "West Europe"
}
```

**What is it ?** A container that groups ALL the Azure resources together.

**Why ?** **MANDATORY in Azure.** Every single resource must belong to a Resource Group. It's how Azure organizes billing, permissions, and lifecycle management.

**Key dependencies:** Everything depends on this. RG must be created first.

**Analogy:** It's the "land lot" where the entire infrastructure is built.

**File location:** `main.tf`

---

### **VIRTUAL NETWORK (VNet)**

```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]     ## Private IP range
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
```

**What is it ?** A private network isolated from the Internet (by default).

**Why ?** VMs need a network to communicate. This is the private network where all resources live.

**Key dependencies:** Depends on Resource Group.

**Analogy:** It's the "neighborhood" where everything lives.

**Address space:** `10.0.0.0/16` = 65,536 IP addresses available (10.0.0.0 - 10.0.255.255)

**File location:** `network.tf`

---

### **SUBNET**

```hcl
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]    ## Subdivision of VNet
}
```

**What is it ?** A logical subdivision of the VNet.

**Why ?** Organize resources into groups (prod vs dev, frontend vs backend, etc.). You might have multiple subnets in one VNet.

**Key dependencies:** Depends on VNet.

**Address prefixes:** `10.0.2.0/24` = 256 IP addresses (10.0.2.0 - 10.0.2.255)

**Analogy:** It's a "street" in the neighborhood.

**File location:** `network.tf`

---

### **PUBLIC IP ADDRESSES × 2**

```hcl
resource "azurerm_public_ip" "pip" {
  count               = var.vm_count        ## Creates 2 Public IPs
  name                = "pip-vm${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"            ## IP doesn't change
  sku                 = "Standard"           ## Required (not "Basic")
}
```

**What is it ?** An Internet-routable IP address. Makes the VM accessible from outside Azure.

**Why ?** Without this, only other Azure resources can reach the VM. You need Public IPs for:
- SSH from the laptop
- HTTP/HTTPS for WordPress
- Remote access

**Key dependencies:** Depends on Resource Group (but NOT on Subnet/VNet directly).

**Allocation method:**
- `Static` = IP stays the same (recommended)
- `Dynamic` = IP can change when VM stops/restarts

**SKU note:** Azure is phasing out "Basic" SKU. Always use "Standard".

**Analogy:** It's the "mailing address" visible from the street.

**File location:** `network.tf`

---

### **NETWORK INTERFACES (NICs) × 2**

```hcl
resource "azurerm_network_interface" "nic" {
  count               = var.vm_count        ## Creates 2 NICs
  name                = "vm-nic${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }
}
```

**What is it ?** The virtual "network card" for each VM.

**Why ?** Every VM needs an interface to connect to a subnet. This is where you:
1. Assign the private IP
2. Attach the public IP
3. Specify which subnet to use

**Key dependencies:** Depends on Subnet and Public IP.

**Private IP allocation:**
- `Dynamic` = Azure assigns any available IP from subnet range
- `Static` = You specify the exact IP

**Analogy:** It's the "Ethernet cable" connecting the server to the network.

**File location:** `network.tf`

---

### **NETWORK SECURITY GROUP (NSG) + RULES**

```hcl
resource "azurerm_network_security_group" "nsg" {
  name                = "vm-${var.environment}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ## Rule 1: Allow HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  ## Rule 2: Allow HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  ## Rule 3: Allow SSH
  security_rule {
    name                       = "AllowSSH"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}
```

**What is it ?** A firewall that controls which network traffic is allowed in/out.

**Why ?** Security. You must:
- ALLOW: Ports 80, 443, 22 (HTTP, HTTPS, SSH)
- DENY: Everything else (MySQL on 3306, databases on 5432, etc.)

**Key dependencies:** Depends on Resource Group.

**Priority:** Lower number = higher priority. (100 evaluated before 101)

**Rules breakdown:**
- Port 80 → WordPress HTTP access
- Port 443 → WordPress HTTPS/TLS access
- Port 22 → SSH for administration

**Analogy:** It's a "security guard at the gate" who checks every incoming/outgoing packet.

**File location:** `security.tf`

---

### **NSG ASSOCIATION TO NETWORK INTERFACES** ⭐️ **CRITICAL!**

```hcl
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
```

**What is it ?** Links the NSG to the NICs so the firewall rules are actually applied.

**Why ?** **CRITICAL!** An NSG without association does NOTHING. It's like having a security guard but not assigning him to the gate.

**Key dependencies:** Depends on NSG and Network Interface.

**Common mistake:** Creating an NSG but forgetting this association = firewall rules never applied.

**Analogy:** It's the "assignment order" telling the guard which gate to protect.

**File location:** `security.tf`

---

### **LINUX VIRTUAL MACHINE × 2**

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count        ## Creates 2 VMs
  name                = "vm-${var.environment}-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size         ## e.g., "Standard_D2als_v7"
  admin_username      = "adminuser"
  
  ## Attach Network Interface
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  ## SSH Authentication
  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.pub_key)
  }

  ## OS Storage Configuration
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"    ## Cheaper than Premium
  }

  ## Operating System Image
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy-daily"
    sku       = "22_04-daily-lts-gen2"       ## Ubuntu 22.04 Gen 2
    version   = "latest"
  }
}
```

**What is it ?** The actual virtual machine (Linux server).

**Why ?** This is where the application (WordPress) runs. This is the "real" resource you pay for.

**Key dependencies:** Depends on Network Interface.

**Size:** `Standard_D2als_v7`
- 2 vCPUs
- 8 GB RAM
- ~$60-80/month
- IMPORTANT: Must match OS image hypervisor generation (Gen 2 in this case)

**SSH Key:** 
- Public key authentication (more secure than passwords)
- `file(var.pub_key)` reads the SSH public key
- Must exist at `~/.ssh/id_rsa.pub` or custom path

**OS Disk:**
- `Standard_LRS` = Standard SSD (cheaper)
- `Premium_LRS` = Premium SSD (faster, more expensive)

**Hypervisor Generation:** 
- Image: `22_04-daily-lts-gen2` = Generation 2
- VM Size: `Standard_D2als_v7` = Generation 2 compatible
- **MUST MATCH** or you get compatibility errors

**Analogy:** It's the "computer" itself inside the house.

**File location:** `compute.tf`

---

### **VARIABLES**

```hcl
variable "location" {
  description = "Azure region where resources are deployed"
  type        = string
  default     = "West Europe"
}

variable "environment" {
  description = "Environment name (dev, prod, staging)"
  type        = string
  default     = "dev"
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Azure VM size (impacts cost and performance)"
  type        = string
  default     = "Standard_D2als_v7"
}

variable "pub_key" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
```

**What is it ?** Parameters you can change without editing code.

**Why ?** Reusability. Change variables instead of hardcoding values.

**Best practices:**
- Always provide descriptions
- Set sensible defaults
- Use `var.variable_name` throughout the configs
- Store sensitive values in `.tfvars` files (not in git)

**File location:** `variables.tf`

---

### **OUTPUTS**

```hcl
output "resource_group_name" {
  description = "Name of the created Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "vm_names" {
  description = "Names of created VMs"
  value       = azurerm_linux_virtual_machine.vm[*].name
}

output "vm_public_ips" {
  description = "Public IP addresses for SSH and HTTP/HTTPS access"
  value       = azurerm_public_ip.pip[*].ip_address
}

output "vm_private_ips" {
  description = "Private IP addresses (internal Azure network)"
  value       = azurerm_network_interface.nic[*].private_ip_address
}

output "nsg_id" {
  description = "ID of the Network Security Group"
  value       = azurerm_network_security_group.nsg.id
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.vnet.id
}

output "subnet_id" {
  description = "ID of the Subnet"
  value       = azurerm_subnet.subnet.id
}
```

**What is it ?** Values displayed after `terraform apply` completes.

**Why ?** You need to know:
- Which IPs to SSH into
- Which IPs to access WordPress on
- IDs for reference in other Terraform modules

**Usage:** After `terraform apply`, you'll see:
```
resource_group_name = "myTFResourceGroup"
vm_names = ["vm-dev-1", "vm-dev-2"]
vm_public_ips = ["20.160.158.48", "20.71.116.56"]
vm_private_ips = ["10.0.2.5", "10.0.2.4"]
...
```

**File location:** `outputs.tf`

---

## PART 3: HOW EVERYTHING FITS TOGETHER

### **Dependency Chain (Creation Order)**

```
1. Resource Group (FOUNDATION)
   └─ Everything depends on this
   
2. VNet (NETWORK FOUNDATION)
   └─ All networking depends on this
   
3. Subnet (NETWORK SUBDIVISION)
   └─ VMs connect here
   
4. Public IPs (INTERNET GATEWAY)
   └─ External access layer
   
5. Network Interface (VM CONNECTION POINT)
   └─ Links VM to Subnet + Public IP
   
6. Network Security Group (FIREWALL)
   └─ Controls traffic
   
7. NSG Association (FIREWALL ACTIVATION)
   ├─ Applies NSG to NICs
   │
8. Linux Virtual Machine (ACTUAL SERVER)
   └─ Finally, the VM itself
```

### **Visual Layout**

```
┌───────────────────────────────────────────────────────┐
│          Resource Group (Container)                   │
├───────────────────────────────────────────────────────┤
│                                                       │
│  ┌─────────────────────────────────────────────┐      │
│  │  VNet: 10.0.0.0/16 (Neighborhood)           │      │
│  │                                             │      │
│  │  ┌──────────────────────────────────────┐   │      │
│  │  │ Subnet: 10.0.2.0/24 (Street)         │   │      │
│  │  │                                      │   │      │
│  │  │  ┌──────────────┐  ┌──────────────┐  │   │      │
│  │  │  │ VM-1         │  │ VM-2         │  │   │      │
│  │  │  │ 10.0.2.5     │  │ 10.0.2.4     │  │   │      │
│  │  │  │              │  │              │  │   │      │
│  │  │  │ NIC-1        │  │ NIC-2        │  │   │      │
│  │  │  └──────────────┘  └──────────────┘  │   │      │
│  │  └──────────────────────────────────────┘   │      │
│  └─────────────────────────────────────────────┘      │
│                                                       │
│  Public IP-1: 20.160.158.48 ──→ NIC-1 ──→ VM-1        │
│  Public IP-2: 20.71.116.56   ──→ NIC-2 ──→ VM-2       │
│                                                       │
│  ┌─────────────────────────────────────────────┐      │
│  │ NSG (Firewall)                              │      │
│  │ Rule 1: Allow Port 80(HTTP)  ──┐            │      │
│  │ Rule 2: Allow Port 443(HTTPS)  ├──→ Applied to NICs│
│  │ Rule 3: Allow Port 22(SSH)   ──┘            │      │
│  └─────────────────────────────────────────────┘      │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### **Data Flow Example: SSH to VM**

```
- Laptop
    ↓ (SSH to 20.160.158.48:22)
    ↓
- Internet
    ↓
- Azure Public IP: 20.160.158.48
    ↓
- NSG checks: "Is port 22 allowed ?" → YES ✅
    ↓
- Network Interface (nic[0])
    ↓
- Subnet (10.0.2.0/24)
    ↓
- VM-1 (10.0.2.5)
    ↓
- SSH Daemon listens on port 22
    ↓
✅ Connection successful!
```

---

## PART 4: FILE ORGANIZATION

```
terraform/
├── main.tf              ## Provider + Resource Group
├── network.tf           ## VNet, Subnet, NIC, Public IP
├── security.tf          ## NSG, NSG Association
├── compute.tf           ## Linux VM
├── variables.tf         ## All input variables
├── outputs.tf           ## All outputs
├── terraform.tfvars     ## (optional) Variable overrides
└── .gitignore           ## Hide sensitive files
```

---

## QUICK REFERENCE: What Goes Where ?

| Resource | File | Required ? | Depends On |
|----------|------|-----------|-----------|
| **Resource Group** | main.tf | ✅ YES | Nothing |
| **Provider** | main.tf | ✅ YES | Nothing |
| **VNet** | network.tf | ✅ YES | RG |
| **Subnet** | network.tf | ✅ YES | VNet |
| **Public IP** | network.tf | ✅ (for internet) | RG |
| **NIC** | network.tf | ✅ YES | RG, Subnet, Public IP |
| **NSG** | security.tf | ✅ (for security) | RG |
| **NSG Association** | security.tf | ✅ (if NSG exists) | NSG, NIC |
| **Linux VM** | compute.tf | ✅ YES | RG, NIC |
| **Variables** | variables.tf | ✅ YES | Nothing |
| **Outputs** | outputs.tf | ❌ Optional | Various |

---

## COMMON MISTAKES TO AVOID

1. **❌ Creating NSG without NSG Association**
   - NSG exists but does nothing
   - Rules never applied

2. **❌ Wrong Hypervisor Generation match**
   - VM Size Gen 2 + Image Gen 1 = Error
   - Must match!

3. **❌ Missing Public IP Association in NIC**
   - VM unreachable from internet
   - Still works internally but not useful

4. **❌ Forgetting to attach NIC to VM**
   - VM has no network
   - Cannot SSH or access anything

5. **❌ No outputs defined**
   - Have to dig through Terraform state to find IPs
   - Inconvenient and error-prone

6. **❌ Hardcoded values instead of variables**
   - Cannot reuse infrastructure for dev/prod
   - Have to edit code each time

---

## FINAL CHECKLIST FOR ANY AZURE PROJECT

Before running `terraform apply`:

- [ ] Resource Group defined ?
- [ ] Provider configured ?
- [ ] VNet created with appropriate address space ?
- [ ] Subnet created within VNet ?
- [ ] NIC created and attached to subnet ?
- [ ] Public IP created (if internet access needed) ?
- [ ] NIC linked to Public IP ?
- [ ] NSG created with appropriate rules ?
- [ ] NSG **ASSOCIATED** to NIC ?
- [ ] VM created with correct NIC attached ?
- [ ] VM OS image hypervisor generation matches VM size ?
- [ ] SSH key configured ?
- [ ] Outputs defined for easy reference ?
- [ ] All `resource_group_name` properties set ?
- [ ] All `location` properties set to `var.location` ?
- [ ] Variables have descriptions ?
- [ ] No hardcoded values (everything is variable) ?
