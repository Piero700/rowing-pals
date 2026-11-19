// Run with: deno test --allow-env supabase/functions/_shared/cors_test.ts
import { corsHeaders, withCors } from "./cors.ts"

const assertEq = (a: unknown, b: unknown) => {
  if (a !== b) throw new Error(`expected ${String(b)}, got ${String(a)}`)
}

Deno.test("allowed origin is echoed back", () => {
  const h = corsHeaders("https://rowingpals.com")
  assertEq(h["Access-Control-Allow-Origin"], "https://rowingpals.com")
  assertEq(h["Vary"], "Origin")
  assertEq(corsHeaders("http://localhost:5173")["Access-Control-Allow-Origin"], "http://localhost:5173")
})

Deno.test("disallowed or missing origin gets no allow-origin", () => {
  assertEq(corsHeaders("https://evil.example")["Access-Control-Allow-Origin"], undefined)
  assertEq(corsHeaders(null)["Access-Control-Allow-Origin"], undefined)
})

Deno.test("WEB_ORIGINS adds comma-separated origins", () => {
  Deno.env.set("WEB_ORIGINS", "https://staging.example.com, https://b.example.com")
  assertEq(corsHeaders("https://b.example.com")["Access-Control-Allow-Origin"], "https://b.example.com")
  assertEq(corsHeaders("https://staging.example.com")["Access-Control-Allow-Origin"], "https://staging.example.com")
  Deno.env.delete("WEB_ORIGINS")
})

Deno.test("OPTIONS preflight returns 200 with allow-headers and allow-methods", async () => {
  const handler = withCors(() => new Response("should not run", { status: 500 }))
  const res = await handler(new Request("http://x/", { method: "OPTIONS", headers: { Origin: "http://localhost:5173" } }))
  assertEq(res.status, 200)
  assertEq(res.headers.get("Access-Control-Allow-Origin"), "http://localhost:5173")
  assertEq(res.headers.get("Access-Control-Allow-Headers"), "authorization, x-client-info, apikey, content-type")
  assertEq(res.headers.get("Access-Control-Allow-Methods"), "POST, OPTIONS")
})

Deno.test("errors keep their status and body and still get the headers", async () => {
  const handler = withCors(() => new Response('{"error":"x"}', { status: 401 }))
  const res = await handler(new Request("http://x/", { method: "POST", headers: { Origin: "https://rowingpals.com" } }))
  assertEq(res.status, 401)
  assertEq(await res.text(), '{"error":"x"}')
  assertEq(res.headers.get("Access-Control-Allow-Origin"), "https://rowingpals.com")
})

Deno.test("a throwing handler becomes a 500 JSON error with the CORS headers", async () => {
  const handler = withCors(() => {
    throw new Error("boom")
  })
  const orig = console.error
  console.error = () => {}
  try {
    const res = await handler(new Request("http://x/", { method: "POST", headers: { Origin: "https://rowingpals.com" } }))
    assertEq(res.status, 500)
    assertEq(res.headers.get("Access-Control-Allow-Origin"), "https://rowingpals.com")
    assertEq(await res.text(), '{"error":"server_error","message":"Something went wrong. Try again."}')
  } finally {
    console.error = orig
  }
})
