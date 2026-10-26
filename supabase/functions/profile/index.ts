import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "avatars";
const MAX_LIST = 100;
const NAME_MIN = 2;
const NAME_MAX = 60;
const NAME_PATTERN = /^[\p{L}\p{N} .,'’-]+$/u;
const AVATAR_FILE_PATTERN = /^avatar_\d{10,15}\.(jpg|png|webp)$/;
const PROFILE_COLUMNS = "id, username, email, full_name, photo_url";

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

type ProfileRow = {
    id: string;
    username: string;
    email: string;
    full_name: string | null;
    photo_url: string | null;
};

// Data profil yang aman dikirim ke app.
function toProfile(row: ProfileRow) {
    return {
        username: row.username,
        email: row.email,
        full_name: row.full_name,
        photo_url: row.photo_url,
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
        const authUser = authData.user;
        const authId = authUser.id;

        // 2. Cari profil di tabel users dari akun Auth
        const { data: profile, error: profileError } = await admin
            .from("users")
            .select(PROFILE_COLUMNS)
            .eq("auth_user_id", authId)
            .maybeSingle();

        if (profileError) {
            console.error("profile: gagal membaca profil:", profileError.message);
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

        // Profil + jumlah followers dan following
        if (action === "get") {
            const [followersRes, followingRes] = await Promise.all([
                admin
                    .from("user_follows")
                    .select("id", { count: "exact", head: true })
                    .eq("following_id", authId),
                admin
                    .from("user_follows")
                    .select("id", { count: "exact", head: true })
                    .eq("followers_id", authId),
            ]);

            if (followersRes.error || followingRes.error) {
                console.error(
                    "profile: gagal menghitung follow:",
                    followersRes.error?.message ?? followingRes.error?.message,
                );
                return json(
                    { success: false, message: "Terjadi kesalahan di server." },
                    500,
                );
            }

            return json({
                success: true,
                profile: toProfile(profile as ProfileRow),
                followers_count: followersRes.count ?? 0,
                following_count: followingRes.count ?? 0,
            });
        }

        // Ubah nama lengkap. Username sengaja tidak bisa diubah.
        if (action === "update_name") {
            const fullName = typeof payload.full_name === "string"
                ? payload.full_name.trim().replace(/\s+/g, " ")
                : "";

            if (fullName.length < NAME_MIN || fullName.length > NAME_MAX) {
                return json(
                    {
                        success: false,
                        message: `Nama harus ${NAME_MIN} sampai ${NAME_MAX} karakter.`,
                    },
                    400,
                );
            }
            if (!NAME_PATTERN.test(fullName)) {
                return json(
                    {
                        success: false,
                        message:
                            "Nama hanya boleh berisi huruf, angka, dan tanda baca sederhana.",
                    },
                    400,
                );
            }

            // Metadata Auth diubah lebih dulu karena sync-user-profile menyalinnya
            // ke users.full_name setiap login. Kalau langkah berikutnya gagal,
            // sinkronisasi login berikutnya tetap membetulkan tabel users.
            const { error: metaError } = await admin.auth.admin.updateUserById(
                authId,
                { user_metadata: { ...(authUser.user_metadata ?? {}), full_name: fullName } },
            );
            if (metaError) {
                console.error("profile: gagal mengubah metadata:", metaError.message);
                return json(
                    { success: false, message: "Gagal menyimpan nama. Coba lagi." },
                    500,
                );
            }

            const { data: updated, error: updateError } = await admin
                .from("users")
                .update({ full_name: fullName, updated_at: new Date().toISOString() })
                .eq("id", profile.id)
                .select(PROFILE_COLUMNS)
                .single();

            if (updateError) {
                console.error("profile: gagal mengubah nama:", updateError.message);
                return json(
                    { success: false, message: "Gagal menyimpan nama. Coba lagi." },
                    500,
                );
            }

            return json({ success: true, profile: toProfile(updated as ProfileRow) });
        }

        // Simpan foto yang sudah diunggah app ke bucket avatars
        if (action === "update_photo") {
            const path = typeof payload.path === "string" ? payload.path : "";
            const parts = path.split("/");

            // Path wajib berbentuk <id-akun>/avatar_<waktu>.<ext>
            if (
                parts.length !== 2 ||
                parts[0] !== authId ||
                !AVATAR_FILE_PATTERN.test(parts[1])
            ) {
                return json({ success: false, message: "Lokasi foto tidak valid." }, 400);
            }

            const { data: files, error: listError } = await admin.storage
                .from(BUCKET)
                .list(authId, { limit: 100 });
            if (listError) {
                console.error("profile: gagal membaca storage:", listError.message);
                return json(
                    { success: false, message: "Terjadi kesalahan di server." },
                    500,
                );
            }
            if (!(files ?? []).some((file) => file.name === parts[1])) {
                return json(
                    { success: false, message: "File foto tidak ditemukan." },
                    404,
                );
            }

            const publicUrl = admin.storage.from(BUCKET).getPublicUrl(path).data
                .publicUrl;

            const { data: updated, error: updateError } = await admin
                .from("users")
                .update({ photo_url: publicUrl, updated_at: new Date().toISOString() })
                .eq("id", profile.id)
                .select(PROFILE_COLUMNS)
                .single();

            if (updateError) {
                console.error("profile: gagal menyimpan foto:", updateError.message);
                return json(
                    { success: false, message: "Gagal menyimpan foto. Coba lagi." },
                    500,
                );
            }

            // Hapus foto lama supaya penyimpanan tidak menumpuk
            const oldFiles = (files ?? [])
                .map((file) => file.name)
                .filter((name) => name !== parts[1])
                .map((name) => `${authId}/${name}`);
            if (oldFiles.length > 0) {
                const { error: removeError } = await admin.storage
                    .from(BUCKET)
                    .remove(oldFiles);
                if (removeError) {
                    console.error("profile: gagal menghapus foto lama:", removeError.message);
                }
            }

            return json({ success: true, profile: toProfile(updated as ProfileRow) });
        }

        // Hapus foto profil
        if (action === "remove_photo") {
            const { data: updated, error: updateError } = await admin
                .from("users")
                .update({ photo_url: null, updated_at: new Date().toISOString() })
                .eq("id", profile.id)
                .select(PROFILE_COLUMNS)
                .single();

            if (updateError) {
                console.error("profile: gagal menghapus foto:", updateError.message);
                return json(
                    { success: false, message: "Gagal menghapus foto. Coba lagi." },
                    500,
                );
            }

            const { data: files } = await admin.storage
                .from(BUCKET)
                .list(authId, { limit: 100 });
            const paths = (files ?? []).map((file) => `${authId}/${file.name}`);
            if (paths.length > 0) {
                const { error: removeError } = await admin.storage
                    .from(BUCKET)
                    .remove(paths);
                if (removeError) {
                    console.error("profile: gagal menghapus file:", removeError.message);
                }
            }

            return json({ success: true, profile: toProfile(updated as ProfileRow) });
        }

        // Daftar followers (yang mengikuti saya) atau following (yang saya ikuti)
        if (action === "list_followers" || action === "list_following") {
            let ids: string[] = [];

            if (action === "list_followers") {
                const { data, error } = await admin
                    .from("user_follows")
                    .select("followers_id, created_at")
                    .eq("following_id", authId)
                    .order("created_at", { ascending: false })
                    .limit(MAX_LIST);
                if (error) {
                    console.error("profile: gagal membaca followers:", error.message);
                    return json(
                        { success: false, message: "Terjadi kesalahan di server." },
                        500,
                    );
                }
                ids = (data ?? []).map((row: any) => row.followers_id).filter(Boolean);
            } else {
                const { data, error } = await admin
                    .from("user_follows")
                    .select("following_id, created_at")
                    .eq("followers_id", authId)
                    .order("created_at", { ascending: false })
                    .limit(MAX_LIST);
                if (error) {
                    console.error("profile: gagal membaca following:", error.message);
                    return json(
                        { success: false, message: "Terjadi kesalahan di server." },
                        500,
                    );
                }
                ids = (data ?? []).map((row: any) => row.following_id).filter(Boolean);
            }

            if (ids.length === 0) {
                return json({ success: true, items: [] });
            }

            const { data: users, error: usersError } = await admin
                .from("users")
                .select("auth_user_id, username, full_name, photo_url")
                .in("auth_user_id", ids);
            if (usersError) {
                console.error("profile: gagal membaca pengguna:", usersError.message);
                return json(
                    { success: false, message: "Terjadi kesalahan di server." },
                    500,
                );
            }

            const byAuthId = new Map<string, any>();
            for (const user of users ?? []) byAuthId.set(user.auth_user_id, user);

            const items = ids
                .map((id) => byAuthId.get(id))
                .filter(Boolean)
                .map((user) => ({
                    username: user.username,
                    full_name: user.full_name,
                    photo_url: user.photo_url,
                }));

            return json({ success: true, items });
        }

        return json({ success: false, message: "Aksi tidak dikenali." }, 400);
    } catch (error) {
        console.error(
            "Kesalahan profile:",
            error instanceof Error ? error.message : "Unknown error",
        );
        return json(
            { success: false, message: "Terjadi kesalahan di server." },
            500,
        );
    }
});