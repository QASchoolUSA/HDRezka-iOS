/**
 * Mac Mini 24/7 Companion Daemon
 * 
 * Runs continuously on your Mac Mini to provide:
 * 1. Residential Network Proxy & Stream Cache
 * 2. 24/7 Mirror Health Monitoring & Discovery
 * 3. Local High-Speed API Gateway for Home Apple Devices
 */

import http from "http";
import https from "https";
import { URL } from "url";

const PORT = 7890;
const MIRRORS = [
  "https://rezka.ag",
  "https://hdrezka.ag",
  "https://hdrezka.me",
  "https://hdrezka.cm",
  "https://hdrezka.ac"
];

let fastestMirror = MIRRORS[0];
let mirrorLatencies: Record<string, number | null> = {};

// Periodic Mirror Health Checker every 60 seconds
async function checkMirrors() {
  for (const mirror of MIRRORS) {
    const start = Date.now();
    try {
      const parsed = new URL(mirror);
      const req = https.request(
        {
          hostname: parsed.hostname,
          port: 443,
          path: "/",
          method: "HEAD",
          timeout: 4000,
          headers: {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
          }
        },
        (res) => {
          if (res.statusCode && res.statusCode < 400) {
            mirrorLatencies[mirror] = Date.now() - start;
          } else {
            mirrorLatencies[mirror] = null;
          }
        }
      );
      req.on("error", () => {
        mirrorLatencies[mirror] = null;
      });
      req.end();
    } catch {
      mirrorLatencies[mirror] = null;
    }
  }

  // Pick fastest alive mirror
  let best = fastestMirror;
  let minMs = Infinity;
  for (const [m, ms] of Object.entries(mirrorLatencies)) {
    if (ms !== null && ms < minMs) {
      minMs = ms;
      best = m;
    }
  }
  fastestMirror = best;
}

setInterval(checkMirrors, 60_000);
checkMirrors();

const server = http.createServer((req, res) => {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "*");

  if (req.method === "OPTIONS") {
    res.writeHead(200);
    res.end();
    return;
  }

  const reqUrl = new URL(req.url || "/", `http://localhost:${PORT}`);

  if (reqUrl.pathname === "/status") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        status: "online",
        fastestMirror,
        latencies: mirrorLatencies,
        timestamp: new Date().toISOString()
      })
    );
    return;
  }

  // Proxy / Forward request to active mirror
  const targetUrl = new URL(reqUrl.pathname + reqUrl.search, fastestMirror);
  const proxyReq = https.request(
    targetUrl,
    {
      method: req.method,
      headers: {
        ...req.headers,
        host: targetUrl.hostname,
        referer: `${fastestMirror}/`,
        "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
      }
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode || 200, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on("error", (err) => {
    res.writeHead(502, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Proxy error", message: err.message }));
  });

  req.pipe(proxyReq);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`[HDRezka Mac Mini Daemon] Running 24/7 on port ${PORT}`);
  console.log(`[HDRezka Mac Mini Daemon] Active Mirror: ${fastestMirror}`);
});
