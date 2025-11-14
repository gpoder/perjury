# Security Policy

Perjury App is security-sensitive.

## Reporting

Do NOT file public issues.  
Email the maintainer privately.

Include:
- Description
- Steps to reproduce
- Impact
- Suggested fix (optional)

---

## Security Model

### Single-use Tokens
- Random 32-char keys
- Deleted on use
- TTL enforced

### IP Blocking
- Permanent on successful access

### Global Lockout
- All IPs blocked for N seconds

### No Caching
Image responses include:
```
Cache-Control: no-store
Pragma: no-cache
Expires: 0
```

### Secrets Excluded from Git
- Admin key  
- PIN  
- Logs  
- Token files  

### Fail-Closed
If storage errors occur → deny access.

