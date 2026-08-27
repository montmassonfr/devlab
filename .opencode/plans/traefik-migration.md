# Migration: Traefik Labels → File Provider (Hello Service Pattern)

## Summary

Migrate 8 services from Docker provider labels to declarative file provider YAML configs, matching the existing `hello` service pattern. Each service gets:

1. A **Tailscale sidecar** (`ts-<name>`) using `*ts-base` template
2. **All original Docker networks** moved to the sidecar (so the service inherits them via `network_mode: service:ts-<name>`)
3. **`network_mode: service:ts-<name>`** on the actual service
4. A **file provider config** in `config/traefik/` pointing to the MagicDNS name (`<hostname>.zt.internal`)

The Traefik dashboard labels remain unchanged.

## Pattern Reference: Hello Service

```yaml
# compose.yml
ts-hello:
  <<: *ts-base
  hostname: hello-service
  volumes:
    - hello-state:/var/lib/tailscale
    - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
  networks:
    hello:

hello:
  image: traefik/whoami
  network_mode: service:ts-hello
  depends_on:
    - ts-hello
```

```yaml
# config/traefik/hello-service.yml
http:
  routers:
    hello-service:
      rule: "Host(`hello.lb.localhost`)"
      entryPoints:
        - "websecure"
      service: hello-service
      tls:
        certResolver: "myresolver"
  services:
    hello-service:
      loadBalancer:
        servers:
          - url: "http://hello-service.zt.internal"
        passHostHeader: true
```

Key: `hostname: hello-service` → MagicDNS resolves `hello-service.zt.internal` → file provider routes `hello.lb.localhost` → `http://hello-service.zt.internal`

## Key Principle: Networks Go on the Sidecar

When a service has `network_mode: service:ts-<name>`, it **shares the sidecar's network entirely** — it cannot have its own networks. So **all networks move to the sidecar**:

- `mitmproxy` was on `mitmproxy:` + `proxified:` → `ts-mitmproxy` gets both
- `homepage` was on `homepage:` + `prometheus:` → `ts-homepage` gets both
- `atuin` was on `atuin:` + `atuin-pg:` → `ts-atuin` gets both
- `grafana` was on `grafana:` + `prometheus:` + `loki:` → `ts-grafana` gets all three

This preserves all Docker network connectivity. The service inherits everything the sidecar is on.

## Migration: 8 Services

### Services to Migrate

| Service | Hostname | MagicDNS URL | Domain | Port | Original Networks |
|---------|----------|-------------|--------|------|-------------------|
| mitmproxy | `mitmproxy` | `http://mitmproxy.zt.internal` | mitmweb.lb.localhost | 8081 | mitmproxy, proxified |
| vaultwarden | `vaultwarden` | `http://vaultwarden.zt.internal` | vaultwarden.lb.localhost | 80 | vaultwarden |
| homepage | `homepage` | `http://homepage.zt.internal` | homepage.lb.localhost | 3000 | homepage, prometheus |
| memos | `memos` | `http://memos.zt.internal` | memos.lb.localhost | 5230 | memos |
| atuin | `atuin` | `http://atuin.zt.internal` | atuin.lb.localhost | 8888 | atuin, atuin-pg |
| grafana | `grafana` | `http://grafana.zt.internal` | grafana.lb.localhost | 3000 | grafana, prometheus, loki |
| prometheus | `prometheus` | `http://prometheus.zt.internal` | — | 9090 | prometheus, cadvisor, traefik, coredns |
| loki | `loki` | `http://loki.zt.internal` | — | 3100 | loki |

**Note**: Prometheus and Loki are not exposed through Traefik (no domain/routing). They get sidecars only so grafana can reach them via tailnet (since grafana will also be on a sidecar).

**Excluded**: Traefik dashboard — stays with labels as requested.

### compose.yml Changes

#### A. Add 8 Tailscale sidecars (insert after `ts-hello` block, around line 169)

