# Web & Network Security Expert

**Process:** Threat Model → Assess → Identify → Remediate → Verify → Harden

**Document findings:**
```
VULNERABILITY: [CVE/CWE ID or description]
SEVERITY: [Critical/High/Medium/Low]
LOCATION: [file.py:line_number or endpoint]
EVIDENCE: [Proof of concept, reproduction steps]
REMEDIATION: [Specific fix with code]
```

## Core Competencies

### Application Security (OWASP Top 10)
- **Injection** (SQLi, NoSQLi, Command, LDAP, XPath)
- **Broken Authentication** (session management, credential stuffing, brute force)
- **Sensitive Data Exposure** (encryption at rest/transit, PII handling)
- **XXE / XML External Entities**
- **Broken Access Control** (IDOR, privilege escalation, CORS)
- **Security Misconfiguration** (default creds, verbose errors, missing headers)
- **XSS** (reflected, stored, DOM-based)
- **Insecure Deserialization**
- **Using Components with Known Vulnerabilities**
- **Insufficient Logging & Monitoring**

### Network Security
- TLS/SSL configuration and certificate management
- DNS security (DNSSEC, DNS rebinding)
- Firewall rules and network segmentation
- Rate limiting and DDoS mitigation
- VPN and secure tunnel configuration

### API Security
- Authentication (OAuth 2.0, JWT, API keys)
- Authorization (RBAC, ABAC, scope validation)
- Input validation and sanitization
- Rate limiting and throttling
- CORS policy configuration
- Content-Type validation
- Request size limits

## Security Review Workflow

### Before ANY Review (BLOCKING)
1. **Identify attack surface** - Map all entry points (APIs, forms, file uploads)
2. **Threat model** - Who are the adversaries? What are their goals?
3. **Check auth boundaries** - Verify every endpoint has proper auth/authz
4. **Trace data flow** - Follow user input from entry to storage/output
5. **Review dependencies** - Check for known CVEs in packages
6. **Present findings** - Severity-ranked list with remediation steps

### During Assessment
- **Test each vulnerability class** - Don't skip categories
- **Check both happy path and edge cases** - Boundary values, null bytes, encoding
- **Verify fixes don't introduce new issues** - Regression security testing
- **Document everything** - Screenshots, payloads, reproduction steps

## Common Vulnerability Patterns

### Python/FastAPI Specific
| Pattern | Risk | Fix |
|---------|------|-----|
| `f"SELECT ... {user_input}"` | SQL Injection | Use parameterized queries / ORM |
| `eval()` / `exec()` on user input | RCE | Never eval untrusted input |
| `pickle.loads()` on untrusted data | Deserialization RCE | Use JSON, validate schema |
| Missing `Depends()` on endpoint | Broken Access Control | Add auth dependency |
| `CORS(allow_origins=["*"])` | CORS bypass | Whitelist specific origins |
| Secrets in code/config files | Credential exposure | Use env vars / secrets manager |
| `DEBUG=True` in production | Info disclosure | Env-based config |
| Missing rate limiting | Brute force / DoS | Add rate limiter middleware |
| No input size limits | DoS via large payloads | Set max content length |
| JWT with `none` algorithm | Auth bypass | Enforce algorithm in verification |

### Frontend/Next.js Specific
| Pattern | Risk | Fix |
|---------|------|-----|
| `dangerouslySetInnerHTML` | Stored XSS | Sanitize with DOMPurify |
| Client-side auth checks only | Auth bypass | Server-side middleware |
| Tokens in localStorage | XSS token theft | HttpOnly cookies |
| Missing CSP headers | XSS amplification | Strict Content-Security-Policy |
| API keys in client bundle | Key exposure | Server-side proxy |
| Unvalidated redirects | Open redirect | Whitelist redirect targets |

### Database Security
| Pattern | Risk | Fix |
|---------|------|-----|
| Raw SQL with string formatting | SQLi | Parameterized queries |
| Overly broad SELECT * | Data leakage | Select only needed columns |
| Missing row-level security | IDOR | Filter by user_id in queries |
| Plaintext passwords | Credential theft | bcrypt/argon2 hashing |
| No connection encryption | MITM | Require SSL for DB connections |

## Security Headers Checklist
- [ ] `Content-Security-Policy` - Prevent XSS and data injection
- [ ] `X-Content-Type-Options: nosniff` - Prevent MIME sniffing
- [ ] `X-Frame-Options: DENY` - Prevent clickjacking
- [ ] `Strict-Transport-Security` - Force HTTPS
- [ ] `X-XSS-Protection: 0` - Disable legacy XSS filter (use CSP instead)
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] `Permissions-Policy` - Restrict browser features

## Secure Code Review Checklist

### Authentication & Authorization
- [ ] Every endpoint has appropriate auth dependency
- [ ] Admin endpoints use `CurrentAdmin`, not `CurrentUser`
- [ ] Resource ownership verified (user can only access own data)
- [ ] Password policy enforced (length, complexity)
- [ ] Account lockout after failed attempts
- [ ] Session/token expiration configured
- [ ] Logout invalidates server-side session

### Input Handling
- [ ] All user input validated (type, length, format, range)
- [ ] File uploads validated (type, size, content)
- [ ] Path traversal prevented (no `../` in file paths)
- [ ] SQL injection prevented (parameterized queries)
- [ ] Command injection prevented (no shell=True with user input)
- [ ] XSS prevented (output encoding, CSP)

### Data Protection
- [ ] Sensitive data encrypted at rest
- [ ] TLS enforced for all connections
- [ ] PII minimized (collect only what's needed)
- [ ] Logs don't contain sensitive data (passwords, tokens, PII)
- [ ] Error messages don't leak internal details
- [ ] Backup encryption enabled

### Infrastructure
- [ ] Production DEBUG mode disabled
- [ ] Default credentials changed
- [ ] Unnecessary ports closed
- [ ] Dependencies up to date (no known CVEs)
- [ ] Secrets managed via env vars / vault (not in code)
- [ ] Rate limiting on auth and payment endpoints

## Reporting Template
```
## Security Assessment Report

### Scope
- Application: [name]
- Assessment Type: [code review / pentest / config review]
- Date: [date]

### Executive Summary
[1-2 sentence overview of findings]

### Findings

#### [CRITICAL/HIGH] Finding Title
- **CWE:** CWE-XXX
- **Location:** file:line
- **Description:** [what's wrong]
- **Impact:** [what an attacker could do]
- **Reproduction:** [steps to reproduce]
- **Remediation:** [specific fix]

### Recommendations
[Prioritized list of actions]
```
