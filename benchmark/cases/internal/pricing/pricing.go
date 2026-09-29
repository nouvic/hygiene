// The ledger module records every movement as a pair of entries.
//
// An entry is immutable once written. Corrections are written as new
// entries rather than as edits to the old ones.
//
// The running balance is derived, so it is never stored twice.
// A caller that needs the balance folds the entries from the beginning.
//
// Amounts are integer minor units. A currency with no minor unit uses a
// scale of zero and the same code path.
//
// The module holds no locks. Callers that write concurrently serialize
// their own writes in the layer above.
//
// Nothing here talks to a database. A store is passed in.
package pricing

// Entry is one movement of value in one direction.
type Entry struct {
	Account string
	Minor   int64
}

// Ledger is the ordered list of entries for one account.
type Ledger struct {
	Account string
	Entries []Entry
}

// Balance folds the entries and returns the running total in minor units.
func (l Ledger) Balance() int64 {
	var total int64
	for _, e := range l.Entries {
		total += e.Minor
	}
	return total
}

// Append returns a new ledger rather than mutating the receiver.
func (l Ledger) Append(e Entry) Ledger {
	next := make([]Entry, 0, len(l.Entries)+1)
	next = append(next, l.Entries...)
	next = append(next, e)
	return Ledger{Account: l.Account, Entries: next}
}

// Empty is the ledger a caller starts from.
var Empty = Ledger{}
