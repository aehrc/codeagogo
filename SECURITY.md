# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Codeagogo, please report it responsibly through **GitHub Security Advisories**:

1. Go to the [Security Advisories](../../security/advisories) page
2. Click **"Report a vulnerability"**
3. Fill in the details and submit

**Please do not open a public issue for security vulnerabilities.**

## Scope

The following are in scope for security reports:

- Code injection or command injection via concept terms or ECL expressions
- Cross-site scripting (XSS) in the WebView-based visualization panel
- Sensitive data exposure (clipboard contents, user data)
- Denial of service via crafted input (e.g., ReDoS, stack overflow)
- Insecure network communication (e.g., bypassing HTTPS)

The following are **out of scope**:

- Issues requiring physical access to the machine
- Issues in third-party terminology servers
- Social engineering attacks

## Response Timeline

- **Acknowledgement**: Within 3 business days
- **Initial assessment**: Within 10 business days
- **Fix timeline**: Depends on severity; critical issues prioritised

## Safe Harbor

We consider security research conducted in good faith to be authorised. We will not pursue legal action against researchers who:

- Act in good faith to avoid privacy violations and disruption
- Report vulnerabilities promptly
- Allow reasonable time for remediation before disclosure

## Supported Versions

Only the latest release is actively supported with security updates.
