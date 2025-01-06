import { userId, users, userSchema } from '$lib/users';
import { error } from '@sveltejs/kit';
import { redirect } from 'sveltekit-flash-message/server';
import { message, superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';

// id is required in userSchema, but it should be null when creating a new user
// so we extend the schema to make it optional
const crudSchema = userSchema.extend({
  id: userSchema.shape.id.optional(),
});

// A fundamental idea in Superforms:
// you can pass either empty data or an entity partially matching the schema to superValidate,
// and it will generate default values for any non-specified fields, ensuring type safety.
// https://superforms.rocks/default-values

export async function load({ params }) {
  // READ user
  const user = users.find(u => u.id === params.id);

  if (params.id && !user) {
    console.log('User not found.');
    throw error(404, 'User not found.');
  }

  // If user is null, default values for the schema will be returned.
  const form = await superValidate(user, zod(crudSchema));
  return { form, users };
}

export const actions = {
  default: async ({ request, cookies }) => {
    const formData = await request.formData();
    const form = await superValidate(formData, zod(crudSchema));
    console.log({ formData, form });

    if (formData.has('delay')) {
      await new Promise(r => setTimeout(r, 4000));
    }

    if (!form.valid) {
      // message() will return status 400 implicitly when form isn't valid
      return message(form, 'Invalid form data.');
    };

    if (!form.data.id) {
      // CREATE user
      // We just push the new user to the array, but in a real app you would save it to a database.
      const user = { ...form.data, id: userId() };
      users.push(user);

      return message(form, 'User created!');
    }

    const index = users.findIndex(u => u.id === form.data.id);
    if (index < 0) {
      console.log('User not found.');
      return message(form, 'User not found.', { status: 404 });
    }
    if (formData.has('delete')) {
      // DELETE user
      // We just update the user in the array, but in a real app you would save it to a database.
      users.splice(index, 1);
      return redirect('/users', 'User deleted!', cookies);
    }
    else {
      // UPDATE user
      // We just update the user in the array, but in a real app you would save it to a database.
      users[index] = { ...form.data, id: form.data.id };
      return message(form, 'User updated!');
    }
  },
};
