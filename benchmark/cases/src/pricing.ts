// The pricing module keeps every rule in one place.
//
// Every rule is a pure function of the order and the account.
// The order of the rules matters, because a later rule overrides an
// earlier one, and the list is walked from the front.
//
// Rounding happens once, at the end, on the final amount.
// Intermediate values keep full precision so that rounding is never
// applied twice in the same pass.
//
// Currencies without minor units still go through the same path, with a
// scale of zero, so the callers do not need a special case.
//
// Discounts are applied before tax, and tax is computed on the
// discounted amount.
//
// The module does not talk to the network. The caller supplies the
// account and the order, and receives a new order back.
export type Order = { total: number; currency: string };

// A rule returns a new order rather than mutating the one it was given.
export type Rule = (order: Order) => Order;

// The default rule set is empty, so a caller opts in to each rule.
export const RULES: Rule[] = [];

// Applying a rule is cheap, so the whole list is walked on every call.
export function apply(order: Order): Order {
  let result = order;
  for (const rule of RULES) {
    result = rule(result);
  }
  return result;
}

// A rule that does nothing is valid, and is used for the disabled cases.
export const identity: Rule = (order) => order;

// The scale is the number of minor units, two for most currencies.
export const SCALE: Record<string, number> = { USD: 2, JPY: 0 };

// The currency code travels on the order, not on the rule.
export const DEFAULT_CURRENCY = 'USD';

// Amounts are always integers, and the floor is zero.
export const ZERO = 0;

// The largest amount the storage layer can hold without losing precision.
export const MAX = Number.MAX_SAFE_INTEGER;

// Every exported name is listed here so the surface stays small.
export const SURFACE = ['apply', 'identity', 'SCALE', 'ZERO', 'MAX'];
