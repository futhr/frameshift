<script lang="ts">
import { onMount } from "svelte"
import type { SourceDocument } from "$phoenix/types"

let sources = $state<SourceDocument[]>([])
let status = $state<"loading" | "ready" | "error">("loading")

async function loadSources() {
  status = "loading"
  try {
    const response = await fetch("/api/sources")
    if (!response.ok) throw new Error("unavailable")
    const page = await response.json()
    sources = page.data
    status = "ready"
  } catch {
    status = "error"
  }
}

onMount(loadSources)
</script>

<svelte:head>
  <title>Frameshift · Component evidence</title>
  <meta name="description" content="Manufacturer documentation and exact source revisions behind Frameshift component profiles." />
</svelte:head>

<main class="mx-auto max-w-5xl px-6 py-12 sm:px-10">
  <header class="mb-16 border-b border-line pb-8">
    <p class="mb-8 text-xl font-semibold tracking-tight">Frameshift</p>
    <p class="mb-3 text-sm font-semibold uppercase tracking-widest text-accent">Component evidence</p>
    <h1 class="mb-5 text-4xl font-medium tracking-tight sm:text-5xl">Start with the facts.</h1>
    <p class="max-w-2xl text-lg leading-relaxed text-muted">Each component profile starts with manufacturer documentation. Exact revisions and unresolved facts stay visible when you plan your frame.</p>
  </header>

  <section aria-labelledby="sources-heading">
    <h2 id="sources-heading" class="mb-2 text-2xl font-medium">Source documents</h2>
    <p class="mb-8 text-muted">A document records a source. It does not establish that a complete assembly has been tested.</p>
    <div aria-live="polite">
      {#if status === 'loading'}
        <p class="py-8 text-muted">Loading source records…</p>
      {:else if status === 'error'}
        <p class="mb-4">Source records are temporarily unavailable.</p>
        <button class="rounded-lg bg-ink px-5 py-3 font-medium text-white" onclick={loadSources}>Try again</button>
      {:else if sources.length === 0}
        <p class="rounded-xl border border-line p-8 text-muted">No source documents have been recorded in this catalog.</p>
      {:else}
        <ul class="divide-y divide-line border-y border-line">
          {#each sources as source (source.id)}
            <li class="py-6">
              <a class="text-lg font-semibold" href={source.uri} target="_blank" rel="noopener noreferrer">{source.title}</a>
              <p class="mt-2 text-sm text-muted">{source.kind} · Revision {source.revision}</p>
            </li>
          {/each}
        </ul>
      {/if}
    </div>
  </section>
</main>
