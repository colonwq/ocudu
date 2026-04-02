# OCUDU Multi-Container Solution

This folder contains multiple docker compose configurations for different deployment scenarios:

## Available Docker Compose Files

| Compose File | Services | Purpose |
|--------------|----------|---------|
| `docker-compose.yml` | `5gc`, `gnb` | Complete gNB + Core deployment |
| `docker-compose.split.yml` | `cu-cp`, `cu-up`, `du` | CU/DU split architecture that replace the gNB |
| `docker-compose.ui.yml` | `telegraf`, `influxdb`, `grafana` | Monitoring and metrics visualization |

## Quick Start

### Running the default stack

To just launch the solution with gNB + core network:

```bash
docker compose -f docker/docker-compose.yml up
```

or

```bash
cd docker/
docker compose up
```

### Combining Multiple Compose Files to run custom deployments

You can use [docker compose override feature](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/) to combine the compose files to create custom deployments:

```bash
# Run gNB + core
docker compose -f docker/docker-compose.yml up

# Run cu-cp + cu-up + du + core (gNB is replaced)
docker compose -f docker/docker-compose.yml -f docker/docker-compose.split.yml up

# Run gNB + core with monitoring stack
docker compose -f docker/docker-compose.yml -f docker/docker-compose.ui.yml up

# Run split architecture with monitoring stack
docker compose -f docker/docker-compose.yml -f docker/docker-compose.split.yml -f docker/docker-compose.ui.yml up

# Run only the monitoring components (useful when connecting to external gNB
docker compose -f docker/docker-compose.ui.yml up
```

## Service Management

### Extra Start Options

- To force a new build of the containers (including a new build of OCUDU gNB), please add a `--build` flag at the end of the previous command.
- To run it in background, please add a `-d` flag at the end of the previous command.
- For more options, check `docker compose up --help`

### See logs

To see services' output, you can run:

```bash
docker compose logs [OPTIONS] [SERVICE...]
```

- For more options, check `docker compose logs --help`

### Tear down the deployment

To stop any deployment:

```bash
docker compose -f docker/docker-compose.yml -f docker/docker-compose.split.yml -f docker/docker-compose.ui.yml down --remove-orphans
```

- If you also want to remove all internal data except the setup, you can add `--volumes` flag at the end of the previous command.
- For more options, check `docker compose down --help`

If you're not familiarized with `docker compose` tool, it will be recommended to check its [website](https://docs.docker.com/compose/) and `docker compose --help` output.

## Building for different base OS

The gNB image supports Fedora, RHEL, CentOS (from quay.io), and Ubuntu. Set build args `OS` and `OS_VERSION` (or use the defaults: Fedora 43).

**Build with CentOS 10 (base image from quay.io), from the repository root:**

```bash
podman build \
  --build-arg OS=quay.io/centos/centos \
  --build-arg OS_VERSION=stream10 \
  -f docker/Dockerfile \
  -t ocudu/gnb:centos10 \
  .
```

With docker-compose, use env vars so the same Dockerfile is used:

```bash
OS=quay.io/centos/centos OS_VERSION=stream10 docker compose -f docker/docker-compose.yml build gnb
```

**RHEL 10 UBI with Red Hat subscription (optional CodeReady Builder via `subscription-manager`):**  
If the public UBI CodeReady Builder CDN is not enough for your environment, you can pass Red Hat Network credentials as a **build secret** so they are not baked into the image layers and are never committed to git. Create a local env-style file (see `docker/rhsm.build.env.example` for the variable names), keep it out of version control, then build from the repository root:

```bash
podman build \
  --secret id=rhsm_build_creds,src="${HOME}/rhsm.build.env" \
  --build-arg OS=registry.access.redhat.com/ubi10/ubi \
  --build-arg OS_VERSION=latest \
  -f docker/Dockerfile \
  -t ocudu/gnb:ubi10 \
  .
```

The Dockerfile mounts that secret as `rhsm_build_creds` and sets `RHSM_SECRET_FILE=/run/secrets/rhsm_build_creds` on the relevant `RUN` lines; install scripts invoke `with_rhsm_rhel10.sh` only on RHEL 10. Without `--secret`, or with an empty file, the image build still uses the public UBI CRB repo where applicable.

## SIGILL (Illegal instruction) on deployment

If the gNB crashes with **SIGILL** (Illegal instruction) when run in a cluster but not on your build host, the image was built with **MARCH=native** (or a CPU-specific march) and is using instructions not available on the cluster nodes. Rebuild the image with a **portable** march so it runs on typical x86_64 nodes:

```bash
podman build \
  --build-arg MARCH=x86-64-v2 \
  --build-arg OS=quay.io/centos/centos \
  --build-arg OS_VERSION=stream10 \
  -f docker/Dockerfile \
  -t quay.io/<your-org>/gnb:<tag> \
  .
```

The default `MARCH` in the Dockerfile is now **x86-64-v2** (portable). Use `MARCH=native` only if the image will run on the same CPU architecture as the build host.

## Debugging segfaults and crashes

