# Windows Services: Caveats & Best Practices

Due to the unique nature of certain Windows features (e.g. networking, security, file system) there are several items of note regarding the deployment of a Docker service.  Below is a list of these issues including the current "best practices" used to work around them.

------

- **[Networking](https://success.docker.com/article/modernizing-traditional-dot-net-applications#networking) (see [compose file](#example-compose-file-for-a-service-running-on-windows-nodes) example below)**

  - For services that need to be reachable outside the swarm, Linux containers are able to use Docker swarm's [ingress routing mesh](https://docs.docker.com/engine/swarm/ingress/). However, Windows Server 2016 does not currently support the ingress routing mesh. Therefore Docker services scheduled for Windows Server 2016 nodes that need to be accessed outside of swarm need to be configured to bypass Docker's routing mesh. This is done by publishing ports using `host` mode which publishes the service's port directly on the node where it is running.

    Additionally, Docker's DNS Round Robin is the only load balancing strategy supported by Windows Server 2016 today; therefore, for every Docker service scheduled to these nodes, the `--endpoint-mode` parameter must also be specified with a value of `dnsrr`. 

  - When running Docker for Windows there is an issue related to container IP addresses.  The IP address shown when using the `docker inspect` command for a container is incorrect.  To browse a web site or api running in a container you must use the `docker exec` command and query the IP address from within the container (e.g. `ipconfig`).  Also, port assignments are ignored by Docker for Windows when running Windows containers (e.g. `docker run -p 8080:80`).  Run the [example app](https://github.com/ericcollazo/windows-services-caveats/tree/master/aspnet-core) to illustrate this issue.

- **Docker Objects**

  - [Configs](https://docs.docker.com/engine/swarm/configs/#windows-support) use the SYSTEM and ADMINISTRATOR permissions
    - When using a Docker Config object to replace the `web.config` file (ASP.Net apps), IIS will not be able to consume the file.  IIS requires (by default) `BUILTIN\IIS_IUSRS` credentials applied to files it will read/write to.
    - Due to the fact that Docker Config objects are attached after the container is created, assigning rights to the application folder during a `docker build` will not solve this problem.  Files added by the Config will retain their original credentials (`ADMINISTRATOR` & `SYSTEM`).
  - [Secrets](https://docs.docker.com/engine/swarm/secrets) stored on node temporarily
    - Microsoft Windows has no built-in driver for managing RAM disks, so within running Windows containers, secrets are persisted in clear text to the container's root disk. However, the secrets are explicitly removed when a container stops. In addition, Windows does not support persisting a running container as an image using `docker commit` or similar commands.
    - On Windows, we recommend enabling [BitLocker](https://technet.microsoft.com/en-us/library/cc732774(v=ws.11).aspx) on the volume containing the Docker root directory on the host machine to ensure that secrets for running containers are encrypted at rest.
    - Secret files with custom targets are not directly bind-mounted into Windows containers, since Windows does not support non-directory file bind-mounts. Instead, secrets for a container are all mounted in `C:\ProgramData\Docker\internal\secrets` (an implementation detail which should not be relied upon by applications) within the container. Symbolic links are used to point from there to the desired target of the secret within the container. The default target is `C:\ProgramData\Docker\secrets`.
    - When creating a service which uses Windows containers, the options to specify UID, GID, and mode are not supported for secrets. Secrets are currently only accessible by administrators and users with `system` access within the container.

- **AD authentication requires use of [gMSA](https://success.docker.com/article/modernizing-traditional-dot-net-applications#integratedwindowsauthentication)**

  - Windows node must be joined to the AD domain

- **Common base images for Windows applications**

  - ASP.Net applications: [microsoft/aspnet](https://hub.docker.com/r/microsoft/aspnet)
  - WCF Services: [microsoft/iis](https://hub.docker.com/r/microsoft/iis)

  - Windows Services: [microsoft/dotnet-framework](https://hub.docker.com/r/microsoft/dotnet-framework)

  - Console Applications: [microsoft/dotnet-framework](https://hub.docker.com/r/microsoft/dotnet-framework)

  - .Net build tools: [microsoft/dotnet-framework](https://hub.docker.com/r/microsoft/dotnet-framework)

    - Used for multi-stage builds (use the SDK variants)

  - ASP.Net Core applications: [microsoft/aspnetcore](https://hub.docker.com/r/microsoft/aspnetcore)

  - ASP.Net Core build tools: [microsoft/aspnetcore-build](https://hub.docker.com/r/microsoft/aspnetcore-build)

    - Used for multi-stage builds

  - Apps other than .Net: [microsoft/windowsservercore](https://hub.docker.com/r/microsoft/windowsservercore)

    - Additional Windows Features may be required depending on app requirements

------

### Example compose file for a service running on Windows nodes

```yaml
version: '3.3'

services:
  website:
    image: microsoft/iis	# serves a default site on port 80
    ports:
      - mode: host    # host mode networking
    deploy:        
      replicas: 1
      placement:
          constraints:
            - engine.labels.os == windows   # place service only on Windows nodes
      labels:
        com.docker.lb.hosts: app.example.org	# Replace with a real URL
        com.docker.lb.network: mystack_myoverlay # the network that the layer 7 mesh will hand-off to
        com.docker.lb.port: 80 # the port the service expects traffic on
      endpoint_mode: dnsrr    # dns round robin load balancing
    networks:
        - myoverlay   # custom overlay network the service will use

networks:
  myoverlay:  # the custom service definition
    driver: overlay
```