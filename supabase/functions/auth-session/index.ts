
import {
  getSessionUser,
} from "../_shared/auth.ts";
import {
  handleOptions,
  jsonResponse,
} from "../_shared/cors.ts";

Deno.serve(async (request: Request) => {
  const optionsResponse = handleOptions(request);

  if (optionsResponse) {
    return optionsResponse;
  }

  if (request.method !== "GET") {
    return jsonResponse(
      {
        success: false,
        message: "Metode tidak diizinkan.",
      },
      405,
    );
  }

  try {
    const sessionUser = await getSessionUser(request);

    if (!sessionUser) {
      return jsonResponse(
        {
          success: false,
          message: "Sesi tidak valid atau sudah kedaluwarsa.",
        },
        401,
      );
    }

    return jsonResponse({
      success: true,
      message: "Sesi valid.",
      user: {
        id: sessionUser.id,
        username: sessionUser.username,
        email: sessionUser.email,
      },
    });
  } catch (error) {
    console.error(
      "Kesalahan validasi sesi:",
      error instanceof Error ? error.message : "Unknown error",
    );

    return jsonResponse(
      {
        success: false,
        message: "Sesi belum dapat diperiksa.",
      },
      500,
    );
  }
});
