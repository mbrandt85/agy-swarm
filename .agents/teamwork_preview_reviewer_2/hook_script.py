import sys, json, re, subprocess, os, shlex

try:
    raw = sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

cmd = ""
if isinstance(data, dict):
    for obj in [data.get("toolCall"), data.get("tool_call"), data.get("step"), data]:
        if isinstance(obj, dict):
            for arg_key in ["args", "input", "parameters"]:
                sub = obj.get(arg_key)
                if isinstance(sub, dict):
                    for k in ["CommandLine", "commandLine", "command"]:
                        val = sub.get(k)
                        if isinstance(val, str) and val.strip():
                            cmd = val
                            break
                if cmd:
                    break
        if cmd:
            break

if not cmd and "\"CommandLine\"" in raw:
    idx = raw.find("\"CommandLine\"")
    colon = raw.find(":", idx)
    q1 = raw.find("\"", colon)
    if q1 != -1:
        q2 = q1 + 1
        while q2 < len(raw):
            if raw[q2] == "\"" and raw[q2 - 1] != "\\":
                break
            q2 += 1
        if q2 < len(raw):
            try:
                cmd = json.loads(raw[q1 : q2 + 1])
            except Exception:
                cmd = raw[q1 + 1 : q2]

def is_test_run(c):
    if not c:
        return False
    segments = re.split(r"&&|\|\||;|\||\n", c)
    for seg in segments:
        seg = seg.strip()
        if not seg:
            continue
        try:
            tokens = shlex.split(seg)
        except Exception:
            tokens = seg.split()
        if not tokens:
            continue
        idx = 0
        while idx < len(tokens) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=.*", tokens[idx]):
            idx += 1
        while idx < len(tokens) and tokens[idx] in ("sudo", "env", "time", "exec", "nohup"):
            idx += 1
            while idx < len(tokens) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=.*", tokens[idx]):
                idx += 1
        if idx >= len(tokens):
            continue
        exe = tokens[idx].rsplit("/", 1)[-1]
        if exe == "agy-test-runner.sh":
            return True
        if exe in ("bash", "sh", "zsh", "dash", "ksh"):
            idx += 1
            while idx < len(tokens) and tokens[idx].startswith("-") and tokens[idx] != "-c":
                idx += 1
            if idx < len(tokens):
                if tokens[idx] == "-c" and idx + 1 < len(tokens):
                    if is_test_run(tokens[idx + 1]):
                        return True
                elif tokens[idx].rsplit("/", 1)[-1] == "agy-test-runner.sh":
                    return True
    return False

if is_test_run(cmd):
    err = data.get("error") if isinstance(data, dict) else None
    ec = data.get("exitCode", data.get("exit_code")) if isinstance(data, dict) else None
    raw_lower = raw.lower()
    failed = False
    if err or (isinstance(ec, int) and ec != 0):
        failed = True
    elif "[fail] test failures detected!" in raw_lower:
        failed = True
    elif bool(re.search(r"exit(ed with)? (code|status) [1-9]", raw_lower)):
        failed = True
    elif bool(re.search(r"\"exit_code\"\s*:\s*[1-9]", raw)):
        failed = True
    elif bool(re.search(r"\"exitCode\"\s*:\s*[1-9]", raw)):
        failed = True
    if not failed:
        root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip() or "."
        env = os.environ.copy()
        env.setdefault("GIT_AUTHOR_NAME", "Antigravity Agent")
        env.setdefault("GIT_AUTHOR_EMAIL", "agent@antigravity")
        env.setdefault("GIT_COMMITTER_NAME", "Antigravity Agent")
        env.setdefault("GIT_COMMITTER_EMAIL", "agent@antigravity")
        subprocess.run(["git", "add", "-A"], cwd=root, check=False)
        if subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=root).returncode != 0:
            subprocess.run(["git", "-c", "commit.gpgsign=false", "commit", "-m", "chore: auto-commit after green test gate"], cwd=root, env=env, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print("{}")
