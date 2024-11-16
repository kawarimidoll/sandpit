import { defineConfig } from 'drizzle-kit'

export const LOCAL_DB_URL = 'data'

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/db/schema.ts',
  out: './drizzle',
  dbCredentials: {
    url: LOCAL_DB_URL,
  },
  driver: 'pglite',
})
