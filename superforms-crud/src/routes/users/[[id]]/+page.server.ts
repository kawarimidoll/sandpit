import { users, userSchema } from '$lib/users';

import { error } from '@sveltejs/kit';
import { superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';

// id is required in userSchema, but it should be null when creating a new user
// so we extend the schema to make it optional
const crudSchema = userSchema.extend({
  id: userSchema.shape.id.optional(),
});

// A fundamental idea in Superforms:
// you can pass either empty data or an entity partially matching the schema to superValidate,
// and it will generate default values for any non-specified fields, ensuring type safety.

export async function load({ params }) {
  // READ user
  const user = users.find(u => u.id === params.id);

  if (params.id && !user) {
    throw error(404, 'User not found.');
  }

  // If user is null, default values for the schema will be returned.
  const form = await superValidate(user, zod(crudSchema));
  return { form, users };
}
