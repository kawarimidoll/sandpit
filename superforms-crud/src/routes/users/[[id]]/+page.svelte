<script lang='ts'>
  import type { PageServerData } from './$types';
  import { dev } from '$app/environment';
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

<a href='/users/new' class='button'>Add new user</a>

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

{#snippet errorSpan(key: keyof typeof $errors)}
  {#if $errors[key]}
    <span class='invalid'>{$errors[key]}</span>
  {/if}
{/snippet}

{#if $form.id || data.isNew}
  <!-- https://qiita.com/maabow/items/9757a25eb5a8badaeb28 -->
  <div class='modal' id='modal'>
    <a href='/users' class='modal-background' aria-label='close'></a>
    <div class='modal-wrapper'>
      <a href='/users' class='close'>&times;</a>
      <div class='modal-content'>
        <h2>{!$form.id ? 'Create' : 'Update'} user</h2>
        <form method='POST' use:enhance>
          <input type='hidden' name='id' bind:value={$form.id} />

          <label>
            Name<br />
            <input
              name='name'
              aria-invalid={$errors.name ? 'true' : undefined}
              bind:value={$form.name}
              {...$constraints.name} />
            {@render errorSpan('name')}
          </label>

          <label>
            E-mail<br />
            <input
              name='email'
              type='email'
              aria-invalid={$errors.email ? 'true' : undefined}
              bind:value={$form.email}
              {...$constraints.email} />
            {@render errorSpan('email')}
          </label>

          <label>
            Level<br />
            <select name='level' bind:value={$form.level}>
              <option value='' disabled>Select a level</option>
              {#each userLevels as level}
                <option value={level}>{level}</option>
              {/each}
            </select>
            {@render errorSpan('level')}
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

        {#if dev}
          <div style='margin-top: 1rem;'>
            <SuperDebug data={$form} display={dev} />
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
/* like a button of sakura-css */
a.button {
  color: #f9f9f9 !important;
  line-height: 1.15;
  &:hover {
    border-width: 1px;
  }
}

.modal {
  position: fixed;
  top: 0;
  left: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background-color: rgb(0 0 0 / 60%);

  .modal-background {
    cursor: default;
    position: fixed;
    top: 0;
    left: 0;
    z-index: -1;
    width: 100%;
    height: 100%;
    background-color: transparent;
  }

  .modal-wrapper {
    position: relative;
    width: 80%;
    max-width: 500px;
    max-height: 70%;
    padding: 20px;
    margin: auto;
    overflow: scroll;
    background-color: #FEFEFE;
    border-radius: 5px;

    .close {
      position: absolute;
      top: 20px;
      right: 20px;
      font-size: 24px;
      cursor: pointer;
      transform: translate(50%, -50%);
    }
  }
}

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

</style>
