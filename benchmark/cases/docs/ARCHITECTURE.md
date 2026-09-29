# Architecture

The application is a set of modules with one direction of dependency. A module
may import the modules below it and never the ones above.

## Layers

The transport layer parses requests and hands them to the domain layer. The
domain layer holds the rules and knows nothing about transport. The storage
layer owns the database and is reached only through its interface.

## Boundaries

Each module exposes a small surface. Adding a name to that surface is a change
that other teams can see, so it is worth a second reader.
