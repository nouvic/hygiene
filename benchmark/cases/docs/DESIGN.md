# Design

The queue is a single ordered list.

An earlier draft used two lists, one for work that had failed once and one for
work that had failed twice. That alternative was rejected because the second
list added a state that operators had to reason about without removing any.

The single list keeps the ordering rule in one place.
