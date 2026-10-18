# Security reports and publication

Do not put credentials, pairing codes, watch keys, personal addresses, entity
IDs, HA configuration exports, or unredacted logs in public issues or pull
requests. Use synthetic examples when reporting a problem.

For a vulnerability, use GitHub's **Security → Report a vulnerability** on this
repository when available. If private reporting is unavailable, open an issue
asking for a private reporting channel without including exploit details or
private data. Never post a live credential to demonstrate a problem.

## Publishing safely

The watch app and `ha-integration` are independent Git repositories. Publish
each repository through Git, rather than uploading this workspace as a ZIP.
Ignored local folders can contain real home configuration, backups, credentials
and diagnostic output. Ignore rules do not remove files already committed.

Before publishing, inspect staged files, all branches and tags, commit metadata,
and any releases or attached artifacts. Scan history as well as the current
tree. Revoke any exposed credential first; deleting it from a later commit does
not remove it from history or existing copies. Review new changes again before
publishing them.

Repository owner names, commit metadata and activity are visible in a public
repository. A source review does not cover GitHub account settings, collaborators,
Actions secrets, release downloads, issues or other remotely stored content.
