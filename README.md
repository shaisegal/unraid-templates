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

The application has not yet been submitted to Community Applications. Until it
is accepted, install the public template from an Unraid terminal:

```sh
curl -fsSL \
  https://raw.githubusercontent.com/shaisegal/unraid-templates/main/unraid-journal.xml \
  -o /boot/config/plugins/dockerMan/templates-user/my-unraid-journal.xml
```

Then select **Unraid-Journal** under **Docker > Add Container** and apply the
template. On first access, the web interface asks for the administrator
username and password. The session secret is generated automatically and the
authentication data is stored in `/data/.auth.yml`.

No password hash or session secret needs to be generated during installation.

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
