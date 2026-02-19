# homelab

## Structure

```
vm/
  main/           # Main server - runs most services
    docker/       # Compose files, common.yaml, .env
    scripts/      # Backup, todrive, start-all-docker
  plex-new/       # Plex server - media playback and transcoding
    docker/       # Compose files, common.yaml, .env
    scripts/      # Backup, start-all-docker
```

## Docker compose

The setup uses multiple compose files per VM (`docker-compose-*.yml`), merged with the `-f` argument:

```bash
docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') up -d
```

A shared `common.yaml` defines base service templates, referenced via `extends`:

```yaml
extends:
  file: common.yaml
  service: common   # or hotio for hotio images. hotio service template also extends base.
```

This provides restart policy, logging config, and pullio labels to all services without repetition. The `common.yaml` file uses a `.yaml` extension so it isn't picked up by the `find *.yml` glob.

## Environment variables

Sensitive values are stored in local-only `.env` files in the same directory as the compose files.  
These are pulled in automatically by docker compose for variable substitution and must never be pushed to the repo (included in `.gitignore`).

```yaml
# .env
SECRET_KEY=secret_value

# docker-compose-*.yml
environment:
  SOME_SECRET: ${SECRET_KEY}
```

Some services use dedicated env files (e.g. `.paperless.env`, firefly-iii's `.env`/`.db.env`/`.importer.env`) via `env_file:` attribute for isolation.

## Deployment

Copy docker and script directories to the respective servers.  
My personal choice of directory for chucking external applications, runnables and docker stuff is in the `/opt` directory.

```bash
scp -r vm/main/docker/ <user>@<main-server>:/opt/
scp -r vm/main/scripts/ <user>@<main-server>:/opt/

scp -r vm/plex-new/docker/ <user>@<plex-server>:/opt/
scp -r vm/plex-new/scripts/ <user>@<plex-server>:/opt/
```

## Common commands

For the purpose of simplicity, I use aliases for the `docker compose` command with multiple files:
```bash
# ~/.bashrc
alias dcom="docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ')"
```
Then reload .bashrc:
```bash
source ~/.bashrc
```
This can replace all `docker compose $(find ...)` commands below like this:
```bash
dcom pull
dcom up -d
dcom start <container>
```
---
Start all containers in detached mode:
```bash
docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') up -d
```

Pull all images:
```bash
docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') pull
```

Start/stop a specific container:
```bash
docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') start <container>
docker compose $(find /opt/docker -maxdepth 1 -type f -name '*.yml' -printf '-f /opt/docker/%f ') stop <container>
```

Cleanup unused images and containers:
```bash
docker system prune -a
```

## Auto-updates

Docker images are automatically pulled and containers updated via [pullio](https://hotio.dev/pullio/).  
`pullio` is activated on docker services by labels:
```yaml
labels:
  - "org.hotio.pullio.notify=true"
  - "org.hotio.pullio.update=true"
  - "org.hotio.pullio.discord.webhook=${PULLIO_DISCORD_WEBHOOK}"
```
These labels are conveniently placed in the common service template in `common.yaml`, which are used in almost all docker services in this repo.

Usage:
```bash
pullio --parallel 12
```
