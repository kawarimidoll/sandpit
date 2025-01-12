<script lang='ts'>
  import type { PageServerData } from './$types';
  import { page } from '$app/state';
  // store is deprecated but sveltekit-flash-message uses it
  import { page as pageStore } from '$app/stores';
  import { userLevels } from '$lib/users';
  import { toast } from 'svelte-sonner';
  import { getFlash } from 'sveltekit-flash-message';
  import SuperDebug, { superForm } from 'sveltekit-superforms';

  const { data }: { data: PageServerData } = $props();

  const { form, errors, constraints, enhance, delayed, message } = superForm(
    data.form,
    // to keep data after editing
    {
      taintedMessage: true,
      resetForm: false,
      onUpdated({ form }) {
        if (form.message) {
          // Display the message using a toast library
          if (page.status >= 400) {
            toast.error(form.message);
          }
          else {
            toast.success(form.message);
          }
        }
      },
    },
  );

  const flash = getFlash(pageStore);
  $effect(() => {
    if ($flash) {
      if (page.status >= 400) {
        toast.error($flash);
      }
      else {
        toast.success($flash);
      }
    }
  });
</script>

<h1>Users</h1>

<table>
  <thead>
    <tr>
      <th>Id</th>
      <th>Name</th>
      <th>Email</th>
      <th>Level</th>
    </tr>
  </thead>
  <tbody>
    {#each data.users as user}
      <tr>
        <td><a href='/users/{user.id}'>{user.id}</td>
        <td>{user.name}</td>
        <td>{user.email}</td>
        <td>{user.level}</td>
      </tr>
    {/each}
  </tbody>
</table>

<h2>{!$form.id ? 'Create' : 'Update'} user </h2>

<form method='POST' use:enhance>
  <input type='hidden' name='id' bind:value={$form.id} />

  <label>
    Name<br />
    <input
      name='name'
      aria-invalid={$errors.name ? 'true' : undefined}
      bind:value={$form.name}
      {...$constraints.name} />
    {#if $errors.name}
      <span class='invalid'>{$errors.name}</span>
    {/if}
  </label>

  <label>
    E-mail<br />
    <input
      name='email'
      type='email'
      aria-invalid={$errors.email ? 'true' : undefined}
      bind:value={$form.email}
      {...$constraints.email} />
    {#if $errors.email}
      <span class='invalid'>{$errors.email}</span>
    {/if}
  </label>

  <label>
    Level<br />
    <select name='level' bind:value={$form.level}>
      <option value='' disabled>Select a level</option>
      {#each userLevels as level}
        <option value={level}>{level}</option>
      {/each}
    </select>
    {#if $errors.level}
      <span class='invalid'>{$errors.level}</span>
    {/if}
  </label>

  <button disabled={$delayed}>Submit</button>
  <button name='delay' class='delay' disabled={$delayed}>Submit delayed</button>
  {#if $form.id}
    <!-- eslint-disable no-alert -->
    <button
      name='delete'
      onclick={e => !confirm('Are you sure?') && e.preventDefault()}
      class='danger'
      disabled={$delayed}>Delete user</button>
    <!-- eslint-enable no-alert -->
  {/if}

  {#if $delayed}
    <span>Working...</span>
  {/if}
  {#if $message}
    <span class={{ invalid: page.status >= 400 }}>{$message}</span>
  {/if}
</form>

<hr>

<SuperDebug data={$form} />

<style>
.invalid {
  color: red;
}

.danger {
  background-color: brown;
}

.delay {
  background-color: darkblue;
}

button:disabled {
  background-color: lightgray;
}

hr {
  width: 100%;
  margin-block: 2em;
}

</style>
