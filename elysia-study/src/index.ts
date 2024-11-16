import { swagger } from '@elysiajs/swagger'
import { Elysia, t } from 'elysia'
import {
  createBook,
  deleteBook,
  fetchBook,
  fetchBooks,
  updateBook,
} from './books'
import { insertBookSchema } from './db/schema'

const app = new Elysia()

app.use(swagger())

/**
 * Get all books
 */
app.get('/books', () => fetchBooks())

/**
 * Get book by id
 */
app.get('/books/:id', ({ params: { id } }) => fetchBook(id), {
  params: t.Object({
    id: t.Numeric(),
  }),
})

/**
 * Create book
 */
app.post('/books', ({ body }) => createBook(body), {
  body: insertBookSchema,
})

/**
 * Update book
 */
app.put(
  '/books/:id',
  ({ params: { id }, body }) => updateBook(Number(id), body),
  {
    params: t.Object({
      id: t.Numeric(),
    }),
    body: insertBookSchema,
  },
)

/**
 * Delete book
 */
// this is not drizzle's delete()
// eslint-disable-next-line drizzle/enforce-delete-with-where
app.delete('/books/:id', ({ params: { id } }) => deleteBook(id), {
  params: t.Object({
    id: t.Numeric(),
  }),
})

app.listen(3000)

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`,
)
console.log(
  `🔭 Swagger is running at http://${app.server?.hostname}:${app.server?.port}/swagger`,
)
