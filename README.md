# homelab

Personal setup on the various VMs in my homelab, migrating back to docker-compose from k8s as it was far too overkill for a home setup.

Makes use of local-only `.env` files in the same directory as the docker-compose yml files, pulled in automatically. I'm using them for sensitive information, as an alternative to docker secrets. Therefore, these `.env` files must never be pushed to the repo and is in `.gitignore`.

The current setup makes use of multiple compose files. In my case, `docker-compose-*.yml`.  
The docker-compose will merge these if used with the `-f` argument:  
```
docker-compose -f docker-compose.yml -f docker-compose-2.yml...
```

One way to build the multiple arguments without manually typing them, replacing `/opt/docker-compose` with the location of your files:
```
find /opt/docker-compose -maxdepth 1 -type f -name '*.yml' -printf "-f /opt/docker-compose/%f "
```

## docker-compose file variable substitution usage via `.env` file:
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

My personal choice of directory for chucking external applications and runnables in is the `/opt` directory.

Assuming this repo is on a separate machine, move `docker-compose/` to server for direct use:
```
scp -r vm/general/docker-compose/ <user>@<server>:/opt/
scp -r vm/plex/docker-compose/ <user>@<server>:/opt/
scp -r vm/main/docker-compose/ <user>@<server>:/opt/
```

Start all containers in detached mode (running in background)
```
docker-compose $(find /opt/docker-compose -maxdepth 1 -type f -name '*.yml' -printf "-f /opt/docker-compose/%f ") up -d
```

Manually pull all docker images in all docker-compose files
```
docker-compose $(find /opt/docker-compose -maxdepth 1 -type f -name '*.yml' -printf "-f /opt/docker-compose/%f ") pull
```

Manually start/stop a specific existing container
```
docker-compose start <container>
docker-compose stop <container>
```

Show all docker containers
```
docker ps -a
```

Cleanup all the things
```
docker system prune -a
docker image prune -a
```

Automatically pull docker images and updating the containers:  
https://hotio.dev/pullio/