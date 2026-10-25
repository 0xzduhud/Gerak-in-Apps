import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const REQUEST_TIMEOUT_MS = 8000;

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

// Membatasi waktu tunggu setiap permintaan jaringan.
async function fetchWithTimeout(
  input: string | URL | Request,
  init: RequestInit = {},
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(
    () => controller.abort(),
    REQUEST_TIMEOUT_MS,
  );

  try {
    return await fetch(input, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

function logStage(stage: string, startedAt: number) {
  console.log(`[AUTH LOGIN] ${stage}: ${Date.now() - startedAt} ms`);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { success: false, message: "Metode tidak diizinkan." },
      405,
    );
  }

  const requestStartedAt = Date.now();
  let currentStage = "Validasi konfigurasi";

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const publicKey =
      Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY");

    if (!supabaseUrl || !serviceRoleKey || !publicKey) {
      console.error("[AUTH LOGIN] Environment belum lengkap.");

      return jsonResponse({
        success: false,
        message: "Konfigurasi autentikasi server belum lengkap.",
      }, 500);
    }

    currentStage = "Membaca request";
    const body = await req.json();

    const identifier =
      typeof body.identifier === "string"
        ? body.identifier.trim()
        : "";

    const password =
      typeof body.password === "string"
        ? body.password
        : "";

    if (!identifier || !password) {
      return jsonResponse({
        success: false,
        message: "Username/email dan password wajib diisi.",
      }, 400);
    }

    const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier);

    let email = identifier;
    let expectedAuthUserId: string | null = null;

    // Tahap 1: Jika identifier bukan email, cari username.
    if (!isEmail) {
      currentStage = "Pencarian username";
      const lookupStartedAt = Date.now();

      console.log("[AUTH LOGIN] Memulai pencarian username.");

      const admin = createClient(supabaseUrl, serviceRoleKey, {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
        global: {
          fetch: fetchWithTimeout,
        },
      });

      const { data: profile, error: profileError } = await admin
        .from("users")
        .select("email, auth_user_id")
        .eq("username", identifier.toLowerCase())
        .maybeSingle();

      logStage("Pencarian username selesai", lookupStartedAt);

      if (profileError) {
        console.error(
          "[AUTH LOGIN] Kesalahan pencarian username:",
          profileError.message,
        );

        return jsonResponse({
          success: false,
          message: "Pencarian username gagal. Silakan coba lagi.",
        }, 500);
      }

      if (!profile?.email || !profile.auth_user_id) {
        return jsonResponse({
          success: false,
          message: "Username/email atau password salah.",
        }, 401);
      }

      email = profile.email;
      expectedAuthUserId = profile.auth_user_id;
    }

    // Tahap 2: Validasi password melalui Supabase Auth.
    currentStage = "Verifikasi Supabase Auth";
    const authStartedAt = Date.now();

    console.log("[AUTH LOGIN] Memulai verifikasi Supabase Auth.");

    const authResponse = await fetchWithTimeout(
      `${supabaseUrl}/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: publicKey,
        },
        body: JSON.stringify({ email, password }),
      },
    );

    logStage("Respons Supabase Auth diterima", authStartedAt);


const authData = await authResponse.json();

if (!authResponse.ok) {
  console.warn(
    "[AUTH LOGIN] Supabase Auth menolak login:",
    JSON.stringify({
      status: authResponse.status,
      code: authData?.code ?? null,
      error: authData?.error ?? null,
      message: authData?.msg ?? authData?.message ?? null,
    }),
  );

  if (authResponse.status === 429) {
    return jsonResponse({
      success: false,
      message: "Terlalu banyak percobaan. Silakan coba lagi nanti.",
    }, 429);
  }

  return jsonResponse({
    success: false,
    message: "Username/email atau password salah.",
  }, 401);
}


    if (
      typeof authData.refresh_token !== "string" ||
      !authData.refresh_token ||
      typeof authData.access_token !== "string" ||
      !authData.access_token ||
      typeof authData.user?.id !== "string"
    ) {
      console.error("[AUTH LOGIN] Respons token tidak lengkap.");

      return jsonResponse({
        success: false,
        message: "Supabase tidak mengembalikan sesi login yang lengkap.",
      }, 502);
    }

    // Pastikan username yang ditemukan terhubung ke akun Auth yang benar.
    if (
      expectedAuthUserId !== null &&
      expectedAuthUserId !== authData.user.id
    ) {
      console.error(
        "[AUTH LOGIN] ID pengguna pada profil tidak cocok dengan Supabase Auth.",
      );

      return jsonResponse({
        success: false,
        message: "Data akun tidak cocok. Silakan hubungi administrator.",
      }, 401);
    }

    console.log(
      `[AUTH LOGIN] Login berhasil dalam ${Date.now() - requestStartedAt} ms.`,
    );

    // Kembalikan token resmi Supabase Auth.
    return jsonResponse({
      success: true,
      access_token: authData.access_token,
      refresh_token: authData.refresh_token,
      token_type: authData.token_type,
      expires_in: authData.expires_in,
      user: authData.user,
    });
  } catch (error) {
    const isTimeout =
      error instanceof DOMException && error.name === "AbortError";

    console.error(
      `[AUTH LOGIN] Gagal pada tahap "${currentStage}".`,
      error instanceof Error ? error.message : String(error),
    );

    if (isTimeout) {
      return jsonResponse({
        success: false,
        message: `Permintaan melewati batas waktu pada tahap: ${currentStage}.`,
      }, 504);
    }

    return jsonResponse({
      success: false,
      message: "Terjadi kesalahan saat login. Silakan coba lagi.",
    }, 500);
  }
});