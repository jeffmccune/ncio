Version 2.0.1
===

 * Fix ncio with PE > 2017.2  Previous versions hang with requests with
   Transfer-Encoding: chunked.  Thanks to Dylan Ratcliffe and Geoff Williams for
   the fix.

Version 2.0.0
===

 * Make fqdn certificate the default if it exists, fall back to
   pe-internal-orchestrator if not.  This makes ncio more robust when the SSL
   directory is copied from a PE install which had the orchestrator enabled and
   the new PE install does not have the orchestrator enabled.  In such a
   situation only the FQDN certificate is listed in the whitelist.

Version 1.2.0
===

 * PE 2016.4.2 Compatibility thanks to Geoff Williams [Issue
   8](https://github.com/jeffmccune/ncio/issues/8)

Version 1.1.0
===

 * Add `--retry-connections` [Issue 6](https://github.com/jeffmccune/ncio/issues/6)
 * Add better error handling [Issue 7](https://github.com/jeffmccune/ncio/issues/7)

Version 1.0.1
===

 * Initial release.  Backup / Transform / Restore
