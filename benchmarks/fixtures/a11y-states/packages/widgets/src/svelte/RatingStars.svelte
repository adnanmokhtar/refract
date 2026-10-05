<script lang="ts">
  let { value, max = 5 }: { value: number; max?: number } = $props();
  const stars = $derived(Array.from({ length: max }, (_, i) => i < Math.round(value)));
</script>

<p class="lumen-stars" role="img" aria-label={`${value} out of ${max}`}>
  {#each stars as filled, i (i)}
    <span aria-hidden="true" class:filled>★</span>
  {/each}
</p>

<style>
  .lumen-stars {
    display: inline-flex;
  }

  .filled {
    color: var(--lumen-star, currentColor);
  }
</style>
