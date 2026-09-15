import sys, json, re, subprocess, os, shlex, tempfile, shutil

hook_python = """
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
if not cmd:
    m = re.search(r'"CommandLine"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"', raw)
    if m:
        try:
            cmd = json.loads('"' + m.group(1) + '"')
        except Exception:
            cmd = m.group(1)

def is_test_run(c):
    if not c:
        return False
    segments = re.split(r"&&|\\|\\||;|\\||\\n", c)
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
    elif bool(re.search(r'"exit_code"\\s*:\\s*[1-9]', raw)):
        failed = True
    elif bool(re.search(r'"exitCode"\\s*:\\s*[1-9]', raw)):
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
"""

tmp = tempfile.mkdtemp()
repo = tmp + "/repo"
subprocess.run(["git", "init", repo], check=True)
subprocess.run(["git", "config", "user.name", "Tester"], cwd=repo, check=True)
subprocess.run(["git", "config", "user.email", "tester@test.com"], cwd=repo, check=True)
with open(repo + "/init.txt", "w") as f:
    f.write("init")
subprocess.run(["git", "add", "."], cwd=repo, check=True)
subprocess.run(["git", "commit", "-m", "init"], cwd=repo, check=True)

def run_hook(payload_str, cwd=repo):
    cmd = ["python3", "-c", hook_python]
    p = subprocess.run(cmd, input=payload_str, cwd=cwd, text=True, capture_output=True)
    assert p.stdout.strip() == "{}", f"Hook output not {{}}: {repr(p.stdout)}, stderr: {p.stderr}"
    return p

# 1. Green test runner run commits pending changes
with open(repo + "/green.txt", "w") as f:
    f.write("green")
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "bash scripts/agy-test-runner.sh"}}}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "green.txt" not in status, "Green run did not commit green.txt!"
last_msg = subprocess.run(["git", "log", "-1", "--pretty=%B"], cwd=repo, capture_output=True, text=True).stdout.strip()
assert last_msg == "chore: auto-commit after green test gate", f"Commit msg wrong: {last_msg}"
print("✓ Scenario 1 passed (Green test runner commits)")

# 2. cat scripts/agy-test-runner.sh must NOT commit
with open(repo + "/pending.txt", "w") as f:
    f.write("pending")
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "cat scripts/agy-test-runner.sh"}}}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" in status, "cat command erroneously committed pending changes!"
print("✓ Scenario 2 passed (cat scripts/agy-test-runner.sh does not commit)")

# 3. git log with output mentioning scripts/agy-test-runner.sh must NOT commit
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "git log"}}, "content": "modified scripts/agy-test-runner.sh"}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" in status, "git log erroneously committed pending changes!"
print("✓ Scenario 3 passed (git log does not commit)")

# 4. git diff must NOT commit
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "git diff scripts/agy-test-runner.sh"}}}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" in status, "git diff erroneously committed pending changes!"
print("✓ Scenario 4 passed (git diff does not commit)")

# 5. Failed run with error field must NOT commit
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "bash scripts/agy-test-runner.sh"}}, "error": "exit status 1"}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" in status, "failed run with error field committed!"
print("✓ Scenario 5 passed (error field rejects commit)")

# 6. Failed run with [FAIL] in content must NOT commit
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "bash scripts/agy-test-runner.sh"}}, "content": "[FAIL] TEST FAILURES DETECTED! (Exit Code: 1)"}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" in status, "failed run with [FAIL] committed!"
print("✓ Scenario 6 passed ([FAIL] rejects commit)")

# 7. Failed run with non-zero exit code text must NOT commit
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "bash scripts/agy-test-runner.sh"}}, "content": "The command exited with code 1."}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" in status, "failed run with exit code text committed!"
print("✓ Scenario 7 passed (exit code text rejects commit)")

# 8. Failed run with exitCode int must NOT commit
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "bash scripts/agy-test-runner.sh"}}, "exitCode": 1}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" in status, "failed run with exitCode committed!"
print("✓ Scenario 8 passed (exitCode int rejects commit)")

# 9. make lint must NOT commit
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "make lint"}}}))
status = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" in status, "make lint committed!"
print("✓ Scenario 9 passed (make lint does not commit)")

# 10. Missing git user.name / user.email commits with fallback
repo_no_user = tmp + "/repo_no_user"
subprocess.run(["git", "init", repo_no_user], check=True)
with open(repo_no_user + "/file.txt", "w") as f:
    f.write("content")
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "bash scripts/agy-test-runner.sh"}}}), cwd=repo_no_user)
status_no_user = subprocess.run(["git", "status", "--porcelain"], cwd=repo_no_user, capture_output=True, text=True).stdout
assert "file.txt" not in status_no_user, "Commit failed when git identity was missing!"
print("✓ Scenario 10 passed (Missing git identity handled gracefully)")

# 11. commit.gpgsign = true commits with override
subprocess.run(["git", "config", "commit.gpgsign", "true"], cwd=repo)
run_hook(json.dumps({"toolCall": {"name": "run_command", "args": {"CommandLine": "bash scripts/agy-test-runner.sh"}}}))
status_gpg = subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout
assert "pending.txt" not in status_gpg, "Commit failed when commit.gpgsign = true!"
print("✓ Scenario 11 passed (commit.gpgsign = true handled)")

# 12. Malformed JSON on stdin
run_hook("not json {}{{{")
print("✓ Scenario 12 passed (Malformed JSON handled)")

shutil.rmtree(tmp)
print("\nALL 12 HOOK SCENARIOS PASSED PERFECTLY!")
