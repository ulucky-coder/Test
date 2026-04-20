/** Circle next to square of same nominal height → ~2% baseline overshoot. */
export function circleOvershoot(nominalHeight: number): number {
  return nominalHeight * 1.02;
}

/** Triangle centroid up ~3%. */
export function triangleShiftY(nominalHeight: number): number {
  return nominalHeight * -0.03;
}

/** "O" wider than "H" by 2-4%. */
export function letterOWidth(nominalWidth: number): number {
  return nominalWidth * 1.03;
}

/** Diagonal stroke 85-90% of vertical. */
export function diagonalStroke(verticalStroke: number): number {
  return verticalStroke * 0.88;
}
