
import os
import json
import time

BASE_DIR = os.path.dirname(__file__)
DATA_DIR = os.path.join(BASE_DIR, "data")
BLOCKS_DIR = os.path.join(DATA_DIR, "blocks")
TOKENS_DIR = os.path.join(DATA_DIR, "tokens")
SETTINGS_FILE = os.path.join(DATA_DIR, "settings.json")
GLOBAL_BLOCK_FILE = os.path.join(DATA_DIR, "global.json")
LOG_FILE = os.path.join(DATA_DIR, "log.json")
IMAGE_PATH = os.path.join(BASE_DIR, "image.png")


def ensure_dirs():
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(BLOCKS_DIR, exist_ok=True)
    os.makedirs(TOKENS_DIR, exist_ok=True)


def load_json(path, default=None):
    if default is None:
        default = {}
    if not os.path.exists(path):
        return default
    try:
        with open(path, "r") as f:
            return json.load(f)
    except Exception:
        return default


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


def load_log():
    if not os.path.exists(LOG_FILE):
        return []
    try:
        with open(LOG_FILE, "r") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []


def save_log(entries):
    with open(LOG_FILE, "w") as f:
        json.dump(entries, f, indent=2)


def log_event(event, ip=None, extra=None):
    entries = load_log()
    entry = {
        "ts": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()),
        "event": event,
        "ip": ip,
        "extra": extra or {},
    }
    entries.append(entry)
    # keep last 500
    entries = entries[-500:]
    save_log(entries)
