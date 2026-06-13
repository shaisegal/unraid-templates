# Unraid Journal

Community Applications template and public support repository for Unraid
Journal, a private self-hosted single-user journal.

The application stores journal entries and attachments in the mounted
filesystem. Its default Unraid configuration is:

- Web UI: `http://<unraid-host>:18080`
- Persistent data: `/mnt/user/appdata/unraid-journal`
- Container image: `ghcr.io/shaisegal/unraid-journal:latest`
- Container process: UID/GID `99:100` (`nobody:users` on Unraid)

## Installation

Once the application has been accepted into Community Applications, search for
`Unraid Journal` and select **Install**.

Before installation, generate the required values:

```bash
docker run --rm ghcr.io/shaisegal/unraid-journal:latest \
  hash-password 'your-password'

openssl rand -hex 32
```

Enter the first result as **Admin Password Hash** and the second as
**Session Secret**. Keep both values private.

## Nginx Proxy Manager

For `journal.home.arpa`, create a Proxy Host with:

- Scheme: `http`
- Forward Hostname/IP: `unraid.home.arpa`
- Forward Port: `18080`

Public certificate authorities do not issue certificates for `.home.arpa`.
Use HTTP on the trusted local network or configure an internal CA certificate.

## Support

Open an issue in this repository and include the Unraid version, container log
excerpt, and steps to reproduce. Remove journal content, credentials, secrets,
and other private data before posting.
