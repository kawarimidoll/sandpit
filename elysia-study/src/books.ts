import { type Static, Type } from '@sinclair/typebox'
import { eq } from 'drizzle-orm'
import { createInsertSchema } from 'drizzle-typebox'
import { db } from './db/instance'
import { books } from './db/schema'

export function fetchBooks() {
  return db.select().from(books)
}

export function fetchBook(id: number) {
  return db.select().from(books).where(eq(books.bookId, id))
}

export const createBookSchema = Type.Pick(createInsertSchema(books), ['title', 'author'])
export function createBook(bookData: Static<createBookSchema>) {
  return db.insert(books).values(bookData).returning()
}

export const updateBookSchema = Type.Partial(createBookSchema)
export function updateBook(id: number, bookData: Static<updateBookSchema>) {
  return db.update(books).set(bookData).where(eq(books.bookId, id)).returning()
}

export function deleteBook(id: number) {
  return db.delete(books).where(eq(books.bookId, id)).returning()
}
