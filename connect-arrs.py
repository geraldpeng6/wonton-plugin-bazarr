# 把云吞注入的 Sonarr/Radarr 连接（x-wonton.sonarr / x-wonton.radarr 能力）写进
# Bazarr 的 config.yaml（/config/config/config.yaml）。Bazarr 没有对应的环境变量，
# 也只认整段的 ip/port/ssl/base_url，所以地址在这里拆开写。
# 每次创建容器都会重跑，必须幂等：apikey 非空或 use_sonarr/use_radarr 已开（用户配置过、
# 连接过或关掉过）就整侧不动；Bazarr 首次启动会把全部默认键写进 config.yaml，键存在不算配过。
import os
import sys
from urllib.parse import urlparse

import yaml

CONFIG = "/config/config/config.yaml"


def parse_url(url):
    u = urlparse(url)
    if u.scheme not in ("http", "https") or not u.hostname:
        sys.exit(f"能力地址不是 HTTP URL，拒写：{url}")
    if u.port is None:
        sys.exit(f"能力地址缺端口，拒写：{url}")
    return {
        "ssl": u.scheme == "https",
        "ip": u.hostname,
        "port": u.port,
        "base_url": u.path or "/",
    }


def main():
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    if os.path.exists(CONFIG):
        with open(CONFIG) as f:
            data = yaml.safe_load(f) or {}
        if not isinstance(data, dict):
            sys.exit(f"{CONFIG} 不是 YAML 映射，拒写：{type(data).__name__}")
    else:
        data = {}

    changed = False
    for name, url_var, key_var in [
        ("sonarr", "WONTON_X_WONTON_SONARR_URL", "WONTON_X_WONTON_SONARR_KEY"),
        ("radarr", "WONTON_X_WONTON_RADARR_URL", "WONTON_X_WONTON_RADARR_KEY"),
    ]:
        section = data.setdefault(name, {})
        if not isinstance(section, dict):
            sys.exit(f"config.yaml 的 {name} 段不是映射，拒写：{type(section).__name__}")
        # Bazarr 第一次启动就把全部默认键写进 config.yaml（含留空的 apikey），
        # 键在不算配过：apikey 非空、或总开关已打开，才当作用户配置过。
        use = data.get("general", {}).get(f"use_{name}", False)
        if section.get("apikey") or use is True:
            print(f"{name}: config.yaml 里已配置过，不改")
            continue
        url = os.environ.get(url_var, "")
        key = os.environ.get(key_var, "")
        if not url and not key:
            print(f"{name}: 未连接对应插件，跳过")
            continue
        if not url:
            sys.exit(f"{name}: 有 API key 但没有地址（{url_var} 为空），核心注入不完整")
        if not key:
            print(f"{name}: 有地址但提供方没有签发凭据（{key_var} 为空），跳过；"
                  "要自动接线需提供方在 provides 里声明 credentials")
            continue
        conn = parse_url(url)
        section.update(conn)
        section["apikey"] = key
        data.setdefault("general", {})[f"use_{name}"] = True
        changed = True
        print(f"{name}: 已写入 {conn['ip']}:{conn['port']}")

    if changed:
        with open(CONFIG, "w") as f:
            yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)


main()
