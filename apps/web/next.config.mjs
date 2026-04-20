/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: { ppr: "incremental", reactCompiler: true },
  images: { formats: ["image/avif", "image/webp"] },
  poweredByHeader: false,
  reactStrictMode: true,
  transpilePackages: [
    "@atelier/tokens",
    "@atelier/motion-kit",
    "@atelier/svg-kit",
    "@atelier/ui-kit",
  ],
};

export default nextConfig;
