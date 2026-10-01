const cfg = {
  port: +process.env.PORT || 3000,
  authMode: process.env.AUTH_MODE || 'dev',
  mongoUri: process.env.MONGO_URI || '',
  graceMs: +process.env.RECONNECT_GRACE_MS || 60000,
  nodeEnv: process.env.NODE_ENV || 'development',
};
// Dev auth lets anyone claim any identity. Only allow in production for temporary test deployments.
if (cfg.nodeEnv === 'production' && cfg.authMode === 'dev' && process.env.ALLOW_DEV_AUTH !== 'true') {
  throw new Error('AUTH_MODE=dev is not allowed in production (set ALLOW_DEV_AUTH=true for temporary test deploys only)');
}
module.exports = cfg;
