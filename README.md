# postgresDB

This repository builds a PostgreSQL 16 image and deploys it with pgAdmin. PostgreSQL is a database protocol, not an HTTP server, so the browser-facing service is pgAdmin.

## Build

```sh
docker build -t postgresdb:latest .
```

The image initializes a new database with both `init.sql` and `task-mapping-table.sql`. PostgreSQL only runs these scripts when the data directory is empty.

## Deploy to Kubernetes

```sh
kubectl apply -f postgres-k8s.yaml
kubectl get pods
kubectl get services
```

The Kubernetes nodes must be able to pull `postgresdb:latest`. For a local Minikube cluster, load the image first:

```sh
minikube image load postgresdb:latest
```

For a remote cluster, tag and push the image to a registry, then change the `image` value in `postgres-k8s.yaml` to that registry path.

## Open in a browser

On a cluster with a working load balancer, open the external address for `pgadmin-service`:

```sh
kubectl get service pgadmin-service
```

For a local cluster, use port forwarding instead:

```sh
kubectl port-forward service/pgadmin-service 8080:80
```

Open `http://localhost:8080` and sign in with `admin@example.com` / `adminpassword`. Add a PostgreSQL server in pgAdmin using host `postgres-service`, port `5432`, database `mydatabase`, user `myuser`, and password `mypassword`.