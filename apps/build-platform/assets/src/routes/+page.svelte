<script lang="ts">
import { onMount } from "svelte"
import type { ProfileRevision, SourceDocument } from "$phoenix/types"

type Page<T> = { data: T[]; more: boolean; offset: number }

let profiles = $state<ProfileRevision[]>([])
let profilePage = $state({ loading: false, loaded: false, error: false, more: false })
let profileOffset = $state(0)
let sources = $state<SourceDocument[]>([])
let sourcePage = $state({ loading: false, loaded: false, error: false, more: false })
let sourceOffset = $state(0)

async function fetchPage<T>(path: string, offset: number): Promise<Page<T>> {
  const response = await fetch(`${path}?offset=${offset}`)
  if (!response.ok) throw new Error("unavailable")

  const page: unknown = await response.json()
  if (
    typeof page !== "object" ||
    page === null ||
    !("data" in page) ||
    !Array.isArray(page.data) ||
    !("more" in page) ||
    typeof page.more !== "boolean" ||
    !("offset" in page) ||
    page.offset !== offset
  )
    throw new Error("invalid_page")

  return page as Page<T>
}

async function loadProfiles() {
  if (profilePage.loading) return
  profilePage.loading = true
  profilePage.error = false

  try {
    const page = await fetchPage<ProfileRevision>("/api/profiles", profileOffset)
    const seen = new Set(profiles.map((profile) => profile.id))
    profiles = [...profiles, ...page.data.filter((profile) => !seen.has(profile.id))]
    profileOffset += page.data.length
    profilePage.more = page.more && page.data.length > 0 && profileOffset <= 10_000
    profilePage.loaded = true
  } catch {
    profilePage.error = true
  } finally {
    profilePage.loading = false
  }
}

async function loadSources() {
  if (sourcePage.loading) return
  sourcePage.loading = true
  sourcePage.error = false

  try {
    const page = await fetchPage<SourceDocument>("/api/sources", sourceOffset)
    const seen = new Set(sources.map((source) => source.id))
    sources = [...sources, ...page.data.filter((source) => !seen.has(source.id))]
    sourceOffset += page.data.length
    sourcePage.more = page.more && page.data.length > 0 && sourceOffset <= 10_000
    sourcePage.loaded = true
  } catch {
    sourcePage.error = true
  } finally {
    sourcePage.loading = false
  }
}

onMount(() => {
  void loadProfiles()
  void loadSources()
})
</script>

<svelte:head>
  <title>Frameshift · Component evidence</title>
  <meta name="description" content="Candidate frame component profiles and exact source revisions, with qualification limits kept visible." />
</svelte:head>

<main class="mx-auto max-w-5xl px-6 py-12 sm:px-10">
  <header class="mb-16 border-b border-line pb-8">
    <p class="mb-8 text-xl font-semibold tracking-tight">Frameshift</p>
    <p class="mb-3 text-sm font-semibold uppercase tracking-widest text-accent">Component evidence</p>
    <h1 class="mb-5 text-4xl font-medium tracking-tight sm:text-5xl">Start with the facts.</h1>
    <p class="max-w-2xl text-lg leading-relaxed text-muted">These component records help frame planning. Source revisions and candidate status stay visible; they do not approve a complete assembly.</p>
  </header>

  <section aria-labelledby="profiles-heading" class="mb-16">
    <h2 id="profiles-heading" class="mb-2 text-2xl font-medium">Candidate profiles</h2>
    <p class="mb-8 text-muted">Download exact profile bytes for inspection. Candidate status does not establish physical compatibility or a build result.</p>
    <div aria-live="polite">
      {#if !profilePage.loaded && !profilePage.error}
        <p class="py-8 text-muted">Loading candidate profiles…</p>
      {:else if !profilePage.loaded && profilePage.error}
        <p class="mb-4">Candidate profiles are temporarily unavailable.</p>
        <button class="rounded-lg bg-ink px-5 py-3 font-medium text-white" onclick={loadProfiles}>Try again</button>
      {:else if profilePage.loaded && profiles.length === 0}
        <p class="rounded-xl border border-line p-8 text-muted">No candidate profiles have been recorded in this catalog.</p>
      {:else}
        <ul class="grid gap-4 sm:grid-cols-2">
          {#each profiles as profile (profile.id)}
            <li class="rounded-xl border border-line bg-white p-6">
              <p class="mb-3 text-xs font-semibold uppercase tracking-widest text-accent">Candidate · {profile.classes.join(' · ')}</p>
              <h3 class="mb-3 text-xl font-semibold">{profile.label}</h3>
              <p class="mb-4 text-sm text-muted">{profile.kind} · Revision {profile.profile_revision}</p>
              <a class="font-semibold" href={`/api/profiles/${profile.identity.slice(7)}`} download>Download exact profile</a>
            </li>
          {/each}
        </ul>
        {#if profilePage.error}
          <p class="mt-5" role="status">More profiles are temporarily unavailable.</p>
        {/if}
        {#if profilePage.more || profilePage.error}
          <button class="mt-5 rounded-lg border border-line bg-white px-5 py-3 font-medium" onclick={loadProfiles} disabled={profilePage.loading}>
            {profilePage.loading ? 'Loading…' : profilePage.error ? 'Try again' : 'Load more profiles'}
          </button>
        {/if}
      {/if}
    </div>
  </section>

  <section aria-labelledby="sources-heading">
    <h2 id="sources-heading" class="mb-2 text-2xl font-medium">Source documents</h2>
    <p class="mb-8 text-muted">A document records a source. It does not establish that a complete assembly has been tested.</p>
    <div aria-live="polite">
      {#if !sourcePage.loaded && !sourcePage.error}
        <p class="py-8 text-muted">Loading source records…</p>
      {:else if !sourcePage.loaded && sourcePage.error}
        <p class="mb-4">Source records are temporarily unavailable.</p>
        <button class="rounded-lg bg-ink px-5 py-3 font-medium text-white" onclick={loadSources}>Try again</button>
      {:else if sourcePage.loaded && sources.length === 0}
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
        {#if sourcePage.error}
          <p class="mt-5" role="status">More source records are temporarily unavailable.</p>
        {/if}
        {#if sourcePage.more || sourcePage.error}
          <button class="mt-5 rounded-lg border border-line bg-white px-5 py-3 font-medium" onclick={loadSources} disabled={sourcePage.loading}>
            {sourcePage.loading ? 'Loading…' : sourcePage.error ? 'Try again' : 'Load more sources'}
          </button>
        {/if}
      {/if}
    </div>
  </section>
</main>
