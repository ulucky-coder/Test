export interface LintViolation {
  rule: string;
  message: string;
}

export function lintSvg(
  content: string,
  opts: { allowText?: boolean } = {},
): LintViolation[] {
  const violations: LintViolation[] = [];
  if (/<script[\s>]/i.test(content))
    violations.push({ rule: "no-script", message: "<script> not allowed" });
  if (/<foreignObject[\s>]/i.test(content))
    violations.push({
      rule: "no-foreign-object",
      message: "<foreignObject> not allowed",
    });
  if (/\son\w+\s*=/i.test(content))
    violations.push({
      rule: "no-event-handlers",
      message: "on* handlers not allowed",
    });
  if (/xlink:href\s*=\s*["']https?:/i.test(content))
    violations.push({
      rule: "no-external-xlink",
      message: "external xlink:href not allowed",
    });
  if (!opts.allowText && /<text[\s>]/i.test(content))
    violations.push({
      rule: "no-text",
      message: "<text> must be outlined to paths",
    });
  if (!/<title[>\s]/i.test(content))
    violations.push({
      rule: "missing-title",
      message: "<title> required for accessibility",
    });
  return violations;
}
