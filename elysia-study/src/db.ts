import { PGlite } from '@electric-sql/pglite'
import { drizzle } from 'drizzle-orm/pglite'

const client = await PGlite.create({
  dataDir: 'data',
})
export const db = drizzle(client)
