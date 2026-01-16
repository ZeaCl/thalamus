/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  // Ensure server actions are enabled (default in Next.js 14)
  experimental: {
    serverActions: true,
  },
}

module.exports = nextConfig
