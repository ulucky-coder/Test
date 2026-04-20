import Link from "next/link";

export default function PortalHome() {
  return (
    <main style={{ padding: "4rem 1.5rem", maxWidth: 720, margin: "0 auto" }}>
      <h1
        style={{
          fontSize: "2.5rem",
          fontWeight: 600,
          letterSpacing: "-0.02em",
        }}
      >
        Atelier
      </h1>
      <p style={{ marginTop: "1rem", opacity: 0.7 }}>
        Review your brand kit, approve phases, and sign off on deliverables.
      </p>
      <nav style={{ marginTop: "2rem", display: "grid", gap: "0.5rem" }}>
        <Link href="/login">Sign in</Link>
        <Link href="/client">My project</Link>
      </nav>
    </main>
  );
}
