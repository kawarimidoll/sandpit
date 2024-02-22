import { lookupMimeType } from "./mime_type.ts";

function errResponse(
  status: number,
  statusText: string,
  init: ResponseInit = {},
): [BodyInit, ResponseInit] {
  return [`${status}: ${statusText}`, { status, statusText, ...init }];
}

async function genResponseArgs(request: Request) {
  const { url, method } = request;
  const body = method === "GET" ? null : await request.text();
  const { pathname } = new URL(url);

  let filename = pathname.replace(/^\//, "");

  if (filename === "" || filename.endsWith("/")) {
    filename += "index.html";
  }

  const tailPath = filename.split("/").at(-1);
  let ext = tailPath.includes(".") ? tailPath.split(".").at(-1) : "";

  if (ext === "") {
    filename += ".html";
    ext = "html";
  }

  const mimeType = lookupMimeType(ext);
  console.log({ pathname, filename, mimeType, method, body });

  if (mimeType === "") {
    return errResponse(400, "Invalid mimetype");
  }

  try {
    const file = await Deno.readTextFile(filename);
    return [file, { headers: { "content-type": mimeType } }];
  } catch (e) {
    console.warn(e);
    if (e.name === "NotFound") {
      return errResponse(404, "Not found");
    }

    return errResponse(400, "Something went wrong");
  }
}

Deno.serve(async (request: Request) => {
  const [bodyInit, responseInit] = await genResponseArgs(request);
  return new Response(bodyInit, responseInit);
});
