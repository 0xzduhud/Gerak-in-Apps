
import bcrypt from "npm:bcryptjs@2.4.3";
import { adminDb } from "../_shared/db.ts";
import {
  handleOptions,
  jsonResponse,
} from "../_shared/cors.ts";
import { createSessionToken } from "../_shared/auth.ts";

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
    const body = await request.json();

    const email =
      typeof body.email === "string"
        ? body.email.trim().toLowerCase()
        : "";

    const password =
      typeof body.password === "string"
        ? body.password
        : "";

    if (!email || !password) {
      return jsonResponse(
        {
          success: false,
          message: "Email dan password wajib diisi.",
        },
        400,
      );
    }

    if (email.length > 254 || password.length > 72) {
      return jsonResponse(
        {
          success: false,
          message: "Email atau password tidak valid.",
        },
        400,
      );
    }

    const { data: user, error } = await adminDb
      .from("users")
      .select(
        "id, username, email, password_hash, full_name, photo_url",
      )
      .eq("email", email)
      .maybeSingle();

    if (error) {
      console.error(
        "Pencarian pengguna gagal:",
        error.message,
      );

      return jsonResponse(
        {
          success: false,
          message: "Login belum dapat diproses.",
        },
        500,
      );
    }

    if (!user) {
      return jsonResponse(
        {
          success: false,
          message: "Email atau password salah.",
        },
        401,
      );
    }

    const passwordMatches = await bcrypt.compare(
      password,
      user.password_hash,
    );

    if (!passwordMatches) {
      return jsonResponse(
        {
          success: false,
          message: "Email atau password salah.",
        },
        401,
      );
    }

    const token = await createSessionToken({
      id: user.id,
      username: user.username,
      email: user.email,
    });

    return jsonResponse({
      success: true,
      message: "Login berhasil.",
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        full_name: user.full_name,
        photo_url: user.photo_url,
      },
    });
  } catch (error) {
    console.error(
      "Kesalahan login:",
      error instanceof Error
        ? error.message
        : "Unknown error",
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
