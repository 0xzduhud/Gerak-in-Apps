
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":
    "GET, POST, PATCH, DELETE, OPTIONS",
};

type JsonObject = Record<string, unknown>;

type ActivityInput = {
  id?: unknown;
  sport_id?: unknown;
  started_at?: unknown;
  ended_at?: unknown;
  duration_sec?: unknown;
  steps?: unknown;
  distance_m?: unknown;
  calories?: unknown;
  reps?: unknown;
};

const activityFields = [
  "sport_id",
  "started_at",
  "ended_at",
  "duration_sec",
  "steps",
  "distance_m",
  "calories",
  "reps",
] as const;

class StageTimeoutError extends Error {
  constructor(public readonly stage: string) {
    super(`Timeout pada tahap ${stage}`);
    this.name = "StageTimeoutError";
  }
}

async function withTimeout<T>(
  promise: Promise<T>,
  stage: string,
  milliseconds = 8000,
): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;

  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timer = setTimeout(
          () => reject(new StageTimeoutError(stage)),
          milliseconds,
        );
      }),
    ]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}

function isObject(value: unknown): value is JsonObject {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value)
  );
}

function isUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value)
  );
}

function isValidTimestamp(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.trim().length > 0 &&
    Number.isFinite(Date.parse(value))
  );
}

function isNonNegativeInteger(value: unknown): value is number {
  return (
    typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value >= 0
  );
}

function isNonNegativeNumber(value: unknown): value is number {
  return (
    typeof value === "number" &&
    Number.isFinite(value) &&
    value >= 0
  );
}

