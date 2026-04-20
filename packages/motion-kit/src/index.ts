export const EASING = {
  standard: [0.2, 0, 0, 1] as const,
  emphasized: [0.3, 0, 0, 1] as const,
  decelerate: [0, 0, 0, 1] as const,
  accelerate: [0.3, 0, 1, 1] as const,
};

export const DURATION = {
  instant: 0.08,
  fast: 0.16,
  base: 0.24,
  slow: 0.4,
  slower: 0.64,
} as const;

export function prefersReducedMotion(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/** Returns variant object; consumer picks `enter` or `reducedMotion`. */
export function fadeInUp(delay = 0) {
  return {
    enter: {
      initial: { opacity: 0, y: 24 },
      animate: { opacity: 1, y: 0 },
      transition: { duration: DURATION.base, ease: EASING.standard, delay },
    },
    reducedMotion: {
      initial: { opacity: 1, y: 0 },
      animate: { opacity: 1, y: 0 },
      transition: { duration: 0 },
    },
  };
}
