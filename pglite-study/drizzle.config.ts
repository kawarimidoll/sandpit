import "dotenv/config";
import { defineConfig } from "drizzle-kit";

export const DB_URL = "./data";

export default defineConfig({
  out: "./drizzle",
  schema: "./src/db/schema.ts",
  dialect: "postgresql",
  driver: "pglite",
  dbCredentials: {
    url: DB_URL,
  },
});
