export function Footer() {
  return (
    <footer className="border-t border-[color:var(--color-border)] px-6 py-12 text-sm">
      <div className="mx-auto grid max-w-6xl gap-8 md:grid-cols-4">
        <div>
          <p className="font-display text-lg">[Brand]</p>
          <p className="mt-2 text-[color:var(--color-text-muted)]">
            [Short pitch]
          </p>
        </div>
        <FooterColumn
          title="Product"
          items={["Features", "Pricing", "Changelog"]}
        />
        <FooterColumn title="Company" items={["About", "Blog", "Careers"]} />
        <FooterColumn title="Legal" items={["Terms", "Privacy", "Security"]} />
      </div>
      <p className="mx-auto mt-12 max-w-6xl text-[color:var(--color-text-muted)]">
        © {new Date().getFullYear()} [Brand]. All rights reserved.
      </p>
    </footer>
  );
}

function FooterColumn({ title, items }: { title: string; items: string[] }) {
  return (
    <div>
      <p className="mb-3 font-mono text-xs uppercase tracking-widest">
        {title}
      </p>
      <ul className="space-y-2">
        {items.map((i) => (
          <li key={i}>
            <a href="#" className="hover:underline">
              {i}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
