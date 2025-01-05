<script lang='ts'>
  import { Toaster } from 'svelte-sonner';
  const { children } = $props();
</script>

<Toaster />

<header>
  <a href='/'>Top</a>
  <a href='/users'>Users</a>
</header>

{@render children()}

<style>
header {
  border-bottom: 1px solid #ccc;
  a {
    display: inline-block;
    padding: 1rem;
    &:hover{
border: none;
    }
  }
}
</style>
