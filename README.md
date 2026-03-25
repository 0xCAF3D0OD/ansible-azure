## **COMPLETE PROJECT SUMMARY**

```
WHAT YOU CREATED:
  1. Azure Infrastructure (Terraform)
  2. Automation Configuration (Ansible)
  3. Containerized WordPress Application (Docker)
```

---

## **PART 1: AZURE INFRASTRUCTURE (Terraform)**

### **Architecture created:**

```
Resource Group (container)
  ├── VNet (10.0.0.0/16) - Private network
  │   └── Subnet (10.0.2.0/24)
  │       ├── VM-1 (10.0.2.5) ← Public IP: 20.160.158.48
  │       └── VM-2 (10.0.2.4) ← Public IP: 20.71.116.56
  │
  ├── Network Security Group (NSG/Firewall)
  │   ├── Port 80 (HTTP) - Open ✅
  │   ├── Port 443 (HTTPS) - Open ✅
  │   ├── Port 22 (SSH) - Open ✅
  │   └── All other ports - Blocked ❌
  │
  └── Network Interfaces + Public IPs (Standard SKU)
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

### **Terraform Files:**

| File | Purpose |
|---------|-----------------|
| **main.tf** | Azure Provider + Resource Group |
| **network.tf** | VNet, Subnet, NICs, Public IPs |
| **security.tf** | NSG (firewall) + NSG association to NICs |
| **compute.tf** | Ubuntu 22.04 Gen 2 Linux VMs (Standard_D2als_v7) |
| **variables.tf** | Parameters (location, vm_count, vm_size, pub_key) |
| **outputs.tf** | IPs and resource IDs |

### **Key Point:**

The VMs start empty. Ansible configures them and deploys WordPress.

---

## **PART 2: AUTOMATION CONFIGURATION (Ansible)**

### **Execution flow:**

```
1. ansible-playbook playbook.yml -i inventory.yml
   ↓
2. Connects to 2 VMs via SSH (port 22)
   ├─ VM-1: 20.160.158.48
   └─ VM-2: 20.71.116.56
   ↓

3. Install Docker (using geerlingguy.docker role)
   ↓
4. Install docker-compose
   ↓
5. Create /opt/wordpress/ directory
   ↓
6. Generate self-signed SSL certificates
   ↓
7. Copy docker-compose.yml and nginx.conf
   ↓
8. Run: docker-compose up -d
   ↓
9. ✅ 4 containers start on each VM
```

### **Ansible Files:**

| File | Purpose |
|---------|-----------------|
| **playbook.yml** | Orchestration (install Docker, copy files, start containers) |
| **inventory.yml** | IP addresses + SSH credentials for the 2 VMs |
| **docker-compose.yml** | Definition of 4 containers (MySQL, WordPress, phpMyAdmin, Nginx) |
| **nginx.conf** | Reverse proxy + TLS configuration |

---

## **PART 3: CONTAINERIZED APPLICATION (Docker)**

### **4 Containers running on each VM:**

```
Container 1: MySQL
  ├─ Image: mysql:latest
  ├─ Database: mysqldb-dk
  ├─ Credentials: username / userpswd
  ├─ Port (internal): 3306
  └─ Persistent volume: mysql_data/

Container 2: WordPress
  ├─ Image: wordpress:latest
  ├─ Connects to: MySQL (db:3306)
  ├─ Port (internal): 80
  └─ Persistent volume: wordpress_data/

Container 3: phpMyAdmin
  ├─ Image: phpmyadmin:latest
  ├─ Connects to: MySQL
  ├─ Persistent volume: None (Stateless)
  └─ Config: PMA_ABSOLUTE_URI set to /phpma/

Container 4: Nginx (Reverse Proxy + TLS)
  ├─ Image: nginx:alpine
  ├─ Ports (external): 80 (HTTP) + 443 (HTTPS)
  ├─ Redirects: HTTP → HTTPS automatically
  ├─ Routes "/" → WordPress (80)
  ├─ Routes "/phpma/" → phpMyAdmin (80)
  └─ TLS: Self-signed certificates (/ssl/cert.pem, /ssl/key.pem)
