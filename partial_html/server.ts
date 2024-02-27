const contentTypes = {
  html: "text/html",
  css: "text/css",
  js: "text/javascript",
};

async function handler(request: Request): [BodyInit, ResponseInit] {
  const { pathname } = new URL(request.url);
  const filename = pathname === "/" ? "index.html" : pathname.replace("/", "");

  const ext = filename.match(/\.([A-Za-z0-9]+)$/)?.[1] || "";

  console.log({ pathname, ext });

  try {
    const src = await Deno.readTextFile(filename);
    return [src, { headers: { "content-type": contentTypes[ext] } }];
  } catch (e) {
    console.warn(e);

    const [status, statusText] = (e.name === "NotFound")
      ? [404, "Not Found"]
      : [500, "Internal Server Error"];

    return [`${status}: ${statusText}`, { status, statusText }];
  }
}

Deno.serve(async (request: Request) => new Response(...await handler(request)));
