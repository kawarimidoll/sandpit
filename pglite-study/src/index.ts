import { PGlite } from "@electric-sql/pglite";
import { drizzle } from "drizzle-orm/pglite";
import DB_URL from "../../drizzle.config.ts"

const client = new PGlite(DB_URL);
const db = drizzle({ client });
