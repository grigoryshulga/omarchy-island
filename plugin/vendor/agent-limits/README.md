# Agent Limits collector

Source: https://github.com/grigoryshulga/omarchy-agent-limits

Revision: `06aea198476a0ff4fadb656ed5ac2b0439852a5a` (MIT).

The collector is `../../bin/agent-limits-sync`; its defaults path points here.
Island adds aggregate `unpricedTokens` fields for partially priced traffic and
enforces private cache directory/file permissions.
`Model.js` contains the original pure-JS usage helpers. The native Island UI
is maintained separately. Connections, state, locks, and runtime caches remain
compatible with the standalone plugin. Run the collector and QML tests through
`bin/test` from the Island repository root.
