import { adminDb } from "../_shared/db.ts";

Deno.serve(async () => {
  const startedAt = Date.now();

  try {
    const { data, error } = await adminDb
      .from("users")
      .select("id")
      .limit(1);

    if (error) {
      console.error("DB TEST ERROR:", error.message);

      return new Response(
        JSON.stringify({
          success: false,
          message: "Query database gagal.",
          detail: error.message,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Koneksi database berhasil.",
        elapsed_ms: Date.now() - startedAt,
        query_returned_rows: data.length,
      }),
      {
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error(
      "DB TEST EXCEPTION:",
      error instanceof Error ? error.message : "Unknown error",
    );

    return new Response(
      JSON.stringify({
        success: false,
        message: "Terjadi kesalahan saat menguji database.",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});