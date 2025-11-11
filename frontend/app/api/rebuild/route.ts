import { NextRequest, NextResponse } from "next/server";
import crypto from "node:crypto";
import { rebuildAndPush } from "@/lib/rebuild";

export const runtime = "nodejs";

function verifyBearer(req: NextRequest) {
  const token = process.env.REBUILD_TOKEN;
  if (!token) return true; // no token → allow (dev)
  const auth = req.headers.get("authorization") || "";
  return auth === `Bearer ${token}`;
}

// Optional: verify Alchemy webhook signature if you use their callback
function verifyAlchemySignature(raw: string, req: NextRequest) {
  const signingKey = process.env.ALCHEMY_SIGNING_KEY;
  if (!signingKey) return true; // skip if not configured
  const sig = req.headers.get("x-alchemy-signature");
  if (!sig) return false;
  const hmac = crypto.createHmac("sha256", signingKey).update(raw).digest("hex");
  return sig === hmac;
}

export async function POST(req: NextRequest) {
  // Read raw body for signature verification
  const raw = await req.text();

  if (!verifyBearer(req) && !verifyAlchemySignature(raw, req)) {
    return NextResponse.json({ ok: false, error: "unauthorized" }, { status: 401 });
  }

  try {
    const results = await rebuildAndPush();
    return NextResponse.json({ ok: true, results });
  } catch (e) {
    const message =
    e instanceof Error ? e.message :
    typeof e === "string" ? e :
    (() => { try { return JSON.stringify(e); } catch { return String(e); } })();

    return NextResponse.json({ ok: false, error: message }, { status: 500 });
  }
}

// Allow GET too (for manual tests)
export async function GET(req: NextRequest) {
  return POST(req);
}
