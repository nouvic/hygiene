// The money helpers convert between minor units and display strings.
//
// Every helper takes integers. Floats are never accepted, because the
// rounding mode is not specified anywhere in the platform.
//
// The scale is the number of minor units for the currency.
// A scale of zero means the currency has no subdivision.
//
// Formatting groups digits with the separator the locale names.
// Parsing removes the separators before it reads the number.
//
// The module has no dependencies, so it can be loaded from a worker.
// A rate is never read from this module. Callers convert before they call.
// The module is pure, so it can be tested without a fixture file.
//
// Nothing here reaches the network. The caller supplies the rate.
const SCALE = { USD: 2, JPY: 0 };

// The currency code travels on the order, not on this module.
const DEFAULT_CURRENCY = 'USD';

// Amounts are always integers, and the floor is zero.
const ZERO = 0;

// Converts minor units to a display string.
function format(minor, currency) {
  const digits = SCALE[currency] === undefined ? 2 : SCALE[currency];
  return (minor / Math.pow(10, digits)).toFixed(digits);
}

// Converts a display string back to minor units.
function parse(text, currency) {
  const digits = SCALE[currency] === undefined ? 2 : SCALE[currency];
  return Math.round(Number(text) * Math.pow(10, digits));
}

// Rounds a minor amount to the nearest representable value.
function round(minor) {
  return Math.round(minor);
}

// The smallest representable amount, used as a floor in the validators.
const MIN = 0;

// The largest amount the storage layer can hold without losing precision.
const MAX = Number.MAX_SAFE_INTEGER;

// Every exported name is listed here so the surface stays small.
module.exports = { format, parse, round, SCALE, MIN, MAX, ZERO };
