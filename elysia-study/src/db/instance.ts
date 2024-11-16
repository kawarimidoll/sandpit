import { PGlite } from '@electric-sql/pglite'
import { drizzle } from 'drizzle-orm/pglite'
import { LOCAL_DB_URL } from '../../drizzle.config.js'

const client = await PGlite.create({
  dataDir: LOCAL_DB_URL,
})
const casing = 'snake_case'

export const db = drizzle({ client, casing })
