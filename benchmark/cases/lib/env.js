// Reads an environment variable and falls back to the default.
function read(name, fallback) { return process.env[name] || fallback; }
module.exports = { read };
