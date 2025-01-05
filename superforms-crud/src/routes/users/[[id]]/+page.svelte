<script lang='ts'>
  import { page } from '$app/state';
  import SuperDebug, { superForm } from 'sveltekit-superforms';

  const { data } = $props();

  const { form, errors, constraints, enhance, delayed, message } = superForm(
    data.form,
    // to keep data after editing
    { resetForm: false },
  );
</script>

{#if $message}
  <h3 class={{ invalid: page.status >= 400 }}>
    {$message}
  </h3>
{/if}

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

  <button>Submit</button>
  {#if $delayed}
    <span>Working...</span>
  {/if}
</form>

<hr>

<SuperDebug data={$form} />

<style>
.invalid {
  color: red;
}
</style>