If the gNB process segfaults (e.g. after deploying the image from Quay via Helm), use the following to track down the cause.

### 1. Check pod logs

The build enables **ENABLE_BACKWARD** by default, which can print a stack trace on crash. Inspect the pod logs before the restart:

```bash
kubectl logs <pod-name> -c <gnb-container-name> --previous
```

(or `oc logs` on OpenShift). Look for a backtrace or "Segmentation fault" and any lines above it.

### 2. Enable core dumps and persist them

To capture a core file in the cluster, enable core dumps and write them to a directory that is persisted (e.g. emptyDir or a volume). In your Helm values or Deployment, you can:

- Set **securityContext** so core dumps are allowed and a pattern is set, and increase core size:
  - `ulimits` (if your runtime supports it) or an init container that runs `ulimit -c unlimited` and then exec's the main process.
- Run the process with a **wrapper** that sets `ulimit -c unlimited` and `echo /tmp/core.%e.%p | tee /proc/sys/kernel/core_pattern` (if you have permission), then start gnb.
- Mount a **volume** on `/tmp` or `/core` and ensure the core pattern writes there (e.g. `/core/core.%e.%p`).

Then copy the core out before the pod is recreated:

```bash
kubectl cp <namespace>/<pod-name>:/tmp/core.12345 /tmp/core.12345 -c <gnb-container-name>
```

Analyze it later with `gdb` and a binary built with debug info (see below).

### 3. Build a debug image (with symbols)

Build an image with debug symbols so stack traces and core dumps are readable. From the repo root:

```bash
podman build \
  --build-arg OS=quay.io/centos/centos \
  --build-arg OS_VERSION=stream10 \
  --build-arg EXTRA_CMAKE_ARGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo" \
  -f docker/Dockerfile \
  -t quay.io/<your-org>/gnb:debug \
  .
```

Push this image and deploy it (e.g. override the image in Helm to `gnb:debug`). Crashes and core dumps from this image will have symbol information.

### 4. Run under GDB via ENABLE_GDB build arg and entrypoint (recommended)

Build the image with **ENABLE_GDB=1** to install GDB; the image entrypoint then runs gnb under GDB in batch mode so a backtrace is printed to the pod log on crash (SIGSEGV, SIGILL, etc.): `podman build --build-arg ENABLE_GDB=1 -f docker/Dockerfile -t quay.io/<your-org>/gnb:debug .` or `ENABLE_GDB=1 docker compose -f docker/docker-compose.yml build gnb`. The entrypoint (`gnb_entrypoint.sh`) checks the `ENABLE_GDB` env var and runs either `gdb -batch ... --args /usr/local/bin/gnb "$@"` or `gnb "$@"`. Pass gnb args as the container command; no need to override with a full gdb command.

To catch the segfault interactively with a custom image, either:

- **Option A – custom debug image with GDB:** In the Dockerfile’s runtime stage, add `RUN dnf -y install gdb && dnf clean all` (or the equivalent for your base), build and push that image, then override the pod command to run under GDB, e.g.:

```yaml
command: ["gdb", "-batch", "-ex", "run", "-ex", "bt full", "-ex", "quit", "--args", "/usr/local/bin/gnb", "-c", "/gnb_config.yml", "-c", "/gnb_compose_config.yml"]
```

- **Option B – one-off debug pod:** Start a pod with the same image, config, and volumes but with a shell. Install GDB inside the container if the base has a package manager and network, then run:

```bash
gdb -ex run --args /usr/local/bin/gnb -c /gnb_config.yml -c /gnb_compose_config.yml
```

When it segfaults, run `bt full` in GDB for a full backtrace.

### 5. Reproduce locally

Reproduce with the same image and config to see if the crash is environment-specific (e.g. security context, CPU/memory limits, or missing device/config):

```bash
podman run -it --rm quay.io/<your-org>/gnb:<tag> \
  gnb -c /gnb_config.yml -c /gnb_compose_config.yml
```

Use the same config files (mount them or copy in) and, if relevant, similar resource limits.

## Configuration

### Enabling metrics reporting in the gNB

To be able to see gNB's metrics in the monitoring UI (Grafana + InfluxDB + Telegraf), it's required to enable metrics reporting in the gNB config.

**Note**: When using the monitoring stack (`docker-compose.ui.yml` or combined deployments), ensure your gNB configuration includes:

```yml
metrics:
  autostart_stdout_metrics: true
  enable_json: true
remote_control:
  bind_addr: 0.0.0.0
  enabled: true
```

`gnb` and `du` services already have those options configured in their respective docker-compose.yml files.

### Telegraf metrics and Grafana on OpenShift (OCP)

**Grafana is not a metrics ingest endpoint.** It visualizes data from a time-series store (here: InfluxDB 3 in `docker-compose.ui.yml`). To use **Grafana running on OCP**, point Telegraf (or the whole pipeline) at the **same backend** that your OCP Grafana instance uses, or add a second output.

