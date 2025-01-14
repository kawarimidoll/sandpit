<script lang='ts'>
  import { page } from '$app/state';
  import { Toaster } from 'svelte-sonner';

  const { children } = $props();

  const navs = [
    { href: '/', text: 'Top' },
    { href: '/users', text: 'Users' },
  ];
</script>

<Toaster />

<header>
  {#each navs as { href, text }}
    <a {href} class={{ active: href === '/'
      ? page.url.pathname === href
      : page.url.pathname.startsWith(href),
    }}>{text}</a>
  {/each}
</header>

{@render children()}

<style>
header {
  border-bottom: 1px solid #ccc;
  a {
    display: inline-block;
    padding: 1rem;
    &.active {
      border-bottom: 2px solid #45d;
    }
  }
}
</style>
