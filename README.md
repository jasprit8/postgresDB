# postgresDB

This repository builds and deploys a customized PostgreSQL 16 image. PostgreSQL is a database protocol, not an HTTP server, so it is accessed with `psql`, an application, or another PostgreSQL client rather than directly in a browser.

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

## Connect to PostgreSQL

For local access, forward the PostgreSQL service to your machine:

```sh
kubectl port-forward service/postgres-service 5432:5432
```

Then connect with `psql`:

```sh
psql "postgresql://myuser:mypassword@localhost:5432/mydatabase"
```

From another pod in the Kubernetes cluster, use host `postgres-service`, port `5432`, database `mydatabase`, user `myuser`, and password `mypassword`.

To rerun the initialization scripts, remove the existing database volume first. This deletes all stored data:

```sh
kubectl delete deployment postgres
kubectl delete pvc postgres-pvc
kubectl apply -f postgres-k8s.yaml
```