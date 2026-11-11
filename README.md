# 云吞插件：Bazarr

开发流程见[插件开发指南](https://github.com/wontonapp/wonton-docs/blob/main/develop.md)。

云吞（Wonton）的 Bazarr 插件：给 Sonarr、Radarr 下载好的剧集和电影自动找字幕，按你选的语言下载后写在视频旁边，播放器里直接可选。

这个插件使用 [LinuxServer.io 镜像](https://docs.linuxserver.io/images/docker-bazarr/)（Docker Hub 名 `linuxserver/bazarr`，amd64 和 arm64，上游 Bazarr 只发布 zip 不发布官方镜像），按清单列表摘要固定。网页经云吞网关访问：Bazarr 自带认证默认关闭，网关挡在前面；想再加一层，在 Bazarr 的 设置 → General → Security 里打开（Basic 或 Form，上游原生设置）。

## Sonarr / Radarr 连接

在云吞里把 `x-wonton.sonarr` / `x-wonton.radarr` 能力接到对应插件时，地址（`WONTON_X_WONTON_SONARR_URL` 等）和 API key（提供方声明 credentials 后的 `WONTON_X_WONTON_SONARR_KEY` 等）由一次性服务写进 Bazarr 配置，写过的侧不再改动；只装其中一个插件时另一侧照常留空，手动填也不受影响。两个能力声明都还在等核心的插件间依赖上线，在那之前手动填地址和 API key。

## 字幕源与外网

字幕来自 Bazarr 内置的字幕站（OpenSubtitles.com、SubtitleCat 等），需要出网权限；字幕站自己的账号在 Bazarr 设置里填，插件不代管。Whisper 自动生成字幕（接 speaches 一类服务）是可选项，本插件不做。

## 通知

Bazarr 的通知是 Apprise URL 型（设置 → 通知），没有 *arr 那种原生 Email 设置，也没有创建通知的接口，所以插件不预配；想要字幕下载进 Wonton 私聊，可在那里自己加一条指向云吞内部邮箱的 mailtos:// 地址。

## 图标来源与许可

`icon.png` 使用 Bazarr 官方标志；来源、处理方式、许可证全文和商标说明见 [NOTICE](NOTICE)。

## 先跑起来

```bash
scripts/dev.sh up
scripts/dev.sh install
```

`up` 在本机起一套云吞，打印它的地址。浏览器打开，用 `scripts/dev.sh token` 输出的用户令牌登录。`install` 先列出插件要的权限，确认后装上，打印 Bazarr 网页的地址。第一次打开后到 设置 → Languages 选字幕语言；字幕源出网需要能访问外网。配置和数据保存在插件数据目录，重装不丢。

## 仓库里有什么

| 路径 | 内容 |
| --- | --- |
| `docker-compose.yml` | 插件本身：Compose 加上 `x-wonton` 清单 |
| `connect-arrs.py` | 一次性服务：把云吞注入的 Sonarr/Radarr 连接写进 Bazarr 配置 |
| `icon.png`、`NOTICE` | 官方图标和它的许可声明 |
| `screenshots/` | 商店详情页里的截图 |
| `scripts/check.sh` | 检查插件包，规则和安装时一样 |
| `scripts/dev.sh` | 开发环境：起一套云吞，装、重装、卸载插件，看日志 |
| `scripts/smoke-probes.sh` | 冒烟对这个插件逐项的探测 |
| `scripts/publish.sh` | 发布一个版本：打 tag、推送 |
| `AGENTS.md` | 给人和 AI 编程代理的规则 |
| `LICENSE`、`NOTICE` | 插件包许可证、上游许可证和商标声明 |
| `.wonton/` | 开发环境的设置、密钥和数据，不提交 |
