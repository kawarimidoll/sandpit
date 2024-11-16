import { eq } from 'drizzle-orm'
import { db } from './db/instance'
import { books } from './db/schema'

export function fetchBooks() {
  return db.select().from(books)
}

export function fetchBook(id: number) {
  return db.select().from(books).where(eq(books.bookId, id))
}

export function createBook(bookData: Omit<typeof books.$inferInsert, 'bookId' | 'createdAt' | 'updatedAt'>) {
  return db.insert(books).values(bookData).returning()
}

export function updateBook(id: number, bookData: Partial<typeof books.$inferInsert>) {
  return db.update(books).set(bookData).where(eq(books.bookId, id)).returning()
}

export function deleteBook(id: number) {
  return db.delete(books).where(eq(books.bookId, id)).returning()
}
