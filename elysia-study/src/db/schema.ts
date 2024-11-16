import { pgTable, serial, timestamp, varchar } from 'drizzle-orm/pg-core'

export const books = pgTable('books', {
  bookId: serial().primaryKey(),
  title: varchar({ length: 255 }).notNull(),
  author: varchar({ length: 255 }).notNull(),
  createdAt: timestamp({ withTimezone: true }).defaultNow(),
  updatedAt: timestamp({ withTimezone: true }).defaultNow(),
})
