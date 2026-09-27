FROM node:22-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git bash ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai

# 仓库不打进镜像，运行时通过 volume 挂载到 /repo（见 docker-compose.yml）
WORKDIR /repo

CMD ["sleep", "infinity"]