1. **InfluxDB 3 on OCP (or reachable from the cluster)**  
   Set `INFLUXDB3_EXTERNAL_URL` (and token/bucket if required) on the Telegraf workload to the InfluxDB 3 HTTP URL—for example a `Service` DNS name like `http://influxdb3.my-namespace.svc:8081` or an OpenShift `Route`. In OCP Grafana, add an **InfluxDB** datasource with the same server and bucket. No change to `telegraf.conf` is required beyond environment variables.

2. **Prometheus remote write (Mimir, Thanos receive, User Workload Monitoring, etc.)**  
   If OCP Grafana reads **Prometheus** or **Mimir**, configure Telegraf to **remote-write** to that stack’s ingest URL. When `PROMETHEUS_REMOTE_WRITE_URL` is non-empty, the Telegraf entrypoint loads `docker/telegraf/telegraf-ocp-remote-write.conf` in addition to `telegraf.conf` (see commented examples in `docker/.env`). Adjust the URL to your distributor/gateway (often ending in `/api/v1/push`). Optional HTTP basic auth can be enabled by uncommenting the username/password lines in that file and setting the matching env vars.

You can use **both** the existing Influx output and remote write if you want local Compose Grafana and OCP dashboards at the same time.

### Customizations

- Default docker compose uses `configs/gnb_rf_b200_tdd_n78_20mhz.yml` config file. You can change it by setting the variable `${GNB_CONFIG_PATH}` in the shell, in the `docker compose up` command line or using the existing env-file `.env`. More info about how to do it in docker documentation here: [https://docs.docker.com/compose/environment-variables/set-environment-variables/](https://docs.docker.com/compose/environment-variables/set-environment-variables/)

F.e.:

```bash
# Set variables for specific deployment
export GNB_CONFIG_PATH=configs/gnb_custom.yml
docker compose -f docker-compose.yml -f docker-compose.ui.yml up
```

- Network: If you are using an existing core-network on same machine, then you can comment the `5gc` service section and also link your ocudu container to some existing AMF N2/N3 subnet, doing something like this:

```yml
  gnb: ...
    networks:
      network1:
          ipv4_address: 192.168.70.163 # Setting a fixed IP in the "network1" net

networks:
  network1:
    name: my-pre-existing-network
    external: true
```

More info here: [https://docs.docker.com/compose/networking/](https://docs.docker.com/compose/networking/)

### Open5GS Container Parameters

Advanced parameters for the Open5GS container are stored in [open5gs.env](open5gs/open5gs.env) file. You can modify it or use a totally different file by setting `OPEN_5GS_ENV_FILE` variable like in:

```bash
OPEN_5GS_ENV_FILE=/my/open5gs.env docker compose -f docker/docker-compose.yml up 5gc
```

The following parameters can be set:

- MONGODB_IP (default: 127.0.0.1): This is the IP of the mongodb to use. 127.0.0.1 is the mongodb that runs inside this container.
- SUBSCRIBER_DB (default: "001010123456780,00112233445566778899aabbccddeeff,opc,63bfa50ee6523365ff14c1f45f88737d,8000,10.45.1.2"): This adds subscriber data for a single or multiple users to the Open5GS mongodb. It contains either:
  - Comma separated string with information to define a subscriber
  - `subscriber_db.csv`. This is a csv file that contains entries to add to open5gs mongodb. Each entry will represent a subscriber. It must be stored in `docker/open5gs/`
- OPEN5GS_IP: This must be set to the IP of the container (here: 10.53.1.2).
- UE_IP_BASE: Defines the IP base used for connected UEs (here: 10.45.0).
- DEBUG (default: false): This can be set to true to run Open5GS in debug mode.

For more info, please check its own [README.md](open5gs/README.md).

### Open5GS Container Applications

Open5Gs container includes other binaries such as

- 5gc: 5G Core Only
- epc: EPC Only
- app: Both 5G Core and EPC

By default 5gc is launched. If you want to run another binary, remember you can use `docker compose run` to run any command inside the container. For example:

```bash
docker compose -f docker/docker-compose.yml run 5gc epc -c open5gs-5gc.yml
```

If you need to use custom configuration files, remember you can share folder and files between your local PC (host) and the container:

```bash
docker compose -f docker/docker-compose.yml run -v /tmp/my-open5gs-5gc.yml:/config/my-open5gs-5gc.yml 5gc epc -c /config/my-open5gs-5gc.yml
```

### Metric UI Setup

Change the environment variables define in `.env` that are used to setup and deploy the stack

```bash
├── .env         <---
├── docker-compose.yml
├── Dockerfile
└── ...
```

You can access grafana in [http://localhost:3300](http://localhost:3300). By default, you'll be in view mode without needing to log in. If you want to modify anything, you need to log in using following credentials:

- username: `admin`
- password: `admin`

After your fist log, it will ask you to change the password for a new one, but it can be skipped.

Provisioned Dashboards are into `Home > Dashboards`. **They don't support variable substitution**, so if you change default values in `.env` file, you'll need to go to `grafana/dashboards/` and manually search and replace values such as influxdb uid or bucket in every `.json` file.
