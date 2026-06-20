# Caddy 版本号，优先由 workflow 通过 build-arg 传入
ARG CADDY_VERSION=2.11.4

# ===== 构建阶段 =====
FROM --platform=$BUILDPLATFORM caddy:${CADDY_VERSION}-builder AS builder

ARG CADDY_VERSION
ARG TARGETOS
ARG TARGETARCH
ARG BUILDARCH

RUN GOOS=$TARGETOS GOARCH=$TARGETARCH \
    xcaddy build v${CADDY_VERSION} \
      --with github.com/caddy-dns/cloudflare \
      --with github.com/WeidiDeng/caddy-cloudflare-ip \
      --output /usr/bin/caddy

# 仅在目标架构与构建架构一致时验证
RUN if [ "$TARGETARCH" = "$BUILDARCH" ]; then \
      /usr/bin/caddy version && \
      /usr/bin/caddy list-modules | grep -i cloudflare; \
    else \
      echo "Skipping verification for cross-compiled binary (${TARGETOS}/${TARGETARCH})"; \
    fi

# ===== 运行阶段 =====
FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
