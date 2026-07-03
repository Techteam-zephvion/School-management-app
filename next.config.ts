import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Supabase email links use the 127.0.0.1 host in local dev; allow it to reach
  // dev resources (HMR) without the cross-origin warning.
  allowedDevOrigins: ["127.0.0.1"],
};

export default nextConfig;
