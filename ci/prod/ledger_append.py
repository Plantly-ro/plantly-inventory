#!/usr/bin/env python3
"""Append a one-line deploy record to quadlets plantly-prod/DEPLOYED.md via the
GitLab files API, then READS IT BACK to verify the line landed. Exits non-zero
on any failure — a broken DEPLOY_LEDGER_TOKEN once 403'd silently for 7 weeks
(swallowed by `|| echo non-fatal`); deploy.sh now fails the job at the very end
(after the app is flipped, smoked and safe) when this script fails."""
import datetime
import json
import os
import sys
import urllib.parse
import urllib.request

GITLAB = os.environ.get("CI_SERVER_URL", "https://gitlab.urundead.win")
PROJECT = os.environ.get("LEDGER_PROJECT_ID", "34")
TOKEN = os.environ["DEPLOY_LEDGER_TOKEN"]
BRANCH = os.environ.get("LEDGER_BRANCH", "main")
PATH = urllib.parse.quote("plantly-prod/DEPLOYED.md", safe="")

message = sys.argv[1]
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
line = f"\n**{stamp} [auto-deploy]:** {message}\n"

base = f"{GITLAB}/api/v4/projects/{PROJECT}/repository/files/{PATH}"
headers = {"PRIVATE-TOKEN": TOKEN, "Content-Type": "application/json"}

req = urllib.request.Request(f"{base}/raw?ref={BRANCH}", headers=headers)
content = urllib.request.urlopen(req, timeout=30).read().decode()

payload = json.dumps({
    "branch": BRANCH,
    "content": content + line,
    "commit_message": f"deploy ledger: {message[:72]}",
}).encode()
req = urllib.request.Request(base, data=payload, headers=headers, method="PUT")
urllib.request.urlopen(req, timeout=30)

# Read-back verification: the PUT succeeding is not enough — verify the line
# is actually in the file on the target branch before claiming success.
req = urllib.request.Request(f"{base}/raw?ref={BRANCH}", headers=headers)
check = urllib.request.urlopen(req, timeout=30).read().decode()
if line not in check:
    print("ledger: append did not land (read-back mismatch)", file=sys.stderr)
    sys.exit(1)
print("ledger: appended + verified")
