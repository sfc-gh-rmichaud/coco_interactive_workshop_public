/** @type {import('next').NextConfig} */
const nextConfig = {
  // snowflake-sdk is a Node library with native-ish deps; keep it out of the
  // bundler and let it load at runtime on the server only.
  serverExternalPackages: ["snowflake-sdk"],
};
export default nextConfig;
