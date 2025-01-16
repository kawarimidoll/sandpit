<script lang='ts'>
  import { page } from '$app/state';
  import { Toaster } from 'svelte-sonner';
  import { setupViewTransition } from 'sveltekit-view-transition';

  setupViewTransition();

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
    position: relative;
    &:hover {
      border-bottom: none;
      background-color: rgba(0, 0, 0, 0.1);
    }
    &.active::before {
      view-transition-name: active-page;
      content: '';
      position: absolute;
      bottom: 0;
      left: 0;
      width: 100%;
      height: 2px;
      background-color: #45d;
    }
  }
}
</style>
