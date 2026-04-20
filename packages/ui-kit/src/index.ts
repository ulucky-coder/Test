export const REGISTRY = [
  "button",
  "card",
  "dialog",
  "dropdown-menu",
  "form",
  "input",
  "label",
  "navigation-menu",
  "popover",
  "scroll-area",
  "separator",
  "skeleton",
  "switch",
  "tabs",
  "toast",
  "tooltip",
] as const;

export type RegistryComponent = (typeof REGISTRY)[number];
