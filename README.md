## 1ma fork of Trilema archive

### Branches

* `main`: original archive from 2021 made by [@BullishNode](https://github.com/BullishNode)
* `master`: extra commits to clean up duplicate content and serve the site nicely with Caddy and Cloudflare Pages

### Cloudflare Mirror

Available at: [trilema-mirror.pages.dev](https://trilema-mirror.pages.dev)

> [!WARNING]
> Use the Tor Browser or host your own private copy of the site for better privacy.

The Cloudflare project is configured with `xargs -r rm -rf < _ignores; rm -f _ignores` as the build command.
`wp-content/uploads/2012/04/248493.mp4` had to be excluded from the mirror because Cloudflare's free tier
rejects files larger than 25 MB.

### Run Locally

#### Docker

```shell
docker compose up -d
```

Browse it at http://localhost

#### Host a private copy

Install Caddy on your server and use the Caddyfile provided with this repo,
adjusting as needed.

Original README.md follows:

---

# trilema
Archive of Trilema.com

In Memoriam Mircea Popescu, the original Toxic Bitcoin Maximalist.

## Contributing

This snapshot of Trilema.com was made on June 27 2021. Shortly after the backup was made, the Trilema.com website became unresponsive. We do not know if the backup of the website was completed sucessfully in its entirety. If you are aware of or possess missing content, please submit a PR.
