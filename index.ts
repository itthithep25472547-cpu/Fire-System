import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function respond(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function dateInBangkok(date = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function addDays(date: string, days: number) {
  const value = new Date(`${date}T00:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

function formatDateThai(date: string) {
  return new Date(`${date}T00:00:00+07:00`).toLocaleDateString("th-TH", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "Asia/Bangkok",
  });
}

function formatBaht(value: unknown) {
  return `${(Number(value) || 0).toLocaleString("th-TH", {maximumFractionDigits: 2})} บาท`;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return respond({error:"Method not allowed"},405);

  const expectedSecret = Deno.env.get("CRON_SECRET");
  if (!expectedSecret || request.headers.get("x-cron-secret") !== expectedSecret) {
    return respond({error:"Unauthorized scheduled invocation"},401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("RESEND_FROM_ADDRESS");
  if (!supabaseUrl || !serviceRoleKey || !resendApiKey || !from) {
    return respond({error:"ยังตั้งค่า Supabase/Resend Function ไม่ครบ"},500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {autoRefreshToken:false, persistSession:false},
  });
  const today = dateInBangkok();
  const targetDays = [30, 7];
  const targetDates = targetDays.map((days) => addDays(today, days));
  const {data: policies, error: policyError} = await admin.from("fire_insurance_policies").select("id,data");
  if (policyError) {
    console.error("Could not load policies", policyError);
    return respond({error:"โหลดกรมธรรม์ไม่สำเร็จ"},500);
  }

  const {data: sentRows, error: logReadError} = await admin.from("email_send_logs")
    .select("policy_id,expiry_date,days_before")
    .eq("send_type","scheduled")
    .eq("status","sent")
    .in("expiry_date",targetDates)
    .in("days_before",targetDays);
  if (logReadError) {
    console.error("Could not load reminder history", logReadError);
    return respond({error:"โหลดประวัติเตือนไม่สำเร็จ กรุณารัน supabase-workflow-upgrade.sql"},500);
  }
  const alreadySent = new Set((sentRows || []).map((row) => `${row.policy_id}|${row.expiry_date}|${row.days_before}`));
  const policiesByExpiry = new Map((policies || []).map((row) => [row.id, {id:row.id, ...(row.data || {})}]));
  const results = {sent:0, failed:0, skipped:0};

  for (const daysBefore of targetDays) {
    const expiryDate = addDays(today, daysBefore);
    for (const policy of policiesByExpiry.values()) {
      if (policy.endDate !== expiryDate || policy.emailReminderEnabled !== true) continue;
      const recipient = typeof policy.email === "string" ? policy.email.trim().toLowerCase() : "";
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient)) {
        results.skipped++;
        continue;
      }
      const key = `${policy.id}|${expiryDate}|${daysBefore}`;
      if (alreadySent.has(key)) {
        results.skipped++;
        continue;
      }

      const subject = `แจ้งเตือนต่ออายุประกันอัคคีภัย กรมธรรม์ ${policy.policyNumber || ""}`.trim();
      const text = [
        `เรียน ${policy.insuredName || "ผู้เอาประกันภัย"}`,
        "",
        `บริษัท ${policy.insurerCompany || "บริษัท เทเวศประกันภัย จำกัด (มหาชน)"} ขอแจ้งว่ากรมธรรม์ประกันอัคคีภัยของท่านจะสิ้นสุดความคุ้มครองในอีก ${daysBefore} วัน`,
        `เลขที่กรมธรรม์: ${policy.policyNumber || "—"}`,
        `วันสิ้นสุดความคุ้มครอง: ${formatDateThai(expiryDate)}`,
        `ทุนประกันภัย: ${formatBaht(policy.sumInsured)}`,
        `เบี้ยรวมที่ต้องชำระ: ${formatBaht(policy.premium)}`,
        `กำหนดชำระ: ${formatDateThai(policy.dueDate || expiryDate)}`,
        policy.bankInfo ? `ข้อมูลการชำระเงิน: ${policy.bankInfo}` : "",
        "",
        "กรุณาติดต่อเจ้าหน้าที่เพื่อดำเนินการต่ออายุ หากท่านได้ต่ออายุหรือชำระเงินแล้ว ขออภัยในความไม่สะดวก",
      ].filter(Boolean).join("\n");

      const {data: logRow, error: logError} = await admin.from("email_send_logs").insert({
        policy_id:policy.id,
        policy_number:policy.policyNumber || null,
        expiry_date:expiryDate,
        recipient_email:recipient,
        subject,
        language:"th",
        send_type:"scheduled",
        days_before:daysBefore,
        status:"pending",
      }).select("id").single();
      if (logError) {
        console.error("Could not create reminder history row", logError);
        results.failed++;
        continue;
      }

      try {
        const response = await fetch("https://api.resend.com/emails", {
          method:"POST",
          headers:{Authorization:`Bearer ${resendApiKey}`,"Content-Type":"application/json"},
          body:JSON.stringify({from,to:[recipient],subject,text}),
        });
        const providerResult = await response.json().catch(() => ({}));
        if (!response.ok) {
          const message = String(providerResult.message || "Resend rejected the message").slice(0,500);
          await admin.from("email_send_logs").update({status:"failed",error_message:message}).eq("id",logRow.id);
          results.failed++;
          continue;
        }
        const {error: updateError} = await admin.from("email_send_logs").update({
          status:"sent",
          provider_message_id:providerResult.id || null,
          sent_at:new Date().toISOString(),
        }).eq("id",logRow.id);
        if (updateError) console.error("Email sent but history update failed", updateError);
        alreadySent.add(key);
        results.sent++;
      } catch (error) {
        const message = String(error).slice(0,500);
        await admin.from("email_send_logs").update({status:"failed",error_message:message}).eq("id",logRow.id);
        results.failed++;
      }
    }
  }

  return respond({date:today, ...results});
});
