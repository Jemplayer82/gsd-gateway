FROM node:24-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/open-gsd/gsd-pi.git /build

WORKDIR /build

# Strip root-level deps that aren't needed; keep gsd-pi's pnpm-workspace.yaml
# intact so pnpm can resolve all internal workspace:* cross-references.
RUN node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('package.json','utf8')); delete p.optionalDependencies; delete p.dependencies; delete p.devDependencies; fs.writeFileSync('package.json',JSON.stringify(p));"

RUN npm install -g pnpm && pnpm install --ignore-scripts

RUN pnpm --filter "@gsd/pi-ai" run build && \
    pnpm --filter "@opengsd/contracts" run build && \
    pnpm --filter "@opengsd/rpc-client" run build && \
    pnpm --filter "@opengsd/mcp-server" run build && \
    pnpm --filter "@opengsd/cloud-mcp-gateway" run build

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
