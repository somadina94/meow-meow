// deno-lint-ignore-file no-explicit-any
// Deletes files older than 1 hour from the `meowmeow-app-attachment` bucket.
// Scheduled to run every 2 hours by pg_cron (see migration).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET = "meowmeow-app-attachment";
const MAX_AGE_MS = 60 * 60 * 1000; // 1 hour

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function walk(admin: any, prefix: string, deleted: string[], cutoff: number): Promise<void> {
  const { data, error } = await admin.storage.from(BUCKET).list(prefix, { limit: 1000 });
  if (error || !data) return;
  for (const entry of data) {
    const full = prefix ? `${prefix}/${entry.name}` : entry.name;
    // Folder entries have no id / no metadata.size
    const isFolder = !entry.id;
    if (isFolder) { await walk(admin, full, deleted, cutoff); continue; }
    const createdAt = entry.created_at ? new Date(entry.created_at).getTime() : 0;
    const updatedAt = entry.updated_at ? new Date(entry.updated_at).getTime() : 0;
    const ts = Math.max(createdAt, updatedAt);
    if (ts && ts < cutoff) deleted.push(full);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);
  const cutoff = Date.now() - MAX_AGE_MS;
  const toDelete: string[] = [];
  await walk(admin, "meowmeow/app/attachment", toDelete, cutoff);
  let removed = 0;
  // Delete in chunks of 500
  for (let i = 0; i < toDelete.length; i += 500) {
    const chunk = toDelete.slice(i, i + 500);
    const { error } = await admin.storage.from(BUCKET).remove(chunk);
    if (!error) removed += chunk.length;
    else console.error("[attachment-cleanup] remove error:", error.message);
  }
  return new Response(JSON.stringify({ ok: true, scanned: toDelete.length, removed, cutoff: new Date(cutoff).toISOString() }), {
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
});
