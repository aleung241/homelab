# homelab-vm-general

Personal setup on the General VM, migrating back to docker-compose from k8s as it was far too overkill for a home setup.

Local-only `.env` file pulled in by `docker-compose.yml` automatically in the same root, used for sensitive information, as an alternative to docker secrets. This file must never be pushed to the repo and is in `.gitignore`.

Usage:
```
> cat .env
SECRET_KEY=secret_value

> cat docker-compose.yml
...
environment:
  SOME_SECRET: ${SECRET_KEY}
...
```

---

Move `docker-compose/` to server for direct use:
```
scp -r docker-compose/ <user>@<server>:/opt/
```

Start all containers in detached mode
```
cd /opt/docker-compose
docker-compose up -d
```

Manually pull all containers to local
```
docker-compose pull
```

Manually start/stop one existing container
```
docker-compose start <container>
docker-compose stop <container>
```

Show all docker containers
```
docker ps -a
```

Cleanup
```
docker system prune
```