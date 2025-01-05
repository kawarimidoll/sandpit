<script lang='ts'>
  const { children } = $props();
</script>

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
