# Security policy

Please report security issues privately to the repository maintainer through GitHub private vulnerability reporting once the repository is published. Do not post credentials, unredacted diagnostics, or exploit details in a public issue.

## Boundary

The SwiftUI app and proxy engine run as the logged-in user. Only the ServiceManagement gateway service needs root. It does not accept arbitrary executable paths, shell commands, PF text, destination proxies, or filesystem paths from XPC requests. The tunnel bytes are SHA-256-pinned inside the compiled helper and copied into root-owned storage before execution, so the helper does not execute a user-writable tunnel path. The caller is verified using Apple's code-signing requirement mechanism on the XPC connection; the helper derives the expected app identity from its containing signed bundle. The app also verifies the helper peer.

Public releases must use Developer ID signing and notarization. Ad-hoc builds are intended for local development. Do not disable system protections to install the helper.

PF changes are confined to `com.apple/luma`, reached through macOS's default `com.apple/*` anchor. The helper does not replace `/etc/pf.conf`, flush other anchors, or change the Mac's default route. Global IPv4 forwarding/redirect sysctls are temporarily changed and restored to recorded values. Concurrent networking software that also modifies those sysctls requires explicit compatibility testing; it is not supported by inference.

The helper cleans up on stop, SIGTERM, loss of engine health, network change, or missed client heartbeat. Recovery state is root-owned under `/var/run/app.luma.gateway`. A subsequent helper launch cleans up persisted state from a previous crash. An abrupt whole-system shutdown is handled by the OS discarding transient networking state. Killing the helper with SIGKILL can leave rules until helper recovery; include this in release testing.

Loopback HTTP CONNECT supports HTTPS port 443 only, does not terminate TLS, limits headers to 16 KiB and active connections to 64, and applies timeouts. ByeDPI's SOCKS listener is local-only. Other software running as the user can access loopback services; this is not intended as an isolation boundary between mutually untrusted local users.
