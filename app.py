
from flask import Flask
from werkzeug.middleware.proxy_fix import ProxyFix

from .utils import ensure_dirs
from .settings import load_settings
from .routes.main_routes import main_bp
from .routes.admin_routes import admin_bp


def create_app():
    ensure_dirs()
    load_settings()

    app = Flask(__name__, template_folder="templates", static_folder="static")
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_host=1)

    @app.template_filter("timestamp")
    def timestamp_filter(value):
        import time
        try:
            v = float(value)
            return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(v))
        except Exception:
            return "-"

    app.register_blueprint(main_bp)
    app.register_blueprint(admin_bp)

    return app
