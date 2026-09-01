import http from "http";
import https from "https";
import crypto from "crypto";
import zlib from "zlib";
import { URL } from "url";

const PORT = 7890;
const MIRRORS = [
  "https://rezka.ag",
  "https://hdrezka.ag",
  "https://hdrezka.me",
  "https://hdrezka.cm",
  "https://hdrezka.ac"
];

let fastestMirror = "https://rezka.ag";
const mirrorLatencies: Record<string, number | null> = {};
const sessionCookies: Record<string, string> = {};

function decompressBuffer(buffer: Buffer, encoding?: string): string {
  try {
    if (encoding === "gzip") return zlib.gunzipSync(buffer).toString("utf8");
    if (encoding === "deflate") return zlib.inflateSync(buffer).toString("utf8");
    if (encoding === "br") return zlib.brotliDecompressSync(buffer).toString("utf8");
  } catch (e) {}
  return buffer.toString("utf8");
}

function solveAnubis(html: string, originalPath: string, mirror: string, initialCookies?: string[]): Promise<string> {
  return new Promise((resolve) => {
    try {
      const match = html.match(/<script id="anubis_challenge" type="application\/json">([\s\S]*?)<\/script>/);
      if (!match) return resolve("");
      const json = JSON.parse(match[1]);
      const ch = json.challenge;
      const difficulty = ch.difficulty || 2;
      const targetPrefix = "0".repeat(difficulty);
      const start = Date.now();
      let nonce = 0;
      let hash = "";

      while (true) {
        hash = crypto.createHash("sha256").update(ch.randomData + nonce).digest("hex");
        if (hash.startsWith(targetPrefix)) break;
        nonce++;
        if (nonce > 1_000_000) break;
      }
      const elapsed = Date.now() - start;

      const passUrl = `${mirror}/.within.website/x/cmd/anubis/api/pass-challenge?id=${encodeURIComponent(ch.id)}&nonce=${nonce}&response=${hash}&elapsedTime=${elapsed}&redir=${encodeURIComponent(originalPath)}`;
      const initCookieHeader = (initialCookies || []).map(c => c.split(";")[0]).join("; ");

      const req = https.request(passUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
          "Referer": `${mirror}${originalPath}`,
          "Cookie": initCookieHeader
        }
      }, (passRes) => {
        const setCookies = [
          ...(initialCookies || []),
          ...(passRes.headers["set-cookie"] || [])
        ];
        const cookieMap: Record<string, string> = {};
        for (const c of setCookies) {
          const parts = c.split(";")[0].split("=");
          const k = parts[0].trim();
          const v = parts.slice(1).join("=").trim();
          if (v) cookieMap[k] = v;
        }
        const authCookie = Object.entries(cookieMap).map(([k, v]) => `${k}=${v}`).join("; ");
        resolve(authCookie);
      });
      req.on("error", () => resolve(""));
      req.end();
    } catch {
      resolve("");
    }
  });
}

function forwardRequest(targetUrl: URL, method: string, headers: http.IncomingHttpHeaders, body: Buffer | null, res: http.ServerResponse, retryCount = 0) {
  const cookie = sessionCookies[fastestMirror] || "";
  const clientCookie = headers.cookie || "";
  const combinedCookie = [clientCookie, cookie].filter(Boolean).join("; ");

  const reqHeaders: Record<string, string> = {
    host: targetUrl.hostname,
    referer: `${fastestMirror}/`,
    "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "accept-encoding": "gzip, deflate, br"
  };

  if (combinedCookie) {
    reqHeaders["cookie"] = combinedCookie;
  }
  if (headers["content-type"]) {
    reqHeaders["content-type"] = headers["content-type"] as string;
  }
  if (headers["x-requested-with"]) {
    reqHeaders["x-requested-with"] = headers["x-requested-with"] as string;
  }

  const proxyReq = https.request(
    targetUrl,
    {
      method: method,
      headers: reqHeaders
    },
    (proxyRes) => {
      let chunks: Buffer[] = [];
      proxyRes.on("data", (c) => chunks.push(c));
      proxyRes.on("end", async () => {
        const fullBuffer = Buffer.concat(chunks);
        const text = decompressBuffer(fullBuffer, proxyRes.headers["content-encoding"]);

        // If challenge returned and we haven't retried yet, solve and retry immediately!
        if (text.includes("anubis_challenge") && retryCount === 0) {
          const authCookie = await solveAnubis(text, targetUrl.pathname + targetUrl.search, fastestMirror, proxyRes.headers["set-cookie"]);
          if (authCookie) {
            sessionCookies[fastestMirror] = authCookie;
            return forwardRequest(targetUrl, method, headers, body, res, retryCount + 1);
          }
        }

        res.writeHead(proxyRes.statusCode || 200, proxyRes.headers);
        res.end(fullBuffer);
      });
    }
  );

  proxyReq.on("error", (err) => {
    res.writeHead(502, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Proxy error", message: err.message }));
  });

  if (body) {
    proxyReq.write(body);
  }
  proxyReq.end();
}

// Latency checker
async function checkMirrors() {
  for (const mirror of MIRRORS) {
    const start = Date.now();
    try {
      const u = new URL(mirror);
      const req = https.request(
        {
          hostname: u.hostname,
          path: "/",
          method: "HEAD",
          timeout: 4000,
          headers: { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" }
        },
        (res) => {
          mirrorLatencies[mirror] = Date.now() - start;
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

const server = http.createServer(async (req, res) => {
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

  if (reqUrl.pathname === "/proxy") {
    const target = reqUrl.searchParams.get("url");
    if (!target) {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Missing url parameter" }));
      return;
    }

    try {
      const streamUrl = new URL(target);
      const isHttps = streamUrl.protocol === "https:";
      const client = isHttps ? https : http;

      const pReq = client.request(
        streamUrl,
        {
          method: req.method,
          headers: {
            ...req.headers,
            host: streamUrl.hostname,
            referer: `${fastestMirror}/`,
            "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
          }
        },
        (pRes) => {
          res.writeHead(pRes.statusCode || 200, pRes.headers);
          pRes.pipe(res);
        }
      );

      pReq.on("error", (err) => {
        res.writeHead(502, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Stream proxy error", message: err.message }));
      });

      req.pipe(pReq);
      return;
    } catch (err: any) {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Invalid stream url", message: err.message }));
      return;
    }
  }

  // Read request body if present
  let bodyChunks: Buffer[] = [];
  req.on("data", (chunk) => bodyChunks.push(chunk));
  req.on("end", () => {
    const targetUrl = new URL(reqUrl.pathname + reqUrl.search, fastestMirror);
    const body = bodyChunks.length > 0 ? Buffer.concat(bodyChunks) : null;
    forwardRequest(targetUrl, req.method || "GET", req.headers, body, res);
  });
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`[HDRezka Mac Mini Daemon] Running 24/7 on port ${PORT}`);
  console.log(`[HDRezka Mac Mini Daemon] Active Mirror: ${fastestMirror}`);
});