function json(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function validateActivityFields(
  body: ActivityInput,
  isPatch: boolean,
): string | null {
  if (
    !isPatch &&
    !isValidTimestamp(body.started_at)
  ) {
    return "started_at wajib diisi dengan tanggal dan waktu yang valid.";
  }

  if (
    body.sport_id !== undefined &&
    body.sport_id !== null &&
    (
      typeof body.sport_id !== "number" ||
      !Number.isSafeInteger(body.sport_id) ||
      body.sport_id <= 0
    )
  ) {
    return "sport_id harus berupa bilangan bulat positif atau null.";
  }

  if (
    body.started_at !== undefined &&
    !isValidTimestamp(body.started_at)
  ) {
    return "started_at tidak valid.";
  }

  if (
    body.ended_at !== undefined &&
    body.ended_at !== null &&
    !isValidTimestamp(body.ended_at)
  ) {
    return "ended_at tidak valid.";
  }

  for (const field of ["duration_sec", "steps", "reps"] as const) {
    const value = body[field];

    if (
      value !== undefined &&
      !isNonNegativeInteger(value)
    ) {
      return `${field} harus berupa bilangan bulat nonnegatif.`;
    }
  }

  for (const field of ["distance_m", "calories"] as const) {
    const value = body[field];

    if (
      value !== undefined &&
      !isNonNegativeNumber(value)
    ) {
      return `${field} harus berupa angka nonnegatif.`;
    }
  }

  return null;
}

async function readJson(req: Request): Promise<JsonObject | null> {
  try {
    const value: unknown = await req.json();
    return isObject(value) ? value : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (!["GET", "POST", "PATCH", "DELETE"].includes(req.method)) {
    return json({
      success: false,
      message: "Metode HTTP tidak diizinkan.",
    }, 405);
  }

  let stage = "configuration";

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      console.error("ACTIVITIES_CONFIG_MISSING");

      return json({
        success: false,
        stage,
        message: "Konfigurasi Supabase belum lengkap.",
      }, 500);
    }

    stage = "authorization_header";

    const authorization = req.headers.get("Authorization");
    const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];

    if (!token) {
      return json({
        success: false,
        stage,
        message: "Token autentikasi diperlukan.",
      }, 401);
    }

    stage = "auth_client";

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    stage = "auth.getUser";
    console.log("ACTIVITIES_STAGE", stage);

    const {
      data: { user: authUser },
      error: authError,
    } = await withTimeout(
      authClient.auth.getUser(token),
      stage,
    );

    if (authError || !authUser) {
      console.error(
        "ACTIVITIES_AUTH_REJECTED",
        authError?.message ?? "User tidak ditemukan",
      );

      return json({
        success: false,
        stage,
        message: "Token tidak valid atau sesi telah berakhir.",
      }, 401);
    }

    stage = "profile_lookup";

    const adminDb = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    console.log("ACTIVITIES_STAGE", stage);

    const {
      data: profile,
      error: profileError,
    } = await withTimeout(
      adminDb
        .from("users")
        .select("id")
        .eq("auth_user_id", authUser.id)
        .maybeSingle(),
      stage,
    );

    if (profileError) {
      console.error("ACTIVITIES_PROFILE_ERROR", profileError.message);

      return json({
        success: false,
        stage,
        message: "Gagal mengambil profil pengguna.",
      }, 500);
    }

    if (!profile) {
      return json({
        success: false,
        stage,
        message: "Profil pengguna belum tersedia.",
      }, 403);
    }

    const userId = profile.id as string;
    const url = new URL(req.url);
    const activityId = url.searchParams.get("id");

    // GET: membaca aktivitas milik pengguna yang sedang login.
    if (req.method === "GET") {
      stage = "activities_select";

      if (activityId !== null && !isUuid(activityId)) {
        return json({
          success: false,
          message: "Parameter id harus berupa UUID yang valid.",
        }, 400);
      }

      let query = adminDb
        .from("activities")
        .select("*")
        .eq("user_id", userId)
        .is("deleted_at", null);

      if (activityId !== null) {
        query = query.eq("id", activityId);
      }

      console.log("ACTIVITIES_STAGE", stage);

      const { data, error } = await withTimeout(
        query.order("started_at", { ascending: false }),
        stage,
      );

      if (error) {
        console.error("ACTIVITIES_SELECT_ERROR", error.message);

        return json({
          success: false,
          stage,
          message: "Gagal mengambil data aktivitas.",
        }, 500);
      }

      return json({
        success: true,
        data: data ?? [],
      });
    }

    // POST: membuat aktivitas baru.
    if (req.method === "POST") {
      stage = "request_body";

      const body = await readJson(req);

      if (!body) {
        return json({
          success: false,
          stage,
          message: "Body harus berupa JSON object yang valid.",
        }, 400);
      }

      const input = body as ActivityInput;

      if (
        input.id !== undefined &&
        !isUuid(input.id)
      ) {
        return json({
          success: false,
          message: "id harus berupa UUID yang valid.",
        }, 400);
      }

      const validationError = validateActivityFields(input, false);

      if (validationError) {
        return json({
          success: false,
          message: validationError,
        }, 400);
      }

      stage = "activities_insert";

      const now = new Date().toISOString();

      const payload = {
        id: input.id ?? crypto.randomUUID(),
        user_id: userId,
        sport_id: input.sport_id ?? null,
        started_at: input.started_at,
        ended_at: input.ended_at ?? null,
        duration_sec: input.duration_sec ?? 0,
        steps: input.steps ?? 0,
        distance_m: input.distance_m ?? 0,
        calories: input.calories ?? 0,
        reps: input.reps ?? 0,
        created_at: now,
        updated_at: now,
        deleted_at: null,
      };

      console.log("ACTIVITIES_STAGE", stage);

      const { data, error } = await withTimeout(
        adminDb
          .from("activities")
          .insert(payload)
          .select("*")
          .single(),
        stage,
      );

      if (error) {
        console.error("ACTIVITIES_INSERT_ERROR", error.message);

        return json({
          success: false,
          stage,
          message: "Gagal menyimpan aktivitas.",
        }, 500);
      }

      return json({
        success: true,
        message: "Aktivitas berhasil ditambahkan.",
        data,
      }, 201);
    }

    // PATCH dan DELETE membutuhkan id aktivitas.
    stage = "activity_id_validation";

    if (!activityId || !isUuid(activityId)) {
      return json({
        success: false,
        stage,
        message: "Parameter id aktivitas yang valid wajib diisi.",
      }, 400);
    }

    // PATCH: mengubah aktivitas milik pengguna.
    if (req.method === "PATCH") {
      stage = "request_body";

      const body = await readJson(req);

      if (!body) {
        return json({
          success: false,
          stage,
          message: "Body harus berupa JSON object yang valid.",
        }, 400);
      }

      const input = body as ActivityInput;
      const updates: JsonObject = {};

      for (const field of activityFields) {
        if (Object.prototype.hasOwnProperty.call(input, field)) {
          updates[field] = input[field];
        }
      }

      if (Object.keys(updates).length === 0) {
        return json({
          success: false,
          stage,
          message: "Tidak ada field aktivitas yang akan diubah.",
        }, 400);
      }

      const validationError = validateActivityFields(input, true);

      if (validationError) {
        return json({
          success: false,
          message: validationError,
        }, 400);
      }

      updates.updated_at = new Date().toISOString();

      stage = "activities_update";
      console.log("ACTIVITIES_STAGE", stage);

      const { data, error } = await withTimeout(
        adminDb
          .from("activities")
          .update(updates)
          .eq("id", activityId)
          .eq("user_id", userId)
          .is("deleted_at", null)
          .select("*")
          .maybeSingle(),
        stage,
      );

      if (error) {
        console.error("ACTIVITIES_UPDATE_ERROR", error.message);

        return json({
          success: false,
          stage,
          message: "Gagal mengubah aktivitas.",
        }, 500);
      }

      if (!data) {
        return json({
          success: false,
          message: "Aktivitas tidak ditemukan.",
        }, 404);
      }

      return json({
        success: true,
        message: "Aktivitas berhasil diperbarui.",
        data,
      });
    }

    // DELETE: soft delete agar data tidak langsung hilang.
    stage = "activities_delete";
    console.log("ACTIVITIES_STAGE", stage);

    const now = new Date().toISOString();

    const { data, error } = await withTimeout(
      adminDb
        .from("activities")
        .update({
          deleted_at: now,
          updated_at: now,
        })
        .eq("id", activityId)
        .eq("user_id", userId)
        .is("deleted_at", null)
        .select("id")
        .maybeSingle(),
      stage,
    );

    if (error) {
      console.error("ACTIVITIES_DELETE_ERROR", error.message);

      return json({
        success: false,
        stage,
        message: "Gagal menghapus aktivitas.",
      }, 500);
    }

    if (!data) {
      return json({
        success: false,
        message: "Aktivitas tidak ditemukan.",
      }, 404);
    }

    return json({
      success: true,
      message: "Aktivitas berhasil dihapus.",
      data,
    });
  } catch (error) {
    if (error instanceof StageTimeoutError) {
      console.error("ACTIVITIES_TIMEOUT", error.stage);

      return json({
        success: false,
        stage: error.stage,
        message: `Permintaan terlalu lama pada tahap ${error.stage}.`,
      }, 504);
    }

    console.error("ACTIVITIES_UNEXPECTED_ERROR", stage, error);

    return json({
      success: false,
      stage,
      message: "Terjadi kesalahan saat memproses aktivitas.",
    }, 500);
  }
});
