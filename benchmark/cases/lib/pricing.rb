# The ledger records every movement as a pair of entries.
#
# An entry is immutable once written. Corrections are written as new
# entries rather than as edits to the old ones.
#
# The running balance is derived, so it is never stored twice.
# A caller that needs the balance folds the entries from the beginning.
#
# Amounts are integer minor units. A currency with no minor unit uses a
# scale of zero and the same code path.
#
# The class holds no locks. Callers that write concurrently serialize
# their own writes in the layer above.
#
# Nothing here talks to a database. A store is passed in.
Entry = Struct.new(:account, :minor)

# The ordered list of entries for one account.
class Book
  attr_reader :entries

  def initialize(entries = [])
    @entries = entries
  end

  # Folds the entries and returns the running total in minor units.
  def balance
    total = 0
    @entries.each { |e| total += e.minor }
    total
  end

  # Returns a new book rather than mutating the receiver.
  def append(entry)
    Book.new(@entries + [entry])
  end
end

# The book a caller starts from.
def empty
  Book.new
end

# The scale is the number of minor units, two for most currencies.
SCALE = { 'USD' => 2, 'JPY' => 0 }.freeze

# Amounts are always integers.
ZERO = 0
