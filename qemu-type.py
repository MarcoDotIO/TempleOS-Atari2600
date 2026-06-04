#!/usr/bin/env python3
import socket
import sys
import time


SOCKET_PATH = "qemu-templeos-monitor.sock"
REPEAT_HOLD_THRESHOLD_MS = 250
REPEAT_PULSE_MS = 80
REPEAT_INTERVAL_S = 0.12

SHIFTED = {
    "!": "shift-1",
    "@": "shift-2",
    "#": "shift-3",
    "$": "shift-4",
    "%": "shift-5",
    "^": "shift-6",
    "&": "shift-7",
    "*": "shift-8",
    "(": "shift-9",
    ")": "shift-0",
    "_": "shift-minus",
    "+": "shift-equal",
    ":": "shift-semicolon",
    '"': "shift-apostrophe",
    "<": "shift-comma",
    ">": "shift-dot",
    "?": "shift-slash",
    "~": "shift-grave_accent",
    "{": "shift-bracket_left",
    "}": "shift-bracket_right",
}

PLAIN = {
    " ": "spc",
    "\n": "ret",
    "\r": "ret",
    "\t": "tab",
    "-": "minus",
    "=": "equal",
    ";": "semicolon",
    "'": "apostrophe",
    ",": "comma",
    ".": "dot",
    "/": "slash",
    "`": "grave_accent",
    "\\": "backslash",
    "[": "bracket_left",
    "]": "bracket_right",
}

NAMED = {
    "esc": "esc",
    "spc": "spc",
    "space": "spc",
    "ret": "ret",
    "return": "ret",
    "enter": "ret",
    "fire": "f",
    "jump": "f",
    "f": "f",
    "p0fire": "f",
    "spacefire": "spc",
    "p0spacefire": "spc",
    "enterfire": "ret",
    "p0enterfire": "ret",
    "tab": "tab",
    "up": "up",
    "down": "down",
    "left": "left",
    "right": "right",
    "backspace": "backspace",
    "bs": "backspace",
    "f1": "f1",
    "f2": "f2",
    "f3": "f3",
    "f4": "f4",
    "f5": "f5",
    "f6": "f6",
    "f7": "f7",
    "f8": "f8",
}

NAMED_CHORDS = {
    "leftfire": ["left", "f"],
    "p0leftfire": ["left", "f"],
    "rightfire": ["right", "f"],
    "p0rightfire": ["right", "f"],
    "leftspacefire": ["left", "spc"],
    "p0leftspacefire": ["left", "spc"],
    "rightspacefire": ["right", "spc"],
    "p0rightspacefire": ["right", "spc"],
    "leftenterfire": ["left", "ret"],
    "p0leftenterfire": ["left", "ret"],
    "rightenterfire": ["right", "ret"],
    "p0rightenterfire": ["right", "ret"],
}

PITFALL_RUNUP_MS = 900
PITFALL_JUMP_HOLD_MS = 700
PITFALL_SEQUENCES = {
    "pitfallleftjump": [(["left"], PITFALL_RUNUP_MS), (["left", "f"], PITFALL_JUMP_HOLD_MS)],
    "pitfallrightjump": [(["right"], PITFALL_RUNUP_MS), (["right", "f"], PITFALL_JUMP_HOLD_MS)],
    "pitfallleftspacejump": [(["left"], PITFALL_RUNUP_MS), (["left", "spc"], PITFALL_JUMP_HOLD_MS)],
    "pitfallrightspacejump": [(["right"], PITFALL_RUNUP_MS), (["right", "spc"], PITFALL_JUMP_HOLD_MS)],
    "pitfallleftenterjump": [(["left"], PITFALL_RUNUP_MS), (["left", "ret"], PITFALL_JUMP_HOLD_MS)],
    "pitfallrightenterjump": [(["right"], PITFALL_RUNUP_MS), (["right", "ret"], PITFALL_JUMP_HOLD_MS)],
}

DEFAULT_NAMED_HOLD_MS = {
    "fire": 700,
    "jump": 700,
    "p0fire": 700,
    "space": 700,
    "spacefire": 700,
    "p0spacefire": 700,
    "enter": 700,
    "enterfire": 700,
    "p0enterfire": 700,
    "leftfire": 2200,
    "p0leftfire": 2200,
    "rightfire": 2200,
    "p0rightfire": 2200,
    "leftspacefire": 2200,
    "p0leftspacefire": 2200,
    "rightspacefire": 2200,
    "p0rightspacefire": 2200,
    "leftenterfire": 2200,
    "p0leftenterfire": 2200,
    "rightenterfire": 2200,
    "p0rightenterfire": 2200,
}

