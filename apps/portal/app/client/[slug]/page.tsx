"use client";
import { use, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

interface Phase {
  id: string;
  kind: string;
  status: string;
  iteration: number;
  approved_at: string | null;
}

interface Client {
  id: string;
  slug: string;
  name: string;
}

export default function ClientDashboard({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = use(params);
  const [client, setClient] = useState<Client | null>(null);
  const [phases, setPhases] = useState<Phase[]>([]);

  useEffect(() => {
    let active = true;
    (async () => {
      const { data: c } = await supabase
        .from("clients")
        .select("id,slug,name")
        .eq("slug", slug)
        .single();
      if (!active || !c) return;
      setClient(c as Client);
      const { data: p } = await supabase
        .from("phases")
        .select("*")
        .eq("client_id", c.id)
        .order("kind");
      if (active && p) setPhases(p as Phase[]);
      const sub = supabase
        .channel(`phases-${c.id}`)
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "phases",
            filter: `client_id=eq.${c.id}`,
          },
          async () => {
            const { data } = await supabase
              .from("phases")
              .select("*")
              .eq("client_id", c.id)
              .order("kind");
            if (data) setPhases(data as Phase[]);
          },
        )
        .subscribe();
      return () => {
        sub.unsubscribe();
      };
    })();
    return () => {
      active = false;
    };
  }, [slug]);

  async function review(phase: Phase, verdict: "approve" | "revise") {
    const user = (await supabase.auth.getUser()).data.user;
    if (!user || !client) return;
    await supabase.from("reviews").insert({
      client_id: client.id,
      phase_id: phase.id,
      reviewer: user.id,
      reviewer_role: "client",
      verdict,
    });
    if (verdict === "approve") {
      await supabase.rpc("advance_phase", {
        p_client_id: client.id,
        p_kind: phase.kind,
        p_reviewer: user.id,
      });
    } else {
      await supabase
        .from("phases")
        .update({ status: "revise" })
        .eq("id", phase.id);
    }
  }

  if (!client) return <main style={{ padding: "2rem" }}>Loading…</main>;

  return (
    <main style={{ padding: "2rem", maxWidth: 960, margin: "0 auto" }}>
      <h1 style={{ fontSize: "2rem", fontWeight: 600 }}>{client.name}</h1>
      <p style={{ opacity: 0.6, fontFamily: "monospace" }}>{client.slug}</p>
      <ul
        style={{
          marginTop: "2rem",
          display: "grid",
          gap: "0.5rem",
          padding: 0,
          listStyle: "none",
        }}
      >
        {phases.map((p) => (
          <li
            key={p.id}
            style={{
              display: "grid",
              gridTemplateColumns: "1fr auto auto auto",
              gap: "1rem",
              alignItems: "center",
              padding: "0.75rem",
              border: "1px solid #e5e5e5",
              borderRadius: 6,
            }}
          >
            <span>
              <strong>{p.kind}</strong>
              <span style={{ marginLeft: "0.5rem", opacity: 0.6 }}>
                iter {p.iteration}
              </span>
            </span>
            <code>{p.status}</code>
            <button
              disabled={p.status !== "ready_for_review"}
              onClick={() => review(p, "approve")}
            >
              Approve
            </button>
            <button
              disabled={p.status !== "ready_for_review"}
              onClick={() => review(p, "revise")}
            >
              Revise
            </button>
          </li>
        ))}
      </ul>
    </main>
  );
}
