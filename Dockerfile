# syntax=docker/dockerfile:1

# Caddy 版本号,优先由 workflow 通过 --build-arg 传入
ARG CADDY_VERSION=2.11.4

# ===== 构建阶段:固定在本机架构上交叉编译 =====
# --platform=$BUILDPLATFORM 确保构建阶段始终在 runner 原生架构(amd64)上执行,
# 通过 Go 的交叉编译能力(设置 GOOS/GOARCH)生成目标架构二进制,无需 QEMU 模拟
FROM --platform=$BUILDPLATFORM golang:alpine AS builder

ARG CADDY_VERSION
ARG TARGETOS TARGETARCH
ARG BUILDOS BUILDARCH

# 安装构建工具 xcaddy
RUN apk add --no-cache git ca-certificates && \
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# 交叉编译目标架构的 Caddy 二进制
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH \
    xcaddy build v${CADDY_VERSION} \
    --with github.com/caddy-dns/cloudflare \
    --output /usr/bin/caddy

# 验证:仅在原生架构(构建平台 == 目标平台)时执行,交叉编译时跳过
RUN if [ "$TARGETARCH" = "$BUILDARCH" ]; then \
      /usr/bin/caddy version && \
      /usr/bin/caddy list-modules | grep -i cloudflare; \
    else \
      echo "Skipping verification for cross-compiled binary (${TARGETOS}/${TARGETARCH})"; \
    fi

# ===== 运行阶段:使用官方 Caddy alpine 镜像作为运行时 =====
FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
