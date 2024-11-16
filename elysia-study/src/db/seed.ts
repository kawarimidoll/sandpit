import { db } from './instance'
import { books } from './schema'

await db.insert(books).values([
  {
    title: 'sample1',
    author: 't_o_d',
  },
  {
    title: 'sample2',
    author: 't_o_d',
  },
  {
    title: 'sample3',
    author: 't_o_d',
  },
])
