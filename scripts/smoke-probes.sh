# shellcheck shell=bash
# scripts/smoke.sh 的一项一项探测，跟着插件走。没写的项会 FAIL 并给出写法，不会默认放行。
#
# 变量别叫 state：shellcheck 把这份文件连着 probes.sh 一起分析，probes.sh 自己也读一个 dev.sh 提供的 state；
# 子壳体函数（fn() ( … )）里给 state 赋值，SC2031 就报在 probes.sh 上，CI 红。
#
# 变量：SMOKE_WEB_URL 是应用的网页入口（套件已去尾斜杠，但可能带路径，比如 SSO 登录页）；
#       拼 API 路径用 SMOKE_WEB_ORIGIN（只有 scheme://host:port，入口的路径不掺进来），别直接接在 SMOKE_WEB_URL 后面。
#
# 页面：web_assert 从标准输入读页面，命中的确是应用的真实页面时返回 0。
# 身份：IDENTITY_NA=1——Bazarr 自带认证默认关闭（auth.type=None，网关挡在前面），应用没有用户体系可断言。
# 工具：清单没有 mcp，套件按“清单没有 mcp”记 N/A，这里不用写。
# 数据： Bazarr 的用户数据经它自己的 API 读写；API key（auth.apikey）由应用注在首页 HTML 的
#       window.Bazarr 里，探针从页面取出来当 X-API-KEY 用，不用进容器。

web_assert() { grep -q '<title>Bazarr</title>'; }

export IDENTITY_NA=1
export SMOKE_NOTE="Bazarr 自带认证默认关闭（sso: none），应用没有用户体系可断言"

_bazarr_key() {
  local page
  page="$(dweb /)" || { echo "拿不到首页：$page"; return 1; }
  sed -n 's/.*"apiKey": "\([0-9a-f]\{32\}\)".*/\1/p' <<<"$page" | head -1
}

_bazarr_api() { # <方法> <路径> [<curl 参数>…]
  local key method="$1" path="$2"
  shift 2
  key="$(_bazarr_key)" || return 1
  [[ -n "$key" ]] || { echo "首页 HTML 里没有注入 apiKey"; return 1; }
  curl_t "$SMOKE_API_MAX_TIME" "$SMOKE_WEB_ORIGIN$path" --noproxy '*' \
    -b "$SMOKE_JAR" -H "X-API-KEY: $key" -X "$method" "$@"
}

data_write() { # 把随机标记写进一条通知提供方的 URL，标记原样存进 $SMOKE_STATE
  local marker="wonton-smoke-$RANDOM$RANDOM" providers name
  providers="$(_bazarr_api GET /api/system/settings)" || { echo "读设置失败：$providers"; return 1; }
  name="$(jq -r '.notifications.providers[0].name // empty' <<<"$providers")"
  [[ -n "$name" ]] || { echo "通知提供方列表是空的，没有可写的行：$(head -c 200 <<<"$providers")"; return 1; }
  _bazarr_api POST /api/system/settings \
    --data-urlencode "notifications-providers=$(jq -cn --arg name "$name" --arg url "$marker" \
      '{name: $name, enabled: true, url: $url}')" \
    >/dev/null || { echo "写通知提供方失败"; return 1; }
  printf '%s' "$marker" > "$SMOKE_STATE"
}

data_check() {
  local marker resp url
  marker="$(cat "$SMOKE_STATE")"
  [[ -n "$marker" ]] || { echo "\$SMOKE_STATE 里没有标记"; return 1; }
  resp="$(_bazarr_api GET /api/system/settings)" || { echo "读设置失败：$resp"; return 1; }
  url="$(jq -r --arg marker "$marker" \
    '[.notifications.providers[] | select(.url == $marker)] | length' <<<"$resp")"
  if [[ "$url" -ge 1 ]]; then
    return 0
  fi
  echo "通知提供方里找不到标记 $marker，现在的 URL：$(jq -r '[.notifications.providers[].url] | map(select(. != null and . != ""))' <<<"$resp" | head -c 300)"
  return 1
}
