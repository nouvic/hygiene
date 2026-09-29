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
/// One movement of value in one direction.
pub struct Entry {
    pub account: String,
    pub minor: i64,
}

/// The ordered list of entries for one account.
pub struct Ledger {
    pub account: String,
    pub entries: Vec<Entry>,
}

impl Ledger {
    /// Folds the entries and returns the running total in minor units.
    pub fn balance(&self) -> i64 {
        let mut total = 0i64;
        for e in &self.entries {
            total += e.minor;
        }
        total
    }

    /// Returns a new ledger rather than mutating the receiver.
    pub fn append(&self, e: Entry) -> Ledger {
        let mut next = self.entries.clone();
        next.push(e);
        Ledger {
            account: self.account.clone(),
            entries: next,
        }
    }
}

/// The ledger a caller starts from.
pub fn empty() -> Ledger {
    Ledger {
        account: String::new(),
        entries: Vec::new(),
    }
}
