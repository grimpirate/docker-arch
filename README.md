# docker-arch
Docker Archlinux image based on webtop

~
```
docker run -d --name=webtop -e PUID=1000 -e PGID=1000 -e TZ=America/New_York -p 3000:3000 -p 3001:3001 --shm-size="1gb" --device /dev/fuse --cap-add SYS_ADMIN arch
```
