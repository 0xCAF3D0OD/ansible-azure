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


**Why:** The problem stemmed from a key located at `~/.ssh/azure.pub`. This key, generated within the Azure Portal, 
was the one Terraform was trying to use, but it couldn't locate or access it properly

**Solution:**  Employ a local key, specifically the one found at `~/.ssh/id_rsa.pub`, which you manage.

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



**Solution:** Add `sku = "Standard"` to the Public IP resource.

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
vm_size = "Standard_D2als_v7"  # Gen 2

# compute.tf
source_image_reference {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy-daily"  # Daily = Gen 2!
  sku       = "22_04-daily-lts-gen2"                # Explicitly Gen 2
  version   = "latest"
}

resource "azurerm_public_ip" "pip" {
  sku = "Standard"  # Not Basic!
}
```

---

### **❌ Issue 7: Bad access to vm via ssh**

Why: public and private key are stocked in .ssh folder at the root from terminal, be aware to have:
- id_rsa.pub
- id_rsa.pem

In .ssh folder, it's critical otherwise the connection will fail, be sure that the **ssh private key can be readed**
otherwise it will also fail with:

```terminaloutput
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0644 for '/Users/exemple/.ssh/private_ssh_key.pem' are too open.
It is required that your private key files are NOT accessible by others.
This private key will be ignored.
Load key "/Users/exemple/.ssh/private_ssh_key.pem": bad permissions
debug1: No more authentication methods to try.
adminuser@ip.address: Permission denied (publickey).
...
```

add rights to the file with: `chmod +400 "/Users/exemple/.ssh/private_ssh_key.pem"`


### **❌ Issue 8: Port 80 Conflict**

*   **The Issue:** You were seeing an “Apache/2.4.65 (Debian)” page instead of your website.
*   **The Cause:** An Apache server had installed itself on your Azure VM and was “stealing” traffic before Docker had a chance to intervene.
*   **The Solution:** `sudo systemctl stop apache2` and `disable`.
*   **Why?** Only one service can listen on a given port ($80$ or $443$). For your **Docker Nginx** to be the orchestrator, the port must be free on the host VM.

### **❌ Issue 9: Database Security**

*   **The Error:** Port `3306` was open on the public IP in your `docker-compose.yml`.
*   **The Cause:** Use of the `ports: - “3306:3306”` directive.
*   **Solution:** Remove the `ports` section for MySQL and phpMyAdmin.
*   **Why?** The requirement is that the database must not be accessible from the Internet. By staying exclusively on the `wordpress-network` (internal), WordPress can communicate with the database, but an external hacker is blocked at the gate.


### **❌ Issue 10: Nginx Reverse Proxy**

*   **The Error:** 404 or 502 errors on `/phpma/`.
*   **The Cause:** 
    1. Using `location = /phpma/` (too strict a match).
    2. Missing trailing slash in `proxy_pass`.
*   **Solution:** Use `location /phpma/` and `proxy_pass http://phpmyadmin:80/`.
*   **Why?** Nginx needs to know that anything starting with `/phpma/` must be sent to the phpMyAdmin container, “cleaning” the URL so that the container understands the request.

### **❌ Issue 11: “Sabotaging” the Source Code (Volumes)**
  
*   **The Error:** phpMyAdmin displayed “Not Found” even though the container was running.
*   **The Cause:** You had created a volume `- ./phpmyadmin_data:/var/www/html`.
*   **The Solution:** Delete this volume.
*   **Why?** Mounting an empty folder over the source code of a Docker application instantly erases it. phpMyAdmin is **stateless**: it doesn’t need to save any files; it simply reads your database.

### **❌ Issue 12: The URL Path (PMA_ABSOLUTE_URI)**

*   **The Error:** The phpMyAdmin interface was displayed without images or CSS styles.
*   **The Cause:** phpMyAdmin thought it was at the root (`/`) and was looking for its files in the wrong location.
*   **Solution:** Add the `PMA_ABSOLUTE_URI` environment variable.
*   **Why?** This forces the application to generate internal links that start with `/phpma/`, ensuring that Nginx always redirects to the correct container.

---

## Final Infrastructure Chart

| Component | Role | Status | Public Access |
| :--- | :--- | :--- | :--- |
| **Nginx** | Gateway / Proxy | **Stateful** (Config) | **YES** (80/443) |
| **WordPress** | Site Engine | **Stateful** (Images/Plugins) | **NO** (Via Nginx only) |
| **MySQL** | Database | **Stateful** (SQL Data) | **NO** (Isolated) |
| **phpMyAdmin** | Management Interface | **Stateless** (Interface) | **NO** (Via Nginx + HTTPS) |

---

## Tips
**“How did you secure access to the database?”**
> Answer: *"Applying the principle of least privilege. The database is isolated in a private internal Docker network. Only WordPress and phpMyAdmin can access it. Administrator access to the database is exclusively via an Nginx reverse proxy encrypted with HTTPS on a specific route, without ever exposing port 3306 to the Internet."*

**Would you like me to help you prepare a list of 3 or 4 questions?