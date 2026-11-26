# Security review — development build

## Assets and boundaries

Protect administrator authority, unrelated network rules, console connectivity and Discord credentials. The GUI and connection engine are unprivileged. The gateway helper changes only the selected IPv4 client's route through its own PF anchor. It never receives shell text, executable paths, raw PF rules or credentials over XPC.

## Controls implemented

- Both sides of XPC require the peer's designated code-signing requirement. The helper refuses non-root execution and root clients. A console session has an owning UID; other users cannot stop it or keep it alive.
- The packaged tunnel binary's SHA-256 is embedded in the compiled helper. Before execution, the helper reads the bytes, verifies their digest, and writes those verified bytes to its root-owned 0700 directory. It never executes a user-writable tunnel path. A changed binary fails closed, without an extra user prompt.
- Executable arguments are arrays, never shell interpolations. Child commands use a fixed PATH and C locale. Private IPv4, subnet masks, device/interface names, router/host/broadcast boundaries and the freshly detected network are checked again in the privileged process.
- Root recovery storage rejects symlinks, non-root ownership and group/world write access. Cleanup errors preserve recovery state and are reported instead of presenting false success.
- The helper uses its own PF enable reference and anchor. Loss of engine health, network changes and missed app heartbeats trigger cleanup.
- Proxies bind to loopback, not the LAN. The HTTP bridge accepts HTTPS CONNECT only, limits headers to 16 KiB, bounds header time and concurrent connections, and never intercepts TLS. Socket descriptors are close-on-exec. The engine has a connection cap.
- Child signal dispositions and masks are reset before exec, and the child joins the launchd job's process group. A documented macOS-only ByeDPI patch exits on termination signals using async-signal-safe `_exit`, allowing launchd cleanup if the supervisor crashes. Normal engine exits and forced crashes are integration-tested. The privileged tunnel uses posix_spawn with inherited process group, reset signal state, close-on-exec defaults and explicit child reaping.
- No telemetry, remote executable updates, credentials, router administration or certificate installation. Exported diagnostics omit device IP/MAC addresses, usernames and raw traffic.
- Dependency downloads use pinned versions and SHA-256. Dependency notices ship with the app. Public release signing must use Developer ID and Apple notarization.

## Explicit limits

This is an IPv4 access tool, not a VPN, anonymity service or security boundary against malware already running as the same user. Local processes can access loopback proxies; upstream ByeDPI does not provide a multi-user authentication boundary. DPI methods do not replace the application's TLS certificate validation.

Ad-hoc signing is for local development. The new helper's macOS approval, rejection of an unauthorized XPC client, console voice/game/NAT behavior, forced-helper-crash recovery and uninstall require signed-app acceptance testing. Unit and user-space integration results do not establish these properties by themselves. A separate security audit has not been performed.

Global forwarding/redirect settings are shared OS state: concurrent network utilities that modify them need compatibility testing. A force-killed helper can leave transient rules until its recovery launch. No promise of instantaneous cleanup after SIGKILL is made.