```

>I'm using the standard WordPress image, which already includes an Apache server. Communication between Nginx and 
> WordPress therefore takes place via standard HTTP on port 80. Port 80 is only necessary if you're using a separate architecture with PHP-FPM.

>"why phpMyAdmin doesn't have a volume for persistance data ?"
>- It’s a simple interface: phpMyAdmin is just a visualization tool (a PHP client). It doesn’t contain any data itself. All databases, tables, and users are physically stored in the MySQL container (and its associated volume).
>- Persistence is offloaded: If I delete and recreate the phpMyAdmin container, it simply reconnects to MySQL on startup. Since the actual data is safely stored in the database volume, the interface instantly displays the content without any loss.
>- Avoiding code overwriting: In Docker, if I mounted an empty volume on the phpMyAdmin /var/www/html directory, I would overwrite the application’s source code itself, rendering the service unavailable.
---

## **NETWORK COMMUNICATION**

```
User Browser
  ↓ (https://20.160.158.48/)
  ↓
Azure NSG checks port 443 → ALLOWED ✅
  ↓
Nginx (port 443) receives request
  ↓
URL "/" → Forwards to WordPress:80 (internally)
URL "/phpma/" → Forwards to phpMyAdmin:80 (internally)
  ↓
WordPress/phpMyAdmin responds via Nginx
  ↓
User sees the page ✅

Blocked traffic:
  ❌ Port 3306 (MySQL) - NSG blocks it
  ❌ Port 80 (WordPress internal) - NSG blocks it
  ❌ Port 80 (phpMyAdmin internal) - NSG blocks it
```

---

## **RESILIENCE (Persistent Data)**

```
If a container restarts:
  ❌ Application code/config may reload
  ✅ Database + user data preserved

Why?
  → Docker volumes persist data outside containers
  → mysql_data/ = Database files
  → wordpress_data/ = Posts, images, user accounts
  → phpmyadmin_data/ = phpMyAdmin data
```

---

## **SECURITY**

### **Firewall (NSG):**
```
Open to Internet:
  ✅ Port 80 (HTTP) - Auto-redirects to HTTPS
  ✅ Port 443 (HTTPS) - WordPress + phpMyAdmin
  ✅ Port 22 (SSH) - Administration only

Internal only (blocked from Internet):
  ❌ Port 3306 (MySQL)
  ❌ Port 80 (WordPress)
  ❌ Port 80 (phpMyAdmin)
  ❌ All other ports
```

### **TLS/SSL:**
```
Self-signed certificates generated by Ansible:
  - /ssl/cert.pem (public certificate)
  - /ssl/key.pem (private key)
  - Nginx enforces HTTPS redirect
  - Browser shows "Not secure" (normal for self-signed)
```

>"How can WordPress port 80 be blocked if it's open on Nginx?"
> - Port 80 on the host (VM) is redirected to the Nginx container. 
> - The other containers (WordPress/phpMyAdmin) also listen on port 80, but only on their private Docker 
> IP addresses (e.g., 172.18.0.3), which are not mapped to the VM’s public IP.


---

## **PORTABILITY (Why 2 VMs?)**

```
To prove Ansible is portable:

Current setup: 2 identical VMs
What if you add a 3rd VM?
  1. Add new IP to inventory.yml
  2. Run: ansible-playbook playbook.yml
  3. ✅ 3rd VM configured identically (no manual work)

What if you change config?
  1. Edit docker-compose.yml or nginx.conf
  2. Run: ansible-playbook playbook.yml
  3. ✅ All VMs updated identically
```

---

## **FULL DEPLOYMENT WORKFLOW**

### **Step 1: Infrastructure (Terraform)**
```bash
$ cd terraform/
$ terraform init
$ terraform apply

Outputs:
  vm_public_ips = [20.160.158.48, 20.71.116.56]
  nsg_id = <security-group-id>
```

### **Step 2: Configuration (Ansible)**
```bash
$ cd ../ansible/
$ ansible-playbook playbook.yml -i inventory.yml

Executes on both VMs:
  ✅ Docker installed
  ✅ Containers started
  ✅ SSL configured
```

### **Step 3: Access**
```
WordPress:
  https://20.160.158.48/

phpMyAdmin:
  https://20.160.158.48/phpma/
```

---

## **KEY COMPONENTS EXPLAINED**

### **docker-compose.yml**

Defines 4 interdependent services:

```
db (MySQL):
  └─ Database storage for WordPress

wordpress:
  ├─ Depends on: mysqldb-dk
  └─ Connects to MySQL at mysqldb-dk:3306

phpmyadmin:
  ├─ Depends on: mysqldb-dk
  └─ GUI for managing MySQL

nginx:
  ├─ Depends on: wordpress
  ├─ Listens on ports 80 + 443
  ├─ Routes "/" → wordpress:80
  └─ Routes "/phpma/" → phpmyadmin:80

volumes: mysql_data, wordpress_data
  → Persist data across container restarts

networks: wordpress-network
  → Containers communicate by service name (db, wordpress, etc.)
```

### **nginx.conf**

Acts as entry point:

```
Receives ALL external traffic (80, 443)
  ↓
Port 80: Redirect to HTTPS (//)
Port 443: Verify SSL certificate
  ↓
URL "/" → Proxy to wordpress:80
URL "/phpma/" → Proxy to phpmyadmin:80
  ↓
Set headers (X-Real-IP, X-Forwarded-For, etc.)
```

### **playbook.yml**

Orchestration script:

```
1. Apply geerlingguy.docker role (install Docker)
2. Install docker-compose binary
3. Create /opt/wordpress/ directory
4. Generate self-signed SSL certificates (openssl)
5. Copy docker-compose.yml to /opt/wordpress/
6. Copy nginx.conf to /opt/wordpress/
7. Change directory + run docker-compose up -d
8. Wait for port 443 to be ready (10s delay, 60s timeout)
```

---

## **SUMMARY IN ONE SENTENCE**

> **Automating the deployment of a resilient, secure, and scalable WordPress infrastructure on Azure using Infrastructure as Code (Terraform) for cloud resources and Configuration Management (Ansible) for application setup.**

---

## **TECHNOLOGIES MASTERED**

| Technology | Role | Mastery |
|------------|------|---------|
| **Terraform** | Infrastructure provisioning | ✅ Variables, outputs, resources, NSG association |
| **Ansible** | Configuration automation | ✅ Roles, handlers, shell commands, file copying |
| **Docker** | Containerization | ✅ Multi-container setup, volumes, networks |
| **Nginx** | Reverse proxy + TLS | ✅ HTTP redirects, proxy_pass, SSL configuration |
| **Azure** | Cloud platform | ✅ Resource Groups, VNets, NSGs, VMs, Public IPs |
| **Security** | Firewall + encryption | ✅ NSG rules, SSL certificates, least privilege |
| **Resilience** | Data persistence | ✅ Docker volumes, restart policies, dependencies |

---

## **PROJECT STRUCTURE**

```
.
├── terraform/
│   ├── main.tf              (Provider + RG)
│   ├── network.tf           (VNet, Subnet, NIC, Public IPs)
│   ├── security.tf          (NSG + association)
│   ├── compute.tf           (VMs)
│   ├── variables.tf         (Parameters)
│   ├── outputs.tf           (IPs + IDs)
│   └── terraform.tfvars     (Optional overrides)
│
├── ansible/
│   ├── playbook.yml         (Orchestration)
│   ├── inventory.yml        (VM IPs + credentials)
│   ├── docker-compose.yml   (Container definitions)
│   └── nginx.conf           (Reverse proxy)
│ 
│
└── README.md                (This file)
```

---

**Deployment time: ~5 minutes (Terraform ~3 min + Ansible ~2 min)**

**Monthly cost: ~$120-160 (2× Standard_D2als_v7 VMs + storage)**