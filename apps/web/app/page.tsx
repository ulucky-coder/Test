import { Hero } from "@brand/Hero";
import { Features } from "@brand/Features";
import { SocialProof } from "@brand/SocialProof";
import { CTA } from "@brand/CTA";
import { Footer } from "@brand/Footer";

export default function HomePage() {
  return (
    <>
      <Hero />
      <SocialProof />
      <Features />
      <CTA />
      <Footer />
    </>
  );
}
