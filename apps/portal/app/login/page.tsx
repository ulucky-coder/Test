"use client";
import { useState } from "react";
import { supabase } from "@/lib/supabase";

export default function Login() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: `${window.location.origin}/client` },
    });
    if (error) setError(error.message);
    else setSent(true);
  }

  return (
    <main style={{ padding: "4rem 1.5rem", maxWidth: 480, margin: "0 auto" }}>
      <h1 style={{ fontSize: "1.75rem", fontWeight: 600 }}>Sign in</h1>
      {sent ? (
        <p style={{ marginTop: "1rem" }}>
          Check your email for the magic link.
        </p>
      ) : (
        <form
          onSubmit={onSubmit}
          style={{ display: "grid", gap: "0.75rem", marginTop: "1rem" }}
        >
          <label htmlFor="email">Email</label>
          <input
            id="email"
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            style={{ padding: "0.6rem", fontSize: "1rem" }}
          />
          <button type="submit" style={{ padding: "0.6rem", fontSize: "1rem" }}>
            Send magic link
          </button>
          {error && <p style={{ color: "crimson" }}>{error}</p>}
        </form>
      )}
    </main>
  );
}
