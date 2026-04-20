export const VIEWBOX_MARK = "0 0 1000 1000";
export const VIEWBOX_WORDMARK = "0 0 1000 250";
export const GRID_UNIT = 25;
export const PHI = 1.6180339887;

export function snap(value: number, unit = 0.5): number {
  return Math.round(value / unit) * unit;
}

export function goldenSteps(total = 1000): number[] {
  return [total, total / PHI, total / PHI / PHI, total / (PHI * PHI * PHI)].map(
    (v) => snap(v),
  );
}

export function polygonOnCircle(
  sides: number,
  radius: number,
  cx = 500,
  cy = 500,
  rotation = -Math.PI / 2,
): string {
  const points: string[] = [];
  for (let i = 0; i < sides; i += 1) {
    const t = rotation + (i * 2 * Math.PI) / sides;
    points.push(
      `${snap(cx + radius * Math.cos(t))},${snap(cy + radius * Math.sin(t))}`,
    );
  }
  return points.join(" ");
}
