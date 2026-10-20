Deno.serve(() => {
  return new Response(
    JSON.stringify({
      success: true,
      message: "Edge Function Gerak-in berjalan.",
    }),
    {
      headers: {
        "Content-Type": "application/json",
      },
    },
  );
});