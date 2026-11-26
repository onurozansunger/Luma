# Acceptance plan

Automated tests cover address parsing and subnet boundaries, injection rejection, PF scope generation, proxy CONNECT parsing and command arguments/timeouts. The isolated integration script covers real HTTPS, SOCKS UDP DNS, engine-child recovery and cleanup.

Manual gateway tests (must be performed on the signed app itself):

- Install into Applications and approve only through macOS ServiceManagement.
- Reject a different unsigned or differently signed XPC caller.
- Enter invalid, public, router, own, broadcast and off-subnet console IPs; all must fail before mutation.
- Start with a clean PF state and with other anchors already present; preserve all unrelated rules and default routes.
- Start twice; the second request must not create another tunnel.
- Test IPv4, DNS, PSN login, Discord voice in both directions, game connectivity and NAT type from the console.
- Switch to normal console profile; confirm no dependency on Mac access.
- Stop gateway while keeping Mac Discord available; verify own anchor, enable token, sysctls and tunnel cleanup.
- Terminate the engine child; verify automatic recovery. Terminate the whole app unexpectedly; verify gateway cleanup after heartbeat timeout.
- Change Wi-Fi network; ensure safe stop instead of routing stale addresses.
- Force-kill helper, relaunch, and verify recovery.
- Test sleep/lid/reboot behavior, unsigned/ad-hoc build handling and another local user.
- Stop and unregister helper before uninstalling. Ensure a copied or moved app does not retain a usable stale daemon registration.

Record only non-identifying aggregate results. Never include device addresses, account details, developer home paths, console identifiers or private logs in release artifacts.
