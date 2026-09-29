# Troubleshooting

## The service does not start

Check that the port is free. Check that the config file parses.

## Requests are slow

Look at the database first. A missing index shows up as a flat latency curve
under load.
