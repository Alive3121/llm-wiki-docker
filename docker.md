# Docker 化说明（llm-atomic-wiki）

> 记录日期：2026-07-24。本文档记录本仓库 Docker 化的产物、验证结果、使用方法与环境相关注意事项。

## 完成内容

仓库根目录新增 4 个文件：

| 文件 | 作用 |
|---|---|
| `Dockerfile` | `node:22-slim` + git + opencode（`npm i -g opencode-ai`，安装版本 1.18.4）。仓库不打进镜像，运行时通过 volume 挂载 |
| `docker-compose.yml` | 定义 wiki 容器：仓库挂到 `/repo`|
| `.env` | 宿主机路径变量+ Azure 资源名。**不含 API key** |
| `opencode.json` | 项目级 opencode 配置，默认模型 |


## 使用方法

```bash
# 启动（在能看到 AZURE_COGNITIVE_SERVICES_RESOURCE_NAME / AZURE_OPENAI_API_KEY
# 这两个环境变量的 shell 里执行，比如当前开发容器）
docker compose up -d

# 交互式会话：进去直接说「执行 DeepQuery：...」「Ingest raw/xxx.md 到 xxx 分支」
docker compose exec wiki opencode

# 无头单次调用（脚本化 / cron 的基础）
docker compose exec wiki opencode run "执行 Query 操作，回答：德川家光是谁"
```

opencode 会自动加载项目根目录的 AGENTS.md，五个 Operation（Ingest / Compile / Query / DeepQuery / Lint）的规范在会话中直接生效。


## 待决定事项

- **`.env` 未被 .gitignore 忽略**。目前只含路径和资源名（无机密），但按惯例不建议入库——需要的话在 `.gitignore` 加一行 `.env`。

