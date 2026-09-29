// Cache keys include the locale, so a locale change invalidates the entry.
module.exports = function key(locale, id) { return locale + ':' + id; };
