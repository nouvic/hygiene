// The ledger records every movement as a pair of entries.
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
// The class holds no locks. Callers that write concurrently serialize
// their own writes in the layer above.
//
// Nothing here talks to a database. A store is passed in.
package app;

// One movement of value in one direction.
public final class Entry {
    public final String account;
    public final long minor;

    public Entry(String account, long minor) {
        this.account = account;
        this.minor = minor;
    }
}

// The ordered list of entries for one account.
final class Book {
    private final java.util.List<Entry> entries;

    Book(java.util.List<Entry> entries) {
        this.entries = entries;
    }

    // Folds the entries and returns the running total in minor units.
    long balance() {
        long total = 0L;
        for (Entry e : entries) {
            total += e.minor;
        }
        return total;
    }

    // Returns a new book rather than mutating the receiver.
    Book append(Entry e) {
        java.util.List<Entry> next = new java.util.ArrayList<>(entries);
        next.add(e);
        return new Book(next);
    }
}

// The book a caller starts from.
final class Empty {
    static Book book() {
        return new Book(new java.util.ArrayList<Entry>());
    }
}
