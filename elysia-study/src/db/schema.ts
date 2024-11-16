import { pgTable, serial, timestamp, varchar } from 'drizzle-orm/pg-core'
import { createInsertSchema } from 'drizzle-typebox'

export const books = pgTable('books', {
  bookId: serial().primaryKey(),
  title: varchar({ length: 255 }).notNull(),
  author: varchar({ length: 255 }).notNull(),
  createdAt: timestamp({ withTimezone: true }).defaultNow(),
  updatedAt: timestamp({ withTimezone: true }).defaultNow(),
})

const { properties, ...rest } = createInsertSchema(books)
delete properties.bookId
delete properties.createdAt
delete properties.updatedAt

export const insertBookSchema = { ...rest, properties }

console.log('insertBookSchema')
console.log(insertBookSchema)
