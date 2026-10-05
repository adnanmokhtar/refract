<script lang="ts">
  import { createQuery } from '@tanstack/svelte-query';

  type StoreStock = { id: string; name: string; qty: number };
  let { sku }: { sku: string } = $props();

  const query = createQuery(() => ({
    queryKey: ['stock', sku],
    queryFn: async (): Promise<StoreStock[]> =>
      (await fetch(`/api/stock/${sku}`, { signal: AbortSignal.timeout(5000) })).json(),
  }));
</script>

{#if query.isPending}
  <span class="lumen-badge" aria-busy="true">Checking stock…</span>
{:else if query.isError}
  <p role="status">
    Stock is unavailable right now.
    <button type="button" onclick={() => query.refetch()}>Try again</button>
  </p>
{:else if query.data}
  <ul class="lumen-stock">
    {#each query.data as store (store.id)}
      <li>{store.name}: {store.qty}</li>
    {:else}
      <li>Out of stock in every store.</li>
    {/each}
  </ul>
{/if}
