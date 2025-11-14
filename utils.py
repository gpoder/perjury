
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

# --- i18n helpers ---
import json as _json_i18n
import os as _os_i18n

_LANG_CACHE = {}

def load_language(lang: str = "en"):
    """Load language file from i18n/<lang>.json with simple caching."""
    global _LANG_CACHE
    if lang in _LANG_CACHE:
        return _LANG_CACHE[lang]
    base_dir = _os_i18n.path.dirname(__file__)
    path = _os_i18n.path.join(base_dir, "i18n", f"{lang}.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = _json_i18n.load(f)
    except FileNotFoundError:
        data = {}
    _LANG_CACHE[lang] = data
    return data

def t(key: str, lang: str = "en") -> str:
    """Translate a key using the loaded language dictionary."""
    data = load_language(lang)
    return data.get(key, f"[{key}]")
