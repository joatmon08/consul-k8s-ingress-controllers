# Consul with Kubernetes Ingress

## Prerequisites

1. Install a Kubernetes cluster with a load balancer. This example
   uses GKE. You can run Terraform to create the cluster.
   ```shell
   cd cluster && terraform init && terraform apply
   ```

1. Install Consul 1.10+ to the Kubernetes cluster.
   ```shell
   helm install consul hashicorp/consul --version v0.32.0-beta3 --values consul.yaml
   ```

   > NOTE: You must have ACLs enabled in order for app-aware intentions to work. The
     `values.yaml` does enable them, so make sure to get an ACL token if you want to
     access the Consul cluster.

1. Apply intentions and proxy defaults to Consul on Kubernetes.
   ```shell
   kubectl apply -f consul/
   ```

1. Deploy the example workloads, UI and web, and intentions for
   services.
   ```shell
   kubectl apply -f apps/
   ```

## Kong

We use Kong's Helm chart to install Kong Ingress.

> NOTE: We set the service account name to `<helm name>-proxy`
  because Consul needs it to be the same as the service for ACLs.

1. Add and install the Kong Helm chart.
   ```shell
   helm repo add kong https://charts.konghq.com
   helm repo update
   ```

1. Review `kong/values.yaml`. We need to add a few annotations and make some
   updates to the Kong deployment.
   - Define the service account name for the ingress controller to `example-kong-proxy`.
     The service account name needs to match the service name for Consul ACLs.
   - Update all `livenessProbe` and `readinessProbe` to TCP (for now).
   - Add `podAnnotations` for Consul to:
     - Inject the sidecar proxy
     - Enable transparent proxy
     - Overwrite probes
     - Exclude inbound ports for 8000 and 8443. This allows the load balancer
       to access the proxy!

1. Deploy the Kong proxy and ingress controller.
   ```shell
   helm install -n default example kong/kong -f kong/values.yaml
   ```

1. Apply the Kong Ingress and rate-limiting plugin for the UI.
   ```shell
   kubectl apply -f kong/kubernetes/
   ```

1. Get the load balancer IP address for Kong proxy and open it in your browser.
   ```shell
   kubectl get svc example-kong-proxy  -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
   ```

1. Add `/ui` to the end of the URL in your browser.
   You should be able to access the fake-service UI. It will use Consul to load balance
   between a baseline and canary version of `web`.

   ![](img/kong-fake-service.png)

1. If you refresh the browser, you'll eventually get an error that Kong is rate-limiting
   requests to the API.

   ![](img/kong-fake-service-rate-limit.png)

## Traefik

We use Traefik's Helm chart to install Traefik Ingress.

1. Add and install the Kong Helm chart.
   ```shell
   helm repo add traefik https://helm.traefik.io/traefik
   helm repo update
   ```

1. Get the Kubernetes service IPs. You'll need it to exclude from transparent proxy.
   ```shell
   export KUBERNETES_SVC_IP=$(kubectl get svc kubernetes -o=jsonpath='{.spec.clusterIP}')
   ```

1. Create a `values.yaml` file that excludes ports, certain CIDR blocks, and disables
   probes.
   ```shell
   cat <<EOF > traefik/values.yaml
   deployment:
   podAnnotations:
      consul.hashicorp.com/connect-inject: "true"
      consul.hashicorp.com/connect-service: "traefik"
      consul.hashicorp.com/transparent-proxy: "true"
      consul.hashicorp.com/transparent-proxy-overwrite-probes: "false"
      consul.hashicorp.com/transparent-proxy-exclude-inbound-ports: "9000,8000,8443"
      consul.hashicorp.com/transparent-proxy-exclude-outbound-ports: "443"
      consul.hashicorp.com/transparent-proxy-exclude-outbound-cidrs: "${KUBERNETES_SVC_IP}/32"

   logs:
   general:
      level: DEBUG
   EOF
   ```

1. Deploy the Traefik proxy and ingress controller.
   ```shell
   helm install -n default traefik traefik/traefik -f traefik/values.yaml
   ```

1. Update the UI service defaults to directly dial the pod IP.
   ```shell
   export CONSUL_HTTP_ADDR=$(kubectl get svc consul-ui -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
   export CONSUL_HTTP_TOKEN=$(kubectl get secrets consul-bootstrap-acl-token -o=jsonpath='{.data.token}' | base64 -d)
   consul config write traefik/consul/service-defaults.hcl
   ```

1. Apply the Traefik IngressRoute
   ```shell
   kubectl apply -f traefik/kubernetes/
   ```

## Cleanup

Delete Kong resources.

```shell
kubectl delete -f kong/kubernetes/
```


Delete Traefik resources.

```shell
kubectl delete -f traefik/kubernetes/
```

Delete Kong proxy and ingress controller.

```shell
helm del example
```

Delete Traefik proxy and ingress controller.

```shell
helm del traefik
```

Delete applications.

```shell
kubectl delete -f apps/
```

Delete Consul resources.

```shell
kubectl delete -f consul/
```

Delete Consul Helm chart.

```shell
helm del consul
```