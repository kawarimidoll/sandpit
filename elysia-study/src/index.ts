import { swagger } from '@elysiajs/swagger'
import { Elysia, t } from 'elysia'
import {
  createBook,
  createBookSchema,
  deleteBook,
  fetchBook,
  fetchBooks,
  updateBook,
  updateBookSchema,
} from './books'

const numericIdParamSchema = t.Object({ id: t.Numeric() })

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
  params: numericIdParamSchema,
})

/**
 * Create book
 */
app.post('/books', ({ body }) => createBook(body), {
  body: createBookSchema,
})

/**
 * Update book
 */
app.put(
  '/books/:id',
  ({ params: { id }, body }) => updateBook(Number(id), body),
  {
    params: numericIdParamSchema,
    body: updateBookSchema,
  },
)

/**
 * Delete book
 */
// this is not drizzle's delete()
// eslint-disable-next-line drizzle/enforce-delete-with-where
app.delete('/books/:id', ({ params: { id } }) => deleteBook(id), {
  params: numericIdParamSchema,
})

app.listen(3000)

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`,
)
console.log(
  `🔭 Swagger is running at http://${app.server?.hostname}:${app.server?.port}/swagger`,
)
