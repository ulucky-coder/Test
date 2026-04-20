const items = [
  {
    title: "[Feature 1]",
    body: "[Benefit statement, one sentence, outcome-framed.]",
  },
  {
    title: "[Feature 2]",
    body: "[Benefit statement, one sentence, outcome-framed.]",
  },
  {
    title: "[Feature 3]",
    body: "[Benefit statement, one sentence, outcome-framed.]",
  },
  {
    title: "[Feature 4]",
    body: "[Benefit statement, one sentence, outcome-framed.]",
  },
  {
    title: "[Feature 5]",
    body: "[Benefit statement, one sentence, outcome-framed.]",
  },
  {
    title: "[Feature 6]",
    body: "[Benefit statement, one sentence, outcome-framed.]",
  },
];

export function Features() {
  return (
    <section className="border-t border-[color:var(--color-border)] px-6 py-20">
      <div className="mx-auto max-w-6xl">
        <h2 className="mb-12 font-display text-3xl md:text-5xl">
          [Section header]
        </h2>
        <div className="grid gap-6 md:grid-cols-3">
          {items.map((item) => (
            <article
              key={item.title}
              className="rounded-lg border border-[color:var(--color-border)] p-6 transition-colors duration-[var(--duration-fast)] hover:border-[color:var(--color-brand-primary)]"
            >
              <h3 className="mb-3 font-display text-xl">{item.title}</h3>
              <p className="text-[color:var(--color-text-muted)]">
                {item.body}
              </p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
