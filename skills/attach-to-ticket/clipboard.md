# Clipboard fallback

The OS clipboard holds only the last copied image — for several, ask the user to copy each in turn.
A sandboxed shell may block clipboard access (permission or connection errors; on macOS, AppleScript
syntax errors from a valid script): retry outside the sandbox, or fall back to a saved file path.

- macOS: `osascript -e 'set f to open for access POSIX file "<abs-path>.png" with write permission' -e 'write (the clipboard as «class PNGf») to f' -e 'close access f'`, or `pngpaste '<file>'` when installed
- Linux X11: `xclip -selection clipboard -t image/png -o > '<file>'`
- Linux Wayland: `wl-paste -t image/png > '<file>'`
- Windows: `powershell -c "(Get-Clipboard -Format Image).Save('<abs-path>.png')"` — from WSL call
  `powershell.exe` with a Windows path (`wslpath -w`); the path sits inside the calling shell's
  double quotes, so also escape what that shell expands there (bash: `\`, `$`, `` ` ``, `"`)
