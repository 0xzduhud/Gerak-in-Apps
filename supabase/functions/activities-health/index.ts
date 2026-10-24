
Deno.serve((req: Request) => {
  return new Response(
    JSON.stringify({
      success: true,
      message: "Edge Function runtime berfungsi.",
      method: req.method,
      timestamp: new Date().toISOString(),
    }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
      },
    },
  );
});
