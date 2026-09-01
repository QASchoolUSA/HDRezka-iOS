/**
 * HDRezka Zero-Cost Cloudflare Worker Edge Gateway
 * 
 * Provides:
 * 1. Global Edge Scraper & Anti-Bot Bypass
 * 2. Real-time Obfuscated Stream Decryption
 * 3. HLS M3U8 Proxy & Header Rewriting
 * 4. Multi-Mirror Health & Latency Testing
 */

export interface Env {}

const DEFAULT_MIRRORS = [
  "https://rezka.ag",
  "https://hdrezka.ag",
  "https://hdrezka.me",
  "https://hdrezka.cm",
  "https://hdrezka.ac"
];

const DEFAULT_HEADERS = {
  "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
  "Accept-Language": "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7",
  "Sec-Ch-Ua": '"Chromium";v="124", "Google Chrome";v="124"',
  "Sec-Ch-Ua-Mobile": "?0",
  "Sec-Ch-Ua-Platform": '"macOS"'
};

// Trash Cipher permutations generator for stream deobfuscation
const TRASH_CHARS = ["@", "#", "!", "^", "$"];
const TRASH_CODES_SET: string[] = [];

// Precompute combinations of lengths 2 and 3
for (const c1 of TRASH_CHARS) {
  for (const c2 of TRASH_CHARS) {
    TRASH_CODES_SET.push(btoa(c1 + c2));
    for (const c3 of TRASH_CHARS) {
      TRASH_CODES_SET.push(btoa(c1 + c2 + c3));
    }
  }
}

function decodeStreamPayload(raw: string): string {
  let cleaned = raw.trim();
  if (cleaned.startsWith("#h")) {
    cleaned = cleaned.substring(2);
  }

  const segments = cleaned.split("//_//");
  let trashString = segments.join("");

  for (const code of TRASH_CODES_SET) {
    trashString = trashString.split(code).join("");
  }

  const remainder = trashString.length % 4;
  if (remainder > 0) {
    trashString += "=".repeat(4 - remainder);
  }

  try {
    return atob(trashString);
  } catch {
    return raw;
  }
}

function parseStreams(decoded: string) {
  const streams: Array<{ quality: string; url: string; isHLS: boolean }> = [];
  const entries = decoded.split(",");

  for (const entry of entries) {
    const trimmed = entry.trim();
    if (!trimmed.startsWith("[") || !trimmed.includes("]")) continue;

    const closingIndex = trimmed.indexOf("]");
    const quality = trimmed.substring(1, closingIndex);
    const urlsPart = trimmed.substring(closingIndex + 1);

    const candidates = urlsPart.split(" or ");
    let targetURL = candidates[0];
    let isHLS = false;

    for (const c of candidates) {
      const clean = c.trim();
      if (clean.includes(".m3u8") || clean.includes(":hls:manifest.m3u8")) {
        targetURL = clean.replace(":hls:manifest.m3u8", "");
        isHLS = true;
        break;
      }
    }

    if (!isHLS) {
      targetURL = candidates[0].trim();
    }

    streams.push({
      quality,
      url: targetURL,
      isHLS
    });
  }

  return streams;
}

function parseSubtitles(raw: string | undefined, codes: Record<string, string> = {}) {
  if (!raw) return [];
  const subtitles: Array<{ code: string; language: string; url: string }> = [];
  const entries = raw.split(",");

  for (const entry of entries) {
    const trimmed = entry.trim();
    if (!trimmed.startsWith("[") || !trimmed.includes("]")) continue;
    const closingIndex = trimmed.indexOf("]");
    const language = trimmed.substring(1, closingIndex);
    const url = trimmed.substring(closingIndex + 1).trim();
    const code = codes[language] || language.toLowerCase().slice(0, 2);

    subtitles.push({ code, language, url });
  }

  return subtitles;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // CORS Headers
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Requested-With",
      "Content-Type": "application/json"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const mirror = DEFAULT_MIRRORS[0];

    // Route: /api/mirrors
    if (url.pathname === "/api/mirrors") {
      const results = await Promise.all(
        DEFAULT_MIRRORS.map(async (m) => {
          const start = Date.now();
          try {
            const resp = await fetch(m, { method: "HEAD", headers: DEFAULT_HEADERS });
            return {
              url: m,
              latencyMs: Date.now() - start,
              isAlive: resp.status < 400
            };
          } catch {
            return { url: m, latencyMs: null, isAlive: false };
          }
        })
      );
      return new Response(JSON.stringify({ mirrors: results }), { headers: corsHeaders });
    }

    // Route: /api/stream
    if (url.pathname === "/api/stream" && request.method === "POST") {
      try {
        const body = await request.json() as {
          id: string;
          translator_id: string;
          season?: number;
          episode?: number;
          action?: string;
        };

        const targetAction = body.season && body.episode ? "get_stream" : (body.action || "get_movie");
        const formData = new URLSearchParams();
        formData.append("id", body.id);
        formData.append("translator_id", body.translator_id);
        formData.append("action", targetAction);
        if (body.season) formData.append("season", String(body.season));
        if (body.episode) formData.append("episode", String(body.episode));

        const rezkaResp = await fetch(`${mirror}/ajax/get_cdn_series/?t=${Date.now()}`, {
          method: "POST",
          headers: {
            ...DEFAULT_HEADERS,
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "X-Requested-With": "XMLHttpRequest",
            "Referer": `${mirror}/`
          },
          body: formData.toString()
        });

        const json = await rezkaResp.json() as any;
        if (!json.success || !json.url) {
          return new Response(JSON.stringify({ error: "Stream not found", raw: json }), {
            status: 404,
            headers: corsHeaders
          });
        }

        const decodedManifest = decodeStreamPayload(json.url);
        const streams = parseStreams(decodedManifest);
        const subtitles = parseSubtitles(json.subtitle, json.subtitle_lns);

        return new Response(
          JSON.stringify({
            streams,
            subtitles,
            season: body.season,
            episode: body.episode,
            translationId: body.translator_id
          }),
          { headers: corsHeaders }
        );
      } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders });
      }
    }

    // Route: /api/proxy-m3u8
    if (url.pathname === "/api/proxy-m3u8") {
      const targetURL = url.searchParams.get("url");
      if (!targetURL) {
        return new Response("Missing url param", { status: 400 });
      }

      const streamResp = await fetch(targetURL, {
        headers: {
          ...DEFAULT_HEADERS,
          "Referer": `${mirror}/`
        }
      });

      const contentType = streamResp.headers.get("Content-Type") || "application/vnd.apple.mpegurl";
      return new Response(streamResp.body, {
        headers: {
          ...corsHeaders,
          "Content-Type": contentType
        }
      });
    }

    // Default status route
    return new Response(
      JSON.stringify({
        service: "HDRezka Edge Gateway",
        status: "healthy",
        version: "1.0.0",
        timestamp: new Date().toISOString()
      }),
      { headers: corsHeaders }
    );
  }
};
