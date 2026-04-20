export function SocialProof() {
  return (
    <section
      aria-label="Social proof"
      className="border-t border-[color:var(--color-border)] px-6 py-12"
    >
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-8">
        <p className="font-mono text-xs uppercase tracking-widest text-[color:var(--color-text-muted)]">
          Trusted by teams building the next internet
        </p>
        <ul
          role="list"
          className="grid w-full grid-cols-2 items-center gap-8 opacity-70 md:grid-cols-6"
        >
          {["Acme", "Helix", "Maple", "Nimbus", "Orbit", "Pylon"].map(
            (name) => (
              <li
                key={name}
                className="font-display text-lg text-center tracking-tight"
              >
                {name}
              </li>
            ),
          )}
        </ul>
      </div>
    </section>
  );
}
