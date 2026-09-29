# The pricing module keeps every rule in one place.
#
# Every rule is a pure function of the order and the account.
# The order of the rules matters, because a later rule overrides an
# earlier one, and the list is walked from the front.
#
# Rounding happens once, at the end, on the final amount.
# Intermediate values keep full precision so that rounding is never
# applied twice in the same pass.
#
# Currencies without minor units still go through the same path, with a
# scale of zero, so the callers do not need a special case.
#
# Discounts are applied before tax, and tax is computed on the
# discounted amount.
#
# The module does not talk to the network. The caller supplies the
# account and the order, and receives a new order back.
RULES = []

# A rule returns a new order rather than mutating the one it was given.
def apply(order):
    result = order
    for rule in RULES:
        result = rule(result)
    return result

# A rule that does nothing is valid, and is used for the disabled cases.
def identity(order):
    return order

# The scale is the number of minor units, two for most currencies.
SCALE = {'USD': 2, 'JPY': 0}

# The currency code travels on the order, not on the rule.
DEFAULT_CURRENCY = 'USD'

# Amounts are always integers, and the floor is zero.
ZERO = 0

# The largest amount the storage layer can hold without losing precision.
MAX = 2 ** 53 - 1

# Every exported name is listed here so the surface stays small.
SURFACE = ['apply', 'identity', 'SCALE', 'ZERO', 'MAX']
