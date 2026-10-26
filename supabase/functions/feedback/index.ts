import { createClient } from "npm:@supabase/supabase-js@2";

const MAX_TEXT = 1000;
const MAX_LIST = 50;
const COLUMNS = "id, user_id, saran, kesan, rating, created_at";
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

type FeedbackRow = {
    id: string;
    user_id: string;
    saran: string | null;
    kesan: string | null;
    rating: number | null;
    created_at: string;
};

type AuthorInfo = { username: string; photo_url: string | null };

// Bentuk data yang dikirim ke app. user_id tidak ikut dikirim.
function toItem(
    row: FeedbackRow,
    author: AuthorInfo | undefined,
    currentProfileId: string,
) {
    return {
        id: row.id,
        saran: row.saran ?? "",
        kesan: row.kesan ?? "",
        rating: row.rating,
        created_at: row.created_at,
        username: author?.username ?? "Pengguna",
        photo_url: author?.photo_url ?? null,
        is_mine: row.user_id === currentProfileId,
    };
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
            .select("id, username, photo_url")
            .eq("auth_user_id", authData.user.id)
            .maybeSingle();

        if (profileError) {
            console.error("feedback: gagal membaca profil:", profileError.message);
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

        // Daftar kiriman semua pengguna, terbaru lebih dulu
        if (action === "list") {
            const { data: rows, error } = await admin
                .from("feedback")
                .select(COLUMNS)
                .order("created_at", { ascending: false })
                .limit(MAX_LIST);

            if (error) {
                console.error("feedback: gagal membaca daftar:", error.message);
                return json(
                    { success: false, message: "Terjadi kesalahan di server." },
                    500,
                );
            }

            const list = (rows ?? []) as FeedbackRow[];
            const authorIds = [...new Set(list.map((row) => row.user_id))];

            const authors = new Map<string, AuthorInfo>();
            if (authorIds.length > 0) {
                const { data: users, error: usersError } = await admin
                    .from("users")
                    .select("id, username, photo_url")
                    .in("id", authorIds);

                if (usersError) {
                    console.error("feedback: gagal membaca penulis:", usersError.message);
                }
                for (const user of users ?? []) {
                    authors.set(user.id, {
                        username: user.username,
                        photo_url: user.photo_url,
                    });
                }
            }

            return json({
                success: true,
                items: list.map((row) =>
                    toItem(row, authors.get(row.user_id), profile.id)
                ),
            });
        }

        // Kirim saran dan kesan baru
        if (action === "create") {
            const kesan = typeof payload.kesan === "string" ? payload.kesan.trim() : "";
            const saran = typeof payload.saran === "string" ? payload.saran.trim() : "";
            const rating = Number(payload.rating);

            if (!kesan || !saran) {
                return json(
                    { success: false, message: "Kesan dan saran wajib diisi." },
                    400,
                );
            }
            if (kesan.length > MAX_TEXT || saran.length > MAX_TEXT) {
                return json(
                    {
                        success: false,
                        message: `Kesan dan saran maksimal ${MAX_TEXT} karakter.`,
                    },
                    400,
                );
            }
            if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
                return json(
                    { success: false, message: "Pilih penilaian 1 sampai 5 bintang." },
                    400,
                );
            }

            const { data, error } = await admin
                .from("feedback")
                .insert({ user_id: profile.id, saran, kesan, rating })
                .select(COLUMNS)
                .single();

            if (error) {
                console.error("feedback: gagal menyimpan:", error.message);
                return json(
                    { success: false, message: "Gagal menyimpan saran dan kesan." },
                    500,
                );
            }

            return json({
                success: true,
                item: toItem(
                    data as FeedbackRow,
                    { username: profile.username, photo_url: profile.photo_url },
                    profile.id,
                ),
            });
        }

        // Hapus kiriman milik sendiri
        if (action === "delete") {
            const id = typeof payload.id === "string" ? payload.id : "";
            if (!UUID_PATTERN.test(id)) {
                return json(
                    { success: false, message: "ID kiriman tidak valid." },
                    400,
                );
            }

            // Syarat user_id = profil sendiri menjamin akun lain tidak bisa menghapus.
            const { data, error } = await admin
                .from("feedback")
                .delete()
                .eq("id", id)
                .eq("user_id", profile.id)
                .select("id");

            if (error) {
                console.error("feedback: gagal menghapus:", error.message);
                return json(
                    { success: false, message: "Gagal menghapus kiriman." },
                    500,
                );
            }
            if (!data || data.length === 0) {
                return json(
                    {
                        success: false,
                        message: "Kiriman tidak ditemukan atau bukan milikmu.",
                    },
                    404,
                );
            }

            return json({ success: true });
        }

        return json({ success: false, message: "Aksi tidak dikenali." }, 400);
    } catch (error) {
        console.error(
            "Kesalahan feedback:",
            error instanceof Error ? error.message : "Unknown error",
        );
        return json(
            { success: false, message: "Terjadi kesalahan di server." },
            500,
        );
    }
});