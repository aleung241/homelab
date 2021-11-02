# homelab-vm-general

Personal setup on the General VM, migrating back to docker-compose from k8s as it was far too overkill for a home setup.

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