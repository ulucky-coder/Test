import Link from "next/link";

export function Hero() {
  return (
    <section className="relative isolate overflow-hidden px-6 pt-24 pb-16 md:pt-32 md:pb-24">
      <div className="mx-auto max-w-5xl">
        <p className="mb-6 font-mono text-sm tracking-wide text-[color:var(--color-text-muted)]">
          [brand.tagline]
        </p>
        <h1
          className="font-display text-5xl leading-[1.02] tracking-tight md:text-7xl"
          style={{ fontVariationSettings: '"wght" 600, "opsz" 28' }}
        >
          [Brand headline]
        </h1>
        <p className="mt-6 max-w-2xl text-lg text-[color:var(--color-text-muted)]">
          [Subhead answering what the product does, not who it&apos;s for.]
        </p>
        <div className="mt-10 flex items-center gap-4">
          <Link
            href="/start"
            className="inline-flex h-12 items-center rounded-md bg-[color:var(--color-brand-primary)] px-6 font-medium text-[color:var(--color-bg)] transition-opacity duration-[var(--duration-fast)] hover:opacity-90"
          >
            [Primary CTA]
          </Link>
          <Link
            href="/features"
            className="font-medium underline-offset-4 hover:underline"
          >
            [Secondary CTA]
          </Link>
        </div>
      </div>
    </section>
  );
}
