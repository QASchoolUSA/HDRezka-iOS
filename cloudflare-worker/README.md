# Cloudflare Worker Edge Gateway (100% Free Tier)

Zero-cost edge proxy and stream decryptor for HDRezka App. Handles 100,000 requests per day on Cloudflare's free plan.

## Features
- **Anti-Bot & ISP Bypass**: Injects clean browser headers, User-Agent, and Referer headers directly at Cloudflare's global edge nodes.
- **On-Edge Obfuscation Decryption**: Strips trash cipher tokens and base64 decodes HDRezka stream URLs before delivering clean JSON to client devices.
- **HLS M3U8 Proxy**: Proxies HLS video streams with headers when ISP restricts direct CDN connection.
- **Multi-Mirror Latency Check**: Pings `rezka.ag`, `hdrezka.me`, `hdrezka.cm`, and mirrors to find the lowest latency node.

## Quick 1-Minute Deployment

1. Open your terminal in this directory:
   ```bash
   cd cloudflare-worker
   ```
2. Log in to Cloudflare (free account):
   ```bash
   npx wrangler login
   ```
3. Deploy directly to the edge:
   ```bash
   npx wrangler deploy
   ```
4. Copy the resulting Worker URL (e.g. `https://hdrezka-edge-gateway.YOUR_SUBDOMAIN.workers.dev`) and paste it into the **HDRezka App -> Settings -> Cloudflare Edge Gateway** input field!