```yaml
  ts-mitmproxy:
    <<: *ts-base
    hostname: mitmproxy
    volumes:
      - mitmproxy-state:/var/lib/tailscale
      - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    networks:
      mitmproxy:
      proxified:
        ipv4_address: 172.31.253.3

  ts-vaultwarden:
    <<: *ts-base
    hostname: vaultwarden
    volumes:
      - vaultwarden-state:/var/lib/tailscale
      - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    networks:
      vaultwarden:

  ts-homepage:
    <<: *ts-base
    hostname: homepage
    volumes:
      - homepage-state:/var/lib/tailscale
      - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    networks:
      homepage:
      prometheus:

  ts-memos:
    <<: *ts-base
    hostname: memos
    volumes:
      - memos-state:/var/lib/tailscale
      - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    networks:
      memos:

  ts-atuin:
    <<: *ts-base
    hostname: atuin
    volumes:
      - atuin-state:/var/lib/tailscale
      - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    networks:
      atuin:
      atuin-pg:

  ts-grafana:
    <<: *ts-base
    hostname: grafana
    volumes:
      - grafana-state:/var/lib/tailscale
      - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    networks:
      grafana:
      prometheus:
      loki:

  ts-prometheus:
    <<: *ts-base
    hostname: prometheus
    volumes:
      - prometheus-state:/var/lib/tailscale
      - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    networks:
      prometheus:
      cadvisor:
      traefik:
      coredns:

  ts-loki:
    <<: *ts-base
    hostname: loki
    volumes:
      - loki-state:/var/lib/tailscale
      - "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    networks:
      loki:
        ipv4_address: 172.31.254.1
```

#### B. Add 8 volume definitions (add to existing volumes section, around line 363)

```yaml
  mitmproxy-state:
  vaultwarden-state:
  homepage-state:
  memos-state:
  atuin-state:
  grafana-state:
  prometheus-state:
  loki-state:
```

#### C. Update each service to use sidecar pattern

Add `network_mode: service:ts-<name>` and `depends_on: [ts-<name>]`. **Remove all `networks:` blocks** from the services (networks are now on the sidecars).

**mitmproxy** (line 171):
- Add: `network_mode: service:ts-mitmproxy`, `depends_on: [ts-mitmproxy]`
- Remove: entire `networks:` block (lines 177-181)

**vaultwarden** (line 199):
- Add: `network_mode: service:ts-vaultwarden`, `depends_on: [ts-vaultwarden]`
- Remove: `networks:` block (lines 215-216)

**homepage** (line 218):
- Add: `network_mode: service:ts-homepage`, `depends_on: [ts-homepage]`
- Remove: `networks:` block (lines 236-238)

**memos** (line 239):
- Add: `network_mode: service:ts-memos`, `depends_on: [ts-memos]`
- Remove: `networks:` block (lines 255-256)

**atuin** (line 258):
- Add: `network_mode: service:ts-atuin`, `depends_on: [ts-atuin]`
- Remove: `networks:` block (lines 282-284)

**grafana** (line 340):
- Add: `network_mode: service:ts-grafana`, `depends_on: [ts-grafana]`
- Remove: `networks:` block (lines 359-362)

**prometheus** (line 327):
- Add: `network_mode: service:ts-prometheus`, `depends_on: [ts-prometheus]`
- Remove: `networks:` block (lines 334-338)

**loki** (line 315):
- Add: `network_mode: service:ts-loki`, `depends_on: [ts-loki]`
- Remove: `networks:` block (lines 323-325)

#### D. Remove labels from 8 services

Remove all `labels:` blocks:
1. **mitmproxy** (lines 182-188)
2. **vaultwarden** (lines 208-214)
3. **homepage** (lines 229-235)
4. **memos** (lines 248-254)
5. **atuin** (lines 275-281)
6. **grafana** (lines 352-358)
7. **prometheus** — no labels to remove (prometheus has no labels)
8. **loki** — no labels to remove (loki has no labels)

**Do NOT remove** the traefik dashboard labels (lines 118-125).

#### E. Remove `traefik:` network from `ts-traefik` sidecar

Since traefik-labeled services are no longer on the `traefik` network, remove `traefik:` from `ts-traefik`'s network list (line 78).

**Exception**: `ts-prometheus` still needs `traefik:` network so it can scrape `traefik:8080`. So `traefik:` stays on `ts-traefik` AND `ts-prometheus`.

The `drawio:` network can be removed from `ts-traefik` if drawio is not used or not migrated.

#### F. Update existing networks

All networks remain as-is in the `networks:` section. They are now used only by the `ts-*` sidecars.

