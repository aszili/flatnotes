import os
import shutil
import sys

IMMUTABLE_ROOT = "/opt/flatnotes"
RUNTIME_ROOT = "/state"

SRC = f"{IMMUTABLE_ROOT}/client/dist"
DST = f"{RUNTIME_ROOT}/client/dist"

os.makedirs(DST, exist_ok=True)

if not os.path.exists(os.path.join(DST, "index.html")):
    shutil.copytree(SRC, DST, dirs_exist_ok=True)

host = os.getenv("FLATNOTES_HOST", "0.0.0.0")
port = os.getenv("FLATNOTES_PORT", "8080")

os.chdir(RUNTIME_ROOT)

cmd = [
    "python",
    "-m", "uvicorn",
    "server.main:app",
    "--host", host,
    "--port", port,
]

os.execvp(cmd[0], cmd)
