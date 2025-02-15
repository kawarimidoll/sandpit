import { z } from 'zod';

export const userLevels = ['limited', 'normal', 'super'] as const;

// See https://zod.dev/?id=primitives for schema syntax
export const userSchema = z.object({
  id: z.string().regex(/^\d+$/),
  name: z.string().min(2),
  email: z.string().email(),
  level: z.enum(userLevels),
});

type UserDB = z.infer<typeof userSchema>[];

// Let's worry about id collisions later
export const userId = () => String(Math.random()).slice(2);

// A simple user "database"
export const users: UserDB = [
  {
    id: userId(),
    name: 'Important Customer',
    email: 'important@example.com',
    level: 'normal',
  },
  {
    id: userId(),
    name: 'Super Customer',
    email: 'super@example.com',
    level: 'super',
  },
];

console.log(users);
