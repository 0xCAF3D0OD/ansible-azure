## **MAIN CONTEXT**

```nginx
user nginx;
```

**What is it?** Which Linux user runs Nginx.

**Why?** Security. If you set `user root`, and Nginx is hacked, the hacker gains root access. With `user nginx`, their access is restricted.

**Analogy:** It's like saying, "This server runs under the 'nginx' account, not 'root'."

---

```nginx
worker_processes auto;
```

**What is it?** The number of processes that handle HTTP requests.

**Why?** If you have 4 CPUs, you want 4 workers to handle 4 requests in parallel. `auto` = detects automatically.

**Without this:** By default, Nginx uses 1 worker = 1 request at a time. Very slow!

**Analogy:** It's like hiring 4 cashiers instead of 1. It goes faster.

---

```nginx
error_log /var/log/nginx.error_log info;
```

**What is this?** Where to log Nginx errors.

**Why?** If something breaks, you need to check the logs for debugging.

**Without this:** Errors disappear, and you don't know what's broken.

**Analogy:** It's like a "logbook" for errors.

---

### **EVENTS CONTEXT**

```nginx
events {
    worker_connections 1024;
}
```

**What is it?** Maximum number of simultaneous connections per worker.

**Why?** If you have 1,000 users and `worker_connections = 1,024`, and 4 workers, you can handle 4,000 users (1,024 × 4).

**Without this:** Nginx rejects connections after a certain threshold.

**Analogy:** It's like the "capacity of a checkout line."

---

### **HTTP CONTEXT**

```nginx
http {
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    '"$gzip_ratio"';
```

**What is it?** HTTP log format (for each request).

**Why?** You want to know who is accessing what, when, and from where.

**Example of generated log:**

```
192.168.1.100 - - [25/Mar/2026:15:30:45 +0000] "GET / HTTP/1.1" 200 1234 "-" "Mozilla/5.0"
```

**Variables:**
- `$remote_addr` = Client IP
- `$time_local` = Time
- `$request` = HTTP request (GET / POST, etc.)
- `$status` = HTTP status code (200 = OK, 404 = Not Found, etc.)
- `$bytes_sent` = Response size
- `$http_user_agent` = Client browser

**Without this:** No logs = you don't know who is accessing your site.

**Analogy:** It's the "in/out log" of a store.

---

### **SERVER 1 (HTTP → HTTPS redirect)**

```nginx
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
```

**What is it?** A "virtual server" listening on port 80 (HTTP).

**Why?** 
1. Users type `http://example.com` (not HTTPS)
2. This server responds and says: "Go to `https://example.com` instead"
3. `return 301` = permanent redirect
4. `$host` = user's domain
5. `$request_uri` = exact path

**Example:**

```
User types:  http://example.com/pma
Nginx responds:      "301 redirect to https://example.com/pma"
Browser goes to:   https://example.com/pma
```

**Without this:** People can access via HTTP (unencrypted) = DANGER for data!

**Analogy:** It's a sign that says "No, go this way (HTTPS), it's safer."

---

### **SERVER 2 (HTTPS)**

```nginx
server {
    listen 443 ssl http2;
    server_name _;
```

**What is it?** The actual server that serves the content, on port 443 (HTTPS).

**Why?** Port 443 = encrypted HTTPS. `ssl` = uses certificates. `http2` = faster protocol.

---

```nginx
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
```

**What is it?** SSL files (certificate + private key).

**Why?** Required to encrypt the connection.

**Without it:** No HTTPS, just HTTP = unencrypted data = danger!

**Analogy:** It's the "padlock" that encrypts the communication.

---

```nginx
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
```

**What is it?** TLS (SSL security) versions and encryption algorithms.

**Why?** `TLSv1.2` and `TLSv1.3` = modern and secure. `HIGH` = strong algorithms. `!MD5` = excludes weak ones.

**Without this:** You could end up using old/broken protocols = danger!

**Analogy:** It's like saying "I ONLY want modern locks, not the old broken ones."

---

```nginx
    access_log /var/log/nginx.access_log main;
```

**What is it?** Where to write HTTP logs (access to this server).

**Why?** To know who is accessing what (uses the `main` format defined above).

**Without this:** No logs for this HTTPS server.

**Analogy:** It's the "visitor logbook" for people coming in.

---

### **LOCATION / (WordPress)**

```nginx
    location / {
        proxy_pass http://wordpress:9000;
```

**What is it?** Routes `/` (root) requests to the WordPress container on port 9000.

**Why?** WordPress runs in a separate container. Nginx must tell it to "send this request to WordPress."

**Example:**

```
User goes to: https://example.com/
Nginx says:        "Send this to wordpress:9000"
WordPress:        Receives the request and responds
Response:          Returns to the browser via Nginx
```

**Without this:** HTTP requests arrive at Nginx, but go nowhere! 404 error.

**Analogy:** It's like a "switchboard" that receives a call and says, "I'll transfer you to the WordPress department."

---

```nginx
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
```

**What is this?** Information to send to WordPress so it knows where the request is coming from.

**Why?** Otherwise, WordPress thinks that ALL requests come from Nginx (`localhost`). That's wrong!

**Variables:**
- `$host` = Original domain (example.com)
- `$remote_addr` = Client's actual IP
- `$proxy_add_x_forwarded_for` = Chain of IPs that passed the request
- `$scheme` = http or https

**Analogy:** It's like a "label" on a package that says "This comes from this actual address, not the default one."

---

### **LOCATION /phpma (phpMyAdmin)**

```nginx
    location = /phpma {
        proxy_pass http://phpmyadmin:80;
        proxy_set_header Host $host;
    }
```

**What is it?** Routes `/phpma` (exact path) to phpMyAdmin on port 80.

**Why?** phpMyAdmin runs in its own separate container. Nginx says, "If the URL ends with `/phpma`, send it to phpMyAdmin."

**Example:**

```
User goes to: https://example.com/
Nginx says:        "Send this to WordPress"

User goes to: https://example.com/phpma
Nginx says:        "Send this to phpMyAdmin"
```

**`=`** = EXACT path (not `/phpma/` or `/phpmyadmin`).

**Without this:** phpMyAdmin is not accessible

**Analogy:** It's like saying, "If the number ends in 5000, call the phpMyAdmin service."

---

### **SUMMARY - Why you NEED each element:**

| Element | Why is it required? |
|---------|--------------- -------|
| `user nginx` | Security (not root) |
| `worker_processes auto` | Performance (parallel processing) |
| `error_log` | Debugging |
| `worker_connections 1024` | Maximum capacity |
| `log_format main` | Log access |
| `server listen 80 + redirect 301` | Force HTTPS |
| `server listen 443 ssl` | Serve actual content over HTTPS |
| `ssl_certificate / ssl_key` | Encryption |
| `ssl_protocols / ssl_ciphers` | Security (modern protocols) |
| `access_log` | Logs for debugging |
| `location / + proxy_pass` | Forward requests to WordPress |
| `proxy_set_header` | Pass the actual info to WordPress |
| `location /phpma + proxy_pass` | Forward `/phpma` requests to phpMyAdmin |

---

**Basically:** Each directive tells Nginx **"Who's speaking? Where to send it? With what encryption? And how to log it?"**