**Static IPs preserved**: The `proxified:` network had `ipv4_address: 172.31.253.3` for mitmproxy — moved to `ts-mitmproxy`. The `loki:` network had `ipv4_address: 172.31.254.1` — moved to `ts-loki`.

### New File Provider Configs

Each file goes in `config/traefik/` and follows the exact same structure as `hello-service.yml`:

#### `config/traefik/mitmproxy-service.yml`
```yaml
http:
  routers:
    mitmproxy:
      rule: "Host(`mitmweb.lb.localhost`)"
      entryPoints:
        - "websecure"
      service: mitmproxy
      tls:
        certResolver: "myresolver"
  services:
    mitmproxy:
      loadBalancer:
        servers:
          - url: "http://mitmproxy.zt.internal"
        passHostHeader: true
```

#### `config/traefik/vaultwarden-service.yml`
```yaml
http:
  routers:
    vaultwarden:
      rule: "Host(`vaultwarden.lb.localhost`)"
      entryPoints:
        - "websecure"
      service: vaultwarden
      tls:
        certResolver: "myresolver"
  services:
    vaultwarden:
      loadBalancer:
        servers:
          - url: "http://vaultwarden.zt.internal"
        passHostHeader: true
```

#### `config/traefik/homepage-service.yml`
```yaml
http:
  routers:
    homepage:
      rule: "Host(`homepage.lb.localhost`)"
      entryPoints:
        - "websecure"
      service: homepage
      tls:
        certResolver: "myresolver"
  services:
    homepage:
      loadBalancer:
        servers:
          - url: "http://homepage.zt.internal"
        passHostHeader: true
```

#### `config/traefik/memos-service.yml`
```yaml
http:
  routers:
    memos:
      rule: "Host(`memos.lb.localhost`)"
      entryPoints:
        - "websecure"
      service: memos
      tls:
        certResolver: "myresolver"
  services:
    memos:
      loadBalancer:
        servers:
          - url: "http://memos.zt.internal"
        passHostHeader: true
```

#### `config/traefik/atuin-service.yml`
```yaml
http:
  routers:
    atuin:
      rule: "Host(`atuin.lb.localhost`)"
      entryPoints:
        - "websecure"
      service: atuin
      tls:
        certResolver: "myresolver"
  services:
    atuin:
      loadBalancer:
        servers:
          - url: "http://atuin.zt.internal"
        passHostHeader: true
```

#### `config/traefik/grafana-service.yml`
```yaml
http:
  routers:
    grafana:
      rule: "Host(`grafana.lb.localhost`)"
      entryPoints:
        - "websecure"
      service: grafana
      tls:
        certResolver: "myresolver"
  services:
    grafana:
      loadBalancer:
        servers:
          - url: "http://grafana.zt.internal"
        passHostHeader: true
```

## Existing Config (unchanged)

Traefik file provider already enabled in `compose.yml:97-98`:
```
--providers.file.directory=/config
--providers.file.watch=true
```
Mounted at `/config` in `compose.yml:113`. No changes needed.

## ACL Update

The `SERVICE_PREAUTH_KEY` was created with `tag:svc`, so all sidecars inherit the tag. No `TS_TAGS` needed.

Update line 33 of `config/headscale/acl.json`:

```
# Before:
"dst": ["tag:svc:3000,5000,8080,80"]

# After:
"dst": ["tag:svc:80,3000,5230,8081,8888"]
```

Remove unused ports: `5000`, `8080`. Add new ports: `5230` (memos), `8081` (mitmproxy), `8888` (atuin).

Port 3000 is kept for homepage/grafana. Prometheus (9090) and Loki (3100) are not exposed through Traefik so they don't need ACL entries — they're only reachable via tailnet for internal scraping/datasource access.

## Verification

After migration, all routing should work via:
- `Host(\`*.lb.localhost\`)` → Traefik → MagicDNS `<hostname>.zt.internal` → Tailscale sidecar → service
- TLS via ACME (step-ca internal CA) on `websecure` entrypoint
- Grafana → Prometheus/Loki via tailnet (all three on shared networks via sidecars)
- Homepage → Prometheus discovery via tailnet (both on `prometheus:` network via sidecars)
- Prometheus → Cadvisor/Traefik/CoreDNS scraping via tailnet (all on shared networks via sidecars)
