# gsd-gateway

A self-hosted Docker container that runs the [open-gsd/gsd-pi](https://github.com/open-gsd/gsd-pi) cloud MCP gateway. This lets you connect Claude or other MCP clients to your local `gsd-browser` instance through a standardized HTTP gateway on port **8787**.

## What it does

- Builds and runs the `cloud-mcp-gateway` package from the open-gsd project
- Acts as the bridge between your AI client and your `gsd-browser-mcp` instance
- Exposes the MCP endpoint at `/mcp` on port **8787**
- Stores auth data in a persistent volume at `/data/auth-store.json`

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/Jemplayer82/gsd-gateway.git
cd gsd-gateway
cp .env.example .env
```

Edit `.env` and set a secret token:

```
GSD_CLOUD_USER_TOKEN=replace-with-a-long-random-secret
```

### 2. Start the container

```bash
docker compose up -d
```

The gateway starts on port **8787** with a health check at `/healthz`.

### 3. Connect your MCP client

Point your MCP client at:

```
http://localhost:8787/mcp
```

Use the token you set in `.env` as your Bearer token.

## Docker Compose

```yaml
services:
  gsd-gateway:
    image: ghcr.io/jemplayer82/gsd-cloud-mcp-gateway:latest
    ports:
      - "8787:8787"
    volumes:
      - gsd-gateway-data:/data
    environment:
      GSD_CLOUD_USER_TOKEN: replace-with-a-long-random-secret
    restart: unless-stopped

volumes:
  gsd-gateway-data:
```

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `GSD_CLOUD_USER_TOKEN` | Yes | Bearer token for authenticating MCP clients at `/mcp` |

## How it works

The image is a multi-stage build:

1. **Build stage** — Clones the `open-gsd/gsd-pi` monorepo, strips it down to only the required packages (`contracts`, `rpc-client`, `mcp-server`, `cloud-mcp-gateway`), installs dependencies, and builds each package
2. **Runtime stage** — Copies only the compiled `dist/` and required `node_modules` into a slim Node.js image

At runtime, `node dist/cli.js` starts the gateway. Auth state is persisted to `/data/auth-store.json`, which is mounted as a Docker volume so it survives container restarts.

## Requirements

- Docker and Docker Compose
- Port 8787 available on the host

## Related

- [gsd-browser-mcp](https://github.com/Jemplayer82/gsd-browser-mcp) — the headless Chrome MCP server this gateway connects to
- [open-gsd/gsd-pi](https://github.com/open-gsd/gsd-pi) — the open-source gsd project this is built from
