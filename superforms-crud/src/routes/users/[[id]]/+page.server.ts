import { userSchema } from '$lib/users';

// id is required in userSchema, but it should be null when creating a new user
// so we extend the schema to make it optional
const crudSchema = userSchema.extend({
  id: userSchema.shape.id.optional(),
});

// A fundamental idea in Superforms:
// you can pass either empty data or an entity partially matching the schema to superValidate,
// and it will generate default values for any non-specified fields, ensuring type safety.
