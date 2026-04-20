import Link from "next/link";

export function CTA() {
  return (
    <section className="border-t border-[color:var(--color-border)] px-6 py-24">
      <div className="mx-auto flex max-w-4xl flex-col items-start gap-6">
        <h2 className="font-display text-4xl md:text-6xl">
          [Commitment statement]
        </h2>
        <p className="text-lg text-[color:var(--color-text-muted)]">
          [One sentence framing the outcome of the next click.]
        </p>
        <Link
          href="/start"
          className="inline-flex h-12 items-center rounded-md bg-[color:var(--color-brand-primary)] px-6 font-medium text-[color:var(--color-bg)] hover:opacity-90"
        >
          [Verb + outcome]
        </Link>
      </div>
    </section>
  );
}
