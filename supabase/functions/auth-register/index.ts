
import bcrypt from "npm:bcryptjs@2.4.3";
import { adminDb } from "../_shared/db.ts";
import {
  handleOptions,
  jsonResponse,
} from "../_shared/cors.ts";
import { createSessionToken } from "../_shared/auth.ts";

console.log("AUTH REGISTER: semua import berhasil");

Deno.serve(async (request: Request) => {
  const optionsResponse = handleOptions(request);

  if (optionsResponse) {
    return optionsResponse;
  }

  if (request.method !== "POST") {
    return jsonResponse(
      {
        success: false,
        message: "Metode tidak diizinkan.",
      },
      405,
    );
  }

  try {
    console.log("REGISTER STEP 1: request diterima");

    const body = await request.json();

    console.log("REGISTER STEP 2: body berhasil dibaca");

    const username =
      typeof body.username === "string"
        ? body.username.trim().toLowerCase()
        : "";

    const email =
      typeof body.email === "string"
        ? body.email.trim().toLowerCase()
        : "";

    const password =
      typeof body.password === "string"
        ? body.password
        : "";

    const fullName =
      typeof body.full_name === "string"
        ? body.full_name.trim()
        : "";

    if (!username || !email || !password) {
      return jsonResponse(
        {
          success: false,
          message: "Username, email, dan password wajib diisi.",
        },
        400,
      );
    }

    if (!/^[a-z0-9_]{3,30}$/.test(username)) {
      return jsonResponse(
        {
          success: false,
          message:
            "Username harus 3–30 karakter dan hanya memakai huruf kecil, angka, atau underscore.",
        },
        400,
      );
    }

    if (
      email.length > 254 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    ) {
      return jsonResponse(
        {
          success: false,
          message: "Format email tidak valid.",
        },
        400,
      );
    }

    if (password.length < 8 || password.length > 72) {
      return jsonResponse(
        {
          success: false,
          message: "Password harus terdiri dari 8–72 karakter.",
        },
        400,
      );
    }

    if (fullName.length > 100) {
      return jsonResponse(
        {
          success: false,
          message: "Nama terlalu panjang.",
        },
        400,
      );
    }

    console.log("REGISTER STEP 3: memeriksa email");

    const { data: existingEmail, error: emailError } =
      await adminDb
        .from("users")
        .select("id")
        .eq("email", email)
        .maybeSingle();

    if (emailError) {
      console.error("Pemeriksaan email gagal:", emailError.message);

      return jsonResponse(
        {
          success: false,
          message: "Registrasi belum dapat diproses.",
        },
        500,
      );
    }

    if (existingEmail) {
      return jsonResponse(
        {
          success: false,
          message: "Email sudah terdaftar.",
        },
        409,
      );
    }

    console.log("REGISTER STEP 4: memeriksa username");

    const { data: existingUsername, error: usernameError } =
      await adminDb
        .from("users")
        .select("id")
        .eq("username", username)
        .maybeSingle();

    if (usernameError) {
      console.error(
        "Pemeriksaan username gagal:",
        usernameError.message,
      );

      return jsonResponse(
        {
          success: false,
          message: "Registrasi belum dapat diproses.",
        },
        500,
      );
    }

    if (existingUsername) {
      return jsonResponse(
        {
          success: false,
          message: "Username sudah digunakan.",
        },
        409,
      );
    }

    console.log("REGISTER STEP 5: mulai hashing password");

    const passwordHash = await bcrypt.hash(password, 10);

    console.log("REGISTER STEP 6: hashing selesai");
    console.log("REGISTER STEP 7: mulai insert database");

    const { data: newUser, error: insertError } =
      await adminDb
        .from("users")
        .insert({
          username,
          email,
          password_hash: passwordHash,
          full_name: fullName || null,
        })
        .select("id, username, email, full_name, photo_url")
        .single();

    if (insertError || !newUser) {
      console.error(
        "Penyimpanan pengguna gagal:",
        insertError?.message ?? "Data pengguna tidak dikembalikan",
      );

      if (insertError?.code === "23505") {
        return jsonResponse(
          {
            success: false,
            message: "Email atau username sudah terdaftar.",
          },
          409,
        );
      }

      return jsonResponse(
        {
          success: false,
          message: "Registrasi gagal disimpan.",
        },
        500,
      );
    }

    console.log("REGISTER STEP 8: database berhasil");

    const token = await createSessionToken({
      id: newUser.id,
      username: newUser.username,
      email: newUser.email,
    });

    console.log("REGISTER STEP 9: token berhasil dibuat");

    return jsonResponse(
      {
        success: true,
        message: "Registrasi berhasil.",
        token,
        user: {
          id: newUser.id,
          username: newUser.username,
          email: newUser.email,
          full_name: newUser.full_name,
          photo_url: newUser.photo_url,
        },
      },
      201,
    );
  } catch (error) {
    console.error(
      "Kesalahan registrasi:",
      error instanceof Error ? error.message : "Unknown error",
    );

    return jsonResponse(
      {
        success: false,
        message: "Terjadi kesalahan pada server.",
      },
      500,
    );
  }
});
