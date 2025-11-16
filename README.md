# Perjury App  
A secure, single-use PIN-protected image viewer with IP blocking, token-based access, 
and an administrative control panel.

This project was designed for scenarios where:
- A protected image must be revealed **once**, for **10 seconds**,  
- The viewer must not be able to reload or reuse the URL,  
- The client IP becomes **permanently blocked** upon successful access,
- Optionally, **all IPs** enter a 5-minute global lockout,
- Admin can manage settings, audit logs, and IP blocks.

The application uses:
- **Flask** with Blueprints  
- **DispatcherMiddleware** to allow mounting under `/perjury/`  
- **Flat-file JSON** for logs, tokens, and block records  
- **Nginx** reverse proxy  
- **Single access tokens** that expire and cannot be reused

---

## 💡 Features

### 🔐 PIN Access
A user enters a 4-digit PIN to view the protected image.  
If correct:
- A secure tokenized URL is generated  
- Image displays once for 10 seconds  
- The viewer’s IP becomes permanently blocked  
- Global lockout triggers for all IPs (optional setting)

### 🛡 IP Blocking
- Each IP that successfully views the image is permanently blocked  
- Incorrect PIN attempts may also trigger temporary blocks  
- Global 5-minute lockout mode available

### ⏱ One-Time Image Access
- The image is never cached  
- Served via tokenized URL  
- Token JSON files ensure access is single use  
- Expired tokens cannot be reused

### ⚙ Admin Control Panel (`/control`)
Admin can:
- View/update settings  
- Delete blocked IPs  
- Clear global lockout  
- View/clear audit logs  
- Inspect runtime data  
Admin access uses a key:  
`/perjury/control/?key=<ADMIN_KEY>`

### 📁 Data Storage (Flat Files)
Stored under `data/`:
- `data/settings.json`  
- `data/log.json`  
- `data/global.json` (global lockout state)  
- `data/blocks/*.json` (blocked IPs)  
- `data/tokens/*.json` (single-use tokens)

---

## 🚀 Installation

Clone:

```bash
git clone git@github.com:<yourname>/perjury.git
cd perjury
```

Install:

```bash
pip install -r requirements.txt
```

Run:

```bash
python main.py
```

---

## 📄 License
MIT — see LICENSE.
