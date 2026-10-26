import { createClient } from "npm:@supabase/supabase-js@2";

const PLAN = "plus";
const PERIOD_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;
const BASE_PRICE_IDR = 150000;
// Kurs statis ke IDR. Harus sama dengan di SubscriptionProvider.
const RATES_TO_IDR: Record<string, number> = {
    IDR: 1,
    USD: 15500,
    EUR: 16800,
};
const SUB_COLUMNS = "id, plan, status, started_at, expires_at";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}

type SubscriptionRow = {
    id: string;
    plan: string;
    status: string;
    started_at: string;
    expires_at: string;
};

function statusBody(subscription: SubscriptionRow | null) {
    return { success: true, is_premium: subscription !== null, subscription };
}

// Langganan yang masih aktif (status active dan belum kedaluwarsa).
// deno-lint-ignore no-explicit-any
async function findActive(admin: any, profileId: string) {
    const { data, error } = await admin
        .from("subscriptions")
        .select(SUB_COLUMNS)
        .eq("user_id", profileId)
        .eq("status", "active")
        .gt("expires_at", new Date().toISOString())
        .order("expires_at", { ascending: false })
        .limit(1);

    if (error) throw new Error(error.message);
    return ((data ?? [])[0] ?? null) as SubscriptionRow | null;
}

Deno.serve(async (request: Request) => {
    if (request.method === "OPTIONS") {
        return new Response("ok", { status: 200, headers: corsHeaders });
    }

    if (request.method !== "POST") {
        return json(
            { success: false, message: "Metode tidak diizinkan." },
            405,
        );
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL");
        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        if (!supabaseUrl || !serviceKey) {
            console.error("Konfigurasi Supabase server belum lengkap.");
            return json(
                { success: false, message: "Server belum dikonfigurasi dengan benar." },
                500,
            );
        }

        const admin = createClient(supabaseUrl, serviceKey, {
            auth: { persistSession: false, autoRefreshToken: false },
        });

        // 1. Verifikasi sesi (token Supabase Auth milik pengguna)
        const token = (request.headers.get("Authorization") ?? "").match(
            /^Bearer\s+(.+)$/i,
        )?.[1];
        if (!token) {
            return json({ success: false, message: "Sesi tidak ditemukan." }, 401);
        }

        const { data: authData, error: authError } = await admin.auth.getUser(
            token,
        );
        if (authError || !authData?.user) {
            return json(
                { success: false, message: "Sesi tidak valid atau sudah kedaluwarsa." },
                401,
            );
        }

        // 2. Cari profil di tabel users dari akun Auth
        const { data: profile, error: profileError } = await admin
            .from("users")
            .select("id")
            .eq("auth_user_id", authData.user.id)
            .maybeSingle();

        if (profileError) {
            console.error("subscriptions: gagal membaca profil:", profileError.message);
            return json(
                { success: false, message: "Terjadi kesalahan di server." },
                500,
            );
        }
        if (!profile) {
            return json(
                { success: false, message: "Profil belum terhubung dengan akun login." },
                404,
            );
        }

        // 3. Baca isi request
        let payload: Record<string, unknown>;
        try {
            payload = await request.json();
        } catch {
            return json(
                { success: false, message: "Format request tidak valid." },
                400,
            );
        }

        const action = payload?.action;

        // Status langganan saat ini
        if (action === "status") {
            return json(statusBody(await findActive(admin, profile.id)));
        }

        // Pembayaran simulasi: aktifkan atau perpanjang langganan Plus
        if (action === "activate") {
            const currency = typeof payload.currency === "string"
                ? payload.currency.trim().toUpperCase()
                : "";
            const rate = RATES_TO_IDR[currency];
            if (!rate) {
                return json(
                    { success: false, message: "Mata uang tidak didukung." },
                    400,
                );
            }

            // Harga dihitung di server, bukan dipercaya dari aplikasi.
            const amount = currency === "IDR"
                ? BASE_PRICE_IDR
                : Math.round((BASE_PRICE_IDR / rate) * 100) / 100;

            const existing = await findActive(admin, profile.id);
            let subscription: SubscriptionRow;
            let previousExpiry: string | null = null;

            if (existing) {
                previousExpiry = existing.expires_at;
                const newExpiry = new Date(
                    new Date(existing.expires_at).getTime() + PERIOD_DAYS * DAY_MS,
                ).toISOString();

                const { data, error } = await admin
                    .from("subscriptions")
                    .update({ expires_at: newExpiry })
                    .eq("id", existing.id)
                    .select(SUB_COLUMNS)
                    .single();

                if (error) {
                    console.error("subscriptions: gagal memperpanjang:", error.message);
                    return json(
                        { success: false, message: "Gagal mengaktifkan langganan." },
                        500,
                    );
                }
                subscription = data as SubscriptionRow;
            } else {
                const now = new Date();
                const { data, error } = await admin
                    .from("subscriptions")
                    .insert({
                        user_id: profile.id,
                        plan: PLAN,
                        status: "active",
                        started_at: now.toISOString(),
                        expires_at: new Date(now.getTime() + PERIOD_DAYS * DAY_MS)
                            .toISOString(),
                    })
                    .select(SUB_COLUMNS)
                    .single();

                if (error) {
                    console.error("subscriptions: gagal membuat langganan:", error.message);
                    return json(
                        { success: false, message: "Gagal mengaktifkan langganan." },
                        500,
                    );
                }
                subscription = data as SubscriptionRow;
            }

            const { error: paymentError } = await admin.from("payments").insert({
                user_id: profile.id,
                subscription_id: subscription.id,
                currency,
                amount,
                rate_to_idr: rate,
                status: "success",
            });

            if (paymentError) {
                console.error("subscriptions: gagal mencatat pembayaran:", paymentError.message);
                // Batalkan perubahan langganan supaya data tetap konsisten.
                if (previousExpiry) {
                    await admin
                        .from("subscriptions")
                        .update({ expires_at: previousExpiry })
                        .eq("id", subscription.id);
                } else {
                    await admin.from("subscriptions").delete().eq("id", subscription.id);
                }
                return json(
                    { success: false, message: "Pembayaran gagal dicatat. Coba lagi." },
                    500,
                );
            }

            return json({ ...statusBody(subscription), payment: { currency, amount } });
        }

        // Reset ke Free, khusus untuk keperluan demo. Riwayat pembayaran dipertahankan.
        if (action === "reset") {
            const { error } = await admin
                .from("subscriptions")
                .update({ status: "expired", expires_at: new Date().toISOString() })
                .eq("user_id", profile.id)
                .eq("status", "active");

            if (error) {
                console.error("subscriptions: gagal reset:", error.message);
                return json(
                    { success: false, message: "Gagal mereset status premium." },
                    500,
                );
            }

            return json(statusBody(null));
        }

        return json({ success: false, message: "Aksi tidak dikenali." }, 400);
    } catch (error) {
        console.error(
            "Kesalahan subscriptions:",
            error instanceof Error ? error.message : "Unknown error",
        );
        return json(
            { success: false, message: "Terjadi kesalahan di server." },
            500,
        );
    }
});