# Terminal Resize Investigation

## Problem

iOS terminal output is formatted for macOS terminal dimensions. Lines wrap incorrectly on iPad/iPhone because the zmx session PTY size is set by the macOS Ghostty terminal (the zmx leader).

## Architecture

```
macOS Ghostty → forkpty → zmx attach (command wrapper) → shell
                          ↕ zmx IPC socket
                          zmx daemon (owns session PTY)
                          ↕ zmx IPC socket
WebSocket relay → spawns zmx attach → connects as second client
                  ↕
iOS app (SwiftTerm) ← WebSocket → Supacode server (port 7742)
```

- **Ghostty** owns the PTY on macOS. zmx is injected as a `command_wrapper`. Ghostty handles resize via `TIOCSWINSZ` on its master fd.
- **zmx daemon** owns the session. Multiplexes clients. Leader client controls PTY size.
- **zmx attach** connects to the daemon as a client. On user input, zmx auto-promotes to leader. Leader's terminal size drives the session PTY.
- **WebSocket relay** (`WebAccessTerminalRelay.swift`) spawns `zmx attach` and bridges its I/O to the WebSocket.

## zmx leader/follower protocol

1. Client connects → sends `Init` message with its terminal size
2. If no leader exists, client becomes leader → daemon resizes PTY
3. When a different client sends user input → daemon promotes it to leader
4. Daemon sends `Resize` IPC message to new leader → leader responds with its terminal size → daemon resizes PTY
5. `SIGWINCH` propagates to the shell → shell redraws at new size

## What we tried

### Approach 1: Pipes (original, working I/O)

**Server:** `Process()` with `Pipe()` for stdin/stdout. zmx attach runs without a TTY.

**Result:**
- Terminal I/O works — keystrokes and output relay correctly
- zmx detects `isatty(stdin) == false` → skips raw mode, skips screen clear
- On user input, zmx promotes iOS client to leader
- Leader responds with `getTerminalSize(STDOUT_FILENO)` → fails on pipe → falls back to **160×24**
- Session PTY resizes to 160×24 — reasonable for iPad but not the actual iOS terminal size
- When macOS user types, macOS reclaims leader → PTY resizes to macOS dimensions → iOS output wraps badly again

**Verdict:** I/O works. Resize sort-of works (160×24 fallback) but not to the actual iOS terminal size. No way to send the real iOS cols/rows to zmx.

### Approach 2: PTY via posix_openpt + posix_spawn

**Server:** Replace pipes with PTY pair created via `posix_openpt`/`grantpt`/`unlockpt`/`ptsname`. Slave fd passed to `Process()` as stdin/stdout/stderr. Parse resize JSON text frames from WebSocket, apply via `ioctl(TIOCSWINSZ)` on master fd.

**iOS:** Send `{"type":"resize","cols":N,"rows":M}` text frame on connect and on `sizeChanged`.

**Result:**
- **Broken.** `Foundation.Process` uses `posix_spawn` internally, which does NOT call `setsid()` or `login_tty()`. The child gets the PTY slave fds but it's not the controlling terminal.
- zmx attach detects `isatty(stdin) == true` → enters raw mode → **clears the screen** (`\x1b[2J\x1b[H`)
- Terminal shows blinking cursor. Typing is broken (raw mode + no controlling terminal).
- Reverted.

### Approach 3: PTY via forkpty (current)

**Server:** Use `forkpty()` directly from Swift. Child calls `execvp("zmx", ["zmx", "attach", sessionName])` immediately after fork. Parent gets master fd. Parse resize text frames, apply via `ioctl(TIOCSWINSZ)`.

**iOS:** Same text frame resize as Approach 2.

**Result:**
- `forkpty` properly sets up `setsid()` + controlling terminal
- zmx attach detects `isatty(stdin) == true` → enters raw mode → **clears the screen**
- zmx daemon sends terminal state restore after clear
- **Some worktrees work** — state restore repaints the terminal content
- **Some worktrees show only blinking cursor** — state restore doesn't fully repaint (unclear why; possibly race condition or minimal state)
- The screen clear on every attach is undesirable — it causes a visual flash even when restore works
- Resize via text frames works when zmx promotes iOS to leader

**Verdict:** Resize works correctly but the screen clear + unreliable state restore breaks the experience for some terminals.

## Root cause analysis

The fundamental problem: zmx attach's TTY detection is all-or-nothing.

- **Pipes (isatty=false):** No screen clear, no raw mode. I/O works. But zmx can't query terminal size → falls back to 160×24. No way to inject the real iOS terminal size.
- **PTY (isatty=true):** zmx enters raw mode and clears screen. Can query/set terminal size. But the clear + state restore is unreliable.

We need one of:
1. A way to **tell zmx the terminal size without giving it a real TTY** (pipes + size injection)
2. A way to **prevent zmx from clearing the screen** when it has a PTY
3. A **zmx CLI command** to resize a session externally: `zmx resize <session> <cols> <rows>`
4. **Direct zmx IPC socket** communication — bypass zmx attach entirely, send Init/Resize messages with the correct terminal size

## Recommended next step

**Option 3: `zmx resize` CLI command** — cleanest separation. The WebSocket relay uses pipes (proven working for I/O). When the iOS client sends a resize text frame, the relay calls `zmx resize supa-<surfaceId> <cols> <rows>`. zmx daemon receives the resize and applies `TIOCSWINSZ` on the session PTY.

This requires a zmx enhancement but is the simplest, most maintainable solution. No PTY complexity in the relay. No protocol reimplementation. One CLI command.

**Alternative: Option 4 (direct zmx IPC)** — more work but no zmx CLI changes needed. The relay connects to the zmx daemon's Unix socket and speaks the binary IPC protocol directly. Sends Init with the iOS terminal size, handles Resize requests. Becomes a first-class zmx client.

## iOS-side changes (already implemented, ready for either approach)

- `TerminalSession.sendResize(cols:rows:)` — sends JSON text frame
- `TerminalView` coordinator forwards `sizeChanged` delegate callback → `sendResize`
- `TerminalSession` stores `pendingCols`/`pendingRows`, sends resize after first WebSocket receive
- Output batching (16ms window) to avoid scroll-through on zmx state restore
- `TerminalSessionPool` with paired session + SwiftTerm UIView for instant worktree switching

## Files involved

### macOS (Supacode repo)
- `supacode/Infrastructure/WebAccess/WebAccessTerminalRelay.swift` — relay implementation
- `supacode/Infrastructure/WebAccess/WebAccessServer.swift` — WebSocket route handler
- `docs/asyncapi.yaml` — terminal channel spec (updated for resize text frames)
- `ThirdParty/zmx/src/main.zig` — zmx source (leader/follower protocol)
- `ThirdParty/zmx/src/ipc.zig` — zmx IPC protocol (message format, getTerminalSize)

### iOS (supacode-ios repo)
- `SupacodeViewer/Services/TerminalSession.swift` — WebSocket session + resize sending
- `SupacodeViewer/Services/TerminalSessionPool.swift` — session + UIView persistence pool
- `SupacodeViewer/Views/TerminalView.swift` — UIViewRepresentable wrapping pooled SwiftTerm view
- `SupacodeViewer/Views/ContentView.swift` — terminal container + surface picker
