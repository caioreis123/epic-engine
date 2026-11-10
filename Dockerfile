FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    git \
    jq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /epic-engine
COPY . /epic-engine

RUN chmod +x /epic-engine/scripts/verify-repo.sh \
    /epic-engine/lib/epic-lib/*.sh \
    /epic-engine/lib/agent-lib/*.sh \
    /epic-engine/skills/agent/*/*.sh

CMD ["bash", "/epic-engine/scripts/verify-repo.sh"]
