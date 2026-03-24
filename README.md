# ansible-azure
small project for testing capacity

✅ Resource Group + VNet + Subnet + NICs + Public IPs
✅ Configured variables (vm_count, vm_size, location)
✅ SSH configuration with public key


### **2. Final winning configuration:**
- **Region:** West Europe ✅
- **VM Size:** Standard_D2als_v7 (Gen 2) ✅
- **Image:** Ubuntu 22.04 Jammy Daily Gen 2 ✅
- **Public IPs:** Standard SKU ($3/month each) ✅
- **Count:** 2 VMs instead of 4 ✅

---

## **WHAT WENT WRONG (and why):**

### **❌ Issue 1: Standard_B1s not found**


**Why:** Azure did not have any B1s capacity in any region at that time. This is normal; Azure has capacity limits per region/SKU.

**Lesson:** Not all SKUs are available everywhere, all the time.

---

### **❌ Issue 2: Invalid SSH key**


**Why:** Pointed to `~/.ssh/azure.pub` (key created in the Azure Portal) that Terraform couldn’t find or read correctly.

**Solution:** Use a local key (`~/.ssh/id_rsa.pub`) that is under your control.

---

### **❌ Problem 3: No Public IPs**


**Why:** I had forgotten to add the public IPs initially. This was critical for:
- SSH from outside
- Ansible to deploy WordPress
- HTTP/HTTPS access

**Solution:** Add `azurerm_public_ip` + associate them with the NICs.

---

### **❌ Issue 4: Basic SKU Public IPs not allowed**


**Why:** The subscription could not create Basic SKU IPs (Azure is phasing them out). Must use Standard.



**Solution:** Add `sku = “Standard”` to the Public IP resource.

---

### **❌ Issue 5: Gen 1 vs. Gen 2 Incompatibility**


**Why:** 
- Using **Standard_D2als_v7** (Gen 2 only)
- But the **Ubuntu 22.04 Jammy** image was **Gen 1 only**
- Gen 1 and Gen 2 are not compatible!

**Lesson:** 
```
VM Size → Determines Hypervisor Gen (1 or 2)
OS Image → Must match the Gen
```

---

### **❌ Issue 6: Incorrect Ubuntu 24.04 SKU**

Why: The exact SKU for Ubuntu 24.04 Gen 2 was not 24_04-lts. Canonical uses different conventions.
Solution: Look up the correct SKU in Azure (az vm image list...)

```hcl
# variables.tf
vm_size = “Standard_D2als_v7”  # Gen 2

# vm.tf
source_image_reference {
  publisher = “Canonical”
  offer     = “0001-com-ubuntu-server-jammy-daily”  # Daily = Gen 2!
  sku       = “22_04-daily-lts-gen2”                # Explicitly Gen 2
  version   = “latest”
}

resource “azurerm_public_ip” “pip” {
  sku = “Standard”  # Not Basic!
}
```
