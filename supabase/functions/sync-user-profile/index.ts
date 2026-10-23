
import { createClient } from "npm:@supabase/supabase-js@2";
import bcrypt from "npm:bcryptjs@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    if (req.method !== "POST") {
      return json({ success: false, message: "Method tidak diizinkan." }, 405);
    }

    const authorization = req.headers.get("Authorization");
    const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];

    if (!token) {
      return json({ success: false, message: "Sesi tidak ditemukan." }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error("Konfigurasi rahasia Supabase belum lengkap.");
    }

    // Klien ini memverifikasi token pengguna, bukan mempercayai ID dari aplikasi.
    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const {
      data: { user },
      error: authError,
    } = await authClient.auth.getUser(token);

    if (authError || !user || !user.email) {
      return json({ success: false, message: "Sesi tidak valid." }, 401);
    }

    const body = await req.json();
    const password = body?.password;

    if (
      typeof password !== "string" ||
      password.length < 8 ||
      password.length > 72
    ) {
      return json({
        success: false,
        message: "Password untuk hash tidak valid.",
      }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Hash dibuat di server. Password asli tidak disimpan.
    const passwordHash = bcrypt.hashSync(password, 12);
    const email = user.email.trim().toLowerCase();
    const username = String(user.user_metadata?.username ?? "").trim();
    const fullName = String(user.user_metadata?.full_name ?? "").trim();

    // Cari profil yang sudah terhubung dengan akun Auth ini.
    const { data: linkedProfile, error: linkedError } = await admin
      .from("users")
      .select("*")
      .eq("auth_user_id", user.id)
      .maybeSingle();

    if (linkedError) throw linkedError;

    let profile = linkedProfile;

    if (profile) {
      const { data, error } = await admin
        .from("users")
        .update({
          email,
          password_hash: passwordHash,
          ...(username ? { username } : {}),
          ...(fullName ? { full_name: fullName } : {}),
          updated_at: new Date().toISOString(),
        })
        .eq("auth_user_id", user.id)
        .select()
        .single();

      if (error) throw error;
      profile = data;
    } else {
      // Profil lama hanya boleh ditautkan melalui email yang telah
      // diverifikasi, dan hanya jika belum terhubung ke akun Auth lain.
      const emailVerified = Boolean(user.email_confirmed_at);

      if (emailVerified) {
        const { data: legacyProfile, error: legacyError } = await admin
          .from("users")
          .select("*")
          .eq("email", email)
          .is("auth_user_id", null)
          .maybeSingle();

        if (legacyError) throw legacyError;

        if (legacyProfile) {
          const { data, error } = await admin
            .from("users")
            .update({
              auth_user_id: user.id,
              password_hash: passwordHash,
              updated_at: new Date().toISOString(),
            })
            .eq("id", legacyProfile.id)
            .is("auth_user_id", null)
            .select()
            .single();

          if (error) throw error;
          profile = data;
        }
      }

      if (!profile) {
        if (!username) {
          return json({
            success: false,
            message: "Username tidak ditemukan pada metadata akun.",
          }, 400);
        }

        const { data, error } = await admin
          .from("users")
          .insert({
            auth_user_id: user.id,
            username,
            email,
            full_name: fullName || null,
            password_hash: passwordHash,
          })
          .select()
          .single();

        if (error) throw error;
        profile = data;
      }
    }

    // Jangan mengirim hash password ke aplikasi.
    const { password_hash: _hiddenHash, ...safeProfile } = profile;

    return json({ success: true, user: safeProfile });
  } catch (error) {
    console.error("sync-user-profile error:", error);

    return json({
      success: false,
      message: "Sinkronisasi profil gagal. Periksa log Edge Function.",
    }, 500);
  }
});
