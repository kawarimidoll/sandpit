import { lookupMimeType } from "./mime_type.ts";

function errResponse(
  status: number,
  statusText: string,
  init: ResponseInit = {},
): [BodyInit, ResponseInit] {
  return [`${status}: ${statusText}`, { status, statusText, ...init }];
}

function parseParams(
  text: string,
): Record<string, string | string[]> {
  if (!text) return {};
  const obj = {};
  (new URLSearchParams(text)).forEach((value, key) => {
    if (Object.hasOwn(key)) {
      if (typeof obj[key] === "string") {
        obj[key] = [obj[key]];
      }
      obj[key].push(value);
    } else {
      obj[key] = value;
    }
  });
  return obj;
}
function replaceMarks(
  text: string,
  replaceSpec: Record<string, string>,
): string {
  for (const [k, v] of Object.entries(replaceSpec)) {
    const re = new RegExp(`\\$\\$${k}`, "g");
    // console.log({ text, k, v });
    text = text.replace(re, v);
  }
  return text;
}

const db = {};
async function genResponseArgs(request: Request) {
  const { pathname, search } = new URL(request.url);
  const rawParams = (request.method === "POST") ? await request.text() : search;
  const params = parseParams(rawParams);
  const method = params._method ?? request.method;

  let filename = pathname.replace(/^\//, "");

  if (filename === "" || filename.endsWith("/")) {
    filename += "index.html";
  }

  let ext = filename.match(/\.(\w+)$/)?.[1] || "";

  if (ext === "") {
    filename += ".html";
    ext = "html";
  }

  let all = false;
  if (method === "POST") {
    if (Object.hasOwn(params, "id")) {
      db[params["id"]] = params["content"];
    }
  } else if (method === "PUT") {
    db[params["id"]] = params["content"];
  } else if (method === "DELETE") {
    if (Object.hasOwn(params, "id")) {
      delete db[params["id"]];
    }
  } else {
    // GET
    if (Object.hasOwn(params, "id")) {
      params["content"] = db[params["id"]];
    }
    if (Object.hasOwn(params, "all")) {
      all = true;
    }
  }

  const mimeType = lookupMimeType(ext);
  console.log({
    pathname,
    filename,
    mimeType,
    method,
    params,
    search,
    db,
  });

  if (mimeType === "") {
    return errResponse(400, "Invalid mimetype");
  }

  try {
    const file = await Deno.readTextFile(filename);

    if (all) {
      const html = Object.entries(db).map(([id, content]) =>
        replaceMarks(file, { id, content })
      ).join("");

      return [html, {
        headers: { "content-type": mimeType },
        status: 200,
      }];
    } else {
      return [replaceMarks(file, params), {
        headers: { "content-type": mimeType },
        status: 200,
      }];
    }
  } catch (e) {
    console.warn(e);
    if (e.name === "NotFound") {
      return errResponse(404, "Not found");
    }

    return errResponse(400, "Something went wrong");
  }
}

Deno.serve(async (request: Request) =>
  new Response(...await genResponseArgs(request))
);
