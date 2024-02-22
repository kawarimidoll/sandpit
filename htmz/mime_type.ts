// https://github.com/stackinspector/mime_types/blob/main/mod.ts

const types: Record<string, string> = Object.create(null);

const MIME_DB_URL = "https://cdn.jsdelivr.net/gh/jshttp/mime-db@master/db.json";
const db: Record<string, Source> = await (await fetch(MIME_DB_URL)).json();

function createTypeMap() {
  // source preference (least -> most)
  const preference = ["nginx", "apache", undefined, "iana"];

  for (const [type, mime] of Object.entries(db)) {
    const exts = mime.extensions;

    if (!exts?.length) {
      continue;
    }

    // extension -> mime
    for (const extension of exts) {
      if (types[extension]) {
        const from = preference.indexOf(db[types[extension]].source);
        const to = preference.indexOf(mime.source);

        if (
          types[extension] !== "application/octet-stream" &&
          (from > to ||
            (from === to && types[extension].startsWith("application/")))
        ) {
          // skip the remapping
          continue;
        }
      }

      // set the extension -> mime
      types[extension] = type;
    }
  }
}

createTypeMap();

export function lookupMimeType(path: string) {
  if (!path || typeof path !== "string") {
    return "";
  }

  const extension = path.replace(/^.*\./, "").toLowerCase();

  if (!extension) {
    return "";
  }

  return types[extension] || "";
}
