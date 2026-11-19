// CORS for the Edge Functions the rower web page calls from a browser (username-auth, delete-account).
//
// These calls carry auth, so the request's Origin is echoed back only when it is on the list below
// (never "*"). The list is the live site (with and without www), the local dev server, and any comma-separated origins in
// the WEB_ORIGINS environment variable (the staging web address).

const BASE_ORIGINS = ["https://rowingpals.com", "https://www.rowingpals.com", "http://localhost:5173"]

function allowedOrigins(): string[] {
  const extra = (Deno.env.get("WEB_ORIGINS") ?? "")
    .split(",")
    .map((o) => o.trim())
    .filter((o) => o.length > 0)
  return [...BASE_ORIGINS, ...extra]
}

/** The CORS headers for a request from `origin`. Allow-Origin is present only for an allowed origin. */
export function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  }
  if (origin && allowedOrigins().includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin
  }
  return headers
}

/**
 * Wraps a request handler: answers OPTIONS with 200 and the CORS headers, and adds the CORS headers
 * to every other response, errors included. The handler itself is otherwise untouched.
 */
export function withCors(handler: (req: Request) => Response | Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    const cors = corsHeaders(req.headers.get("Origin"))
    if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: cors })
    let res: Response
    try {
      res = await handler(req)
    } catch (error) {
      // Answer with a real error (carrying the CORS headers) so a browser doesn't report a CORS failure.
      console.error(error)
      res = new Response(
        JSON.stringify({ error: "server_error", message: "Something went wrong. Try again." }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      )
    }
    const headers = new Headers(res.headers)
    for (const [k, v] of Object.entries(cors)) headers.set(k, v)
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers })
  }
}