DIRECTION_CHORD_PARTS = {"up", "down", "left", "right"}
P0_FIRE_CHORD_PARTS = {
    "f",
    "fire",
    "jump",
    "p0fire",
    "space",
    "spc",
    "spacefire",
    "p0spacefire",
    "enter",
    "ret",
    "return",
    "enterfire",
    "p0enterfire",
}
DIRECTION_FIRE_HOLD_MS = 2200


def key_for(ch):
    if "a" <= ch <= "z" or "0" <= ch <= "9":
        return ch
    if "A" <= ch <= "Z":
        return "shift-" + ch.lower()
    if ch in PLAIN:
        return PLAIN[ch]
    if ch in SHIFTED:
        return SHIFTED[ch]
    raise SystemExit(f"Unsupported character for QEMU sendkey: {ch!r}")


def try_named_key(name):
    low = name.strip().lower()
    return NAMED.get(low)


def split_hold(name):
    for sep in ("@", ":"):
        if sep in name:
            base, hold = name.rsplit(sep, 1)
            hold = hold.strip()
            if hold.isdigit():
                return base.strip(), int(hold)
    return name.strip(), None


def iter_keys(text):
    i = 0
    while i < len(text):
        if text[i] == "{":
            end = text.find("}", i + 1)
            if end != -1:
                name, hold_ms = split_hold(text[i + 1:end])
                low = name.lower()
                if low in ("wait", "sleep", "pause", "delay") and hold_ms is not None:
                    yield [], hold_ms
                    i = end + 1
                    continue
                if low in NAMED_CHORDS:
                    if hold_ms is None:
                        hold_ms = DEFAULT_NAMED_HOLD_MS.get(low)
                    yield NAMED_CHORDS[low], hold_ms
                    i = end + 1
                    continue
                if low in PITFALL_SEQUENCES:
                    for seq_keys, seq_hold_ms in PITFALL_SEQUENCES[low]:
                        if (
                            hold_ms is not None
                            and seq_keys
                            and any(part in P0_FIRE_CHORD_PARTS for part in seq_keys)
                        ):
                            seq_hold_ms = hold_ms
                        yield seq_keys, seq_hold_ms
                    i = end + 1
                    continue
                if "+" in name:
                    parts = [part.strip() for part in low.split("+")]
                    chord = [try_named_key(part) for part in parts]
                    if all(chord):
                        if hold_ms is None:
                            hold_ms = max(
                                [DEFAULT_NAMED_HOLD_MS.get(part, 0) for part in parts]
                            ) or None
                            if (
                                any(part in DIRECTION_CHORD_PARTS for part in parts)
                                and any(part in P0_FIRE_CHORD_PARTS for part in parts)
                            ):
                                hold_ms = max(hold_ms or 0, DIRECTION_FIRE_HOLD_MS)
                        yield chord, hold_ms
                        i = end + 1
                        continue
                elif low in NAMED:
                    if hold_ms is None:
                        hold_ms = DEFAULT_NAMED_HOLD_MS.get(low)
                    yield [NAMED[low]], hold_ms
                    i = end + 1
                    continue
                elif len(name) == 1:
                    yield [key_for(name)], hold_ms
                    i = end + 1
                    continue
        yield [key_for(text[i])], None
        i += 1


def send_command(sock, command):
    sock.sendall((command + "\n").encode("ascii"))
    time.sleep(0.13)
    try:
        sock.recv(4096)
    except TimeoutError:
        pass


def send_key_group(sock, keys, hold_ms=None):
    if not keys:
        if hold_ms:
            time.sleep(hold_ms / 1000.0)
        return
    key_expr = "-".join(keys)
    if hold_ms is None:
        send_command(sock, "sendkey " + key_expr)
        return
    if hold_ms <= REPEAT_HOLD_THRESHOLD_MS:
        send_command(sock, f"sendkey {key_expr} {hold_ms}")
        return

    end_time = time.monotonic() + hold_ms / 1000.0
    while True:
        remaining_ms = int((end_time - time.monotonic()) * 1000)
        if remaining_ms <= 0:
            break
        pulse_ms = min(REPEAT_PULSE_MS, remaining_ms)
        send_command(sock, f"sendkey {key_expr} {pulse_ms}")
        time.sleep(REPEAT_INTERVAL_S)


def main():
    text = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else sys.stdin.read()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.03)
        sock.connect(SOCKET_PATH)
        try:
            sock.recv(4096)
        except TimeoutError:
            pass
        for keys, hold_ms in iter_keys(text):
            send_key_group(sock, keys, hold_ms)


if __name__ == "__main__":
    main()
