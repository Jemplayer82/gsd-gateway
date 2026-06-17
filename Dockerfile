FROM node:24-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/open-gsd/gsd-pi.git /build

WORKDIR /build

RUN node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('package.json','utf8')); p.workspaces=['packages/contracts','packages/rpc-client','packages/mcp-server','packages/cloud-mcp-gateway']; delete p.optionalDependencies; delete p.dependencies; delete p.devDependencies; fs.writeFileSync('package.json',JSON.stringify(p));"

# gsd-pi uses pnpm workspace:* cross-references; drop its pnpm-workspace.yaml so
# pnpm picks up the limited workspace list we set in package.json above.
RUN rm -f pnpm-workspace.yaml && corepack enable pnpm && \
    pnpm install --ignore-scripts --no-audit --no-fund 2>&1 | tail -5

RUN pnpm -C packages/contracts run build && \
    pnpm -C packages/rpc-client run build && \
    pnpm -C packages/mcp-server run build && \
    pnpm -C packages/cloud-mcp-gateway run build

FROM node:24-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/packages/cloud-mcp-gateway/dist/ ./dist/
COPY --from=builder /build/packages/cloud-mcp-gateway/package.json ./

RUN node -e "const p=JSON.parse(require('fs').readFileSync('package.json')); const k=['@modelcontextprotocol/sdk','ws','zod']; p.dependencies=Object.fromEntries(Object.entries(p.dependencies||{}).filter(([n])=>k.includes(n))); delete p.devDependencies; delete p.scripts; require('fs').writeFileSync('package.json',JSON.stringify(p));" && npm install --omit=dev --no-fund --no-audit 2>&1

COPY --from=builder /build/packages/cloud-mcp-gateway/package.json ./
COPY --from=builder /build/packages/contracts/dist/ ./node_modules/@opengsd/contracts/dist/
COPY --from=builder /build/packages/contracts/package.json ./node_modules/@opengsd/contracts/
COPY --from=builder /build/packages/rpc-client/dist/ ./node_modules/@opengsd/rpc-client/dist/
COPY --from=builder /build/packages/rpc-client/package.json ./node_modules/@opengsd/rpc-client/
COPY --from=builder /build/packages/mcp-server/dist/ ./node_modules/@opengsd/mcp-server/dist/
COPY --from=builder /build/packages/mcp-server/package.json ./node_modules/@opengsd/mcp-server/

EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD ["curl", "-sf", "http://localhost:8787/healthz"]
CMD ["node", "dist/cli.js"]
