# Bank of Splunk - a CISCO company

![GitHub branch check runs](https://img.shields.io/github/check-runs/GoogleCloudPlatform/bank-of-anthos/main)
[![Website](https://img.shields.io/website?url=https%3A%2F%2Fcymbal-bank.fsi.cymbal.dev%2F&label=live%20demo
)](https://cymbal-bank.fsi.cymbal.dev)

**Bank of Splunk** is a sample HTTP-based web app that simulates a bank's payment processing network, allowing users to create artificial bank accounts and complete transactions.

Splunk uses this application to demonstrate how developers can modernize enterprise applications using Splunk Observability products. This application works on any Kubernetes cluster.

If you are using Bank of Splunk, please ★Star this repository to show your interest!

## Screenshots

| Sign in                                                                                                        | Home                                                                                                    |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| [![Login](/docs/img/login.png)](/docs/img/login.png) | [![User Transactions](/docs/img/transactions.png)](/docs/img/transactions.png) |

## Service Architecture

![Architecture Diagram](/docs/img/architecture.png)

| Service                                                 | Language      | Description                                                                                                                                  |
| ------------------------------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| [frontend](/src/frontend)                              | Python        | Exposes an HTTP server to serve the website. Contains login page, signup page, and home page.                                                |
| [ledger-writer](/src/ledger/ledgerwriter)              | Java          | Accepts and validates incoming transactions before writing them to the ledger.                                                               |
| [balance-reader](/src/ledger/balancereader)            | Java          | Provides efficient readable cache of user balances, as read from `ledger-db`.                                                                |
| [transaction-history](/src/ledger/transactionhistory)  | Java          | Provides efficient readable cache of past transactions, as read from `ledger-db`.                                                            |
| [ledger-db](/src/ledger/ledger-db)                     | PostgreSQL    | Ledger of all transactions. Option to pre-populate with transactions for demo users.                                                         |
| [user-service](/src/accounts/userservice)              | Python        | Manages user accounts and authentication. Signs JWTs used for authentication by other services.                                              |
| [contacts](/src/accounts/contacts)                     | Python        | Stores list of other accounts associated with a user. Used for drop down in "Send Payment" and "Deposit" forms.                              |
| [accounts-db](/src/accounts/accounts-db)               | PostgreSQL    | Database for user accounts and associated data. Option to pre-populate with demo users.                                                      |
| [loadgenerator](/src/loadgenerator)                    | Python/Locust | Continuously sends requests imitating users to the frontend. Periodically creates new accounts and simulates transactions between them.      |

## Interactive quickstart (GKE)

The following button opens up an interactive tutorial showing how to deploy Bank of Anthos in GKE:

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?show=ide&cloudshell_git_repo=https://github.com/GoogleCloudPlatform/bank-of-anthos&cloudshell_workspace=.&cloudshell_tutorial=extras/cloudshell/tutorial.md)

## Quickstart (GKE)

1. Ensure you have the following requirements:
   - [Google Cloud project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#creating_a_project).
   - Shell environment with `gcloud`, `git`, and `kubectl`.

2. Clone the repository.

   ```sh
   git clone https://github.com/GoogleCloudPlatform/bank-of-anthos
   cd bank-of-anthos/
   ```

3. Set the Google Cloud project and region and ensure the Google Kubernetes Engine API is enabled.

   ```sh
   export PROJECT_ID=<PROJECT_ID>
   export REGION=us-central1
   gcloud services enable container.googleapis.com \
     --project=${PROJECT_ID}
   ```

   Substitute `<PROJECT_ID>` with the ID of your Google Cloud project.

4. Create a GKE cluster and get the credentials for it.

   ```sh
   gcloud container clusters create-auto bank-of-anthos \
     --project=${PROJECT_ID} --region=${REGION}
   ```

   Creating the cluster may take a few minutes.

5. Deploy Bank of Anthos to the cluster.

   ```sh
   kubectl apply -f ./extras/jwt/jwt-secret.yaml
   kubectl apply -f ./kubernetes-manifests
   ```

6. Wait for the pods to be ready.

   ```sh
   kubectl get pods
   ```

   After a few minutes, you should see the Pods in a `Running` state:

   ``` text
   NAME                                  READY   STATUS    RESTARTS   AGE
   accounts-db-6f589464bc-6r7b7          1/1     Running   0          99s
   balancereader-797bf6d7c5-8xvp6        1/1     Running   0          99s
   contacts-769c4fb556-25pg2             1/1     Running   0          98s
   frontend-7c96b54f6b-zkdbz             1/1     Running   0          98s
   ledger-db-5b78474d4f-p6xcb            1/1     Running   0          98s
   ledgerwriter-84bf44b95d-65mqf         1/1     Running   0          97s
   loadgenerator-559667b6ff-4zsvb        1/1     Running   0          97s
   transactionhistory-5569754896-z94cn   1/1     Running   0          97s
   userservice-78dc876bff-pdhtl          1/1     Running   0          96s
   ```

7. Access the web frontend in a browser using the frontend's external IP.

   ```sh
   kubectl get service frontend | awk '{print $4}'
   ```

   Visit `http://EXTERNAL_IP` in a web browser to access your instance of Bank of Anthos.

8. Once you are done with it, delete the GKE cluster.

   ```sh
   gcloud container clusters delete bank-of-anthos \
     --project=${PROJECT_ID} --region=${REGION}
   ```

   Deleting the cluster may take a few minutes.

## Quickstart (Local Kubernetes)

You can run Bank of Splunk on a local Kubernetes cluster instead of GKE. The instructions below use [k3d](https://k3d.io) because it is lightweight and matches the `k3s-cluster` naming baked into the manifests, but any local cluster works (kind, minikube, or Docker Desktop's built-in Kubernetes) — only the cluster-create and frontend-access steps change.

1. Install the prerequisites:

   - [Docker Desktop](https://www.docker.com/) or [Docker Engine](https://docs.docker.com/engine/install/)
   - [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
   - [`k3d`](https://k3d.io/#installation) — on macOS: `brew install k3d`; on Linux: `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`

   If you plan to build images locally (recommended in step 5, option B), you also need [skaffold 2.9+](https://skaffold.dev/docs/install/), [OpenJDK 21+](https://openjdk.java.net/projects/jdk/21/), [Maven 3.9+](https://maven.apache.org/download.cgi), and [Python 3.12+](https://www.python.org/downloads/). See [`docs/development.md`](/docs/development.md) for details.

2. Clone this fork.

   ```sh
   git clone https://github.com/swaretech/bank-of-splunk
   cd bank-of-splunk/
   ```

3. Create a local cluster:

   ```sh
   k3d cluster create bank-of-splunk
   ```

   > The frontend Service in [`kubernetes-manifests/frontend.yaml`](/kubernetes-manifests/frontend.yaml) is `type: ClusterIP`, so we will access it via `kubectl port-forward` in step 7 — no cluster-level port mapping is needed and the same flow works for kind, minikube, and Docker Desktop.

4. Provide RUM credentials. The frontend reads Splunk RUM settings from a Kubernetes Secret named `workshop-secret`.

   If you have a Splunk Observability Cloud RUM access token and want real RUM and DXA data:

   ```sh
   kubectl create secret generic workshop-secret \
     --from-literal=realm=<YOUR_REALM> \
     --from-literal=rum_token=<YOUR_RUM_TOKEN> \
     --from-literal=app=bank-of-splunk \
     --from-literal=env=local
   ```

   If you are just testing locally without Splunk RUM, use placeholders (the in-browser RUM init will fail to reach Splunk and will not affect the app):

   ```sh
   kubectl create secret generic workshop-secret \
     --from-literal=realm=us0 \
     --from-literal=rum_token=disabled \
     --from-literal=app=bank-of-splunk \
     --from-literal=env=local
   ```

   > Option A release manifests ([`kubernetes-manifests/frontend.yaml`](/kubernetes-manifests/frontend.yaml)) only mount `realm` and `rum_token`. Option B development overlays also require `app` and `env` — include all four keys above to avoid `CreateContainerConfigError` on the frontend pod.

5. Deploy the application. Choose one of the following:

   **Option A — Pull pre-built release images (requires GHCR access)**

   The manifests in [`kubernetes-manifests/`](/kubernetes-manifests) pin immutable images on GitHub Container Registry (`ghcr.io/splunk/bank-of-splunk/*`; see [`kubernetes-manifests/frontend.yaml`](/kubernetes-manifests/frontend.yaml)). Use this path for a quick demo when you already have registry access.

   ```sh
   kubectl apply -f ./extras/jwt/jwt-secret.yaml
   kubectl apply -f ./kubernetes-manifests
   ```

   If pods stay in `ImagePullBackOff` / `ErrImagePull`, the packages are likely private. Create a pull secret with a GitHub PAT that has `read:packages` scope (store the token in an environment variable — do not paste it on the command line):

   ```sh
   kubectl create secret docker-registry ghcr-creds \
     --docker-server=ghcr.io \
     --docker-username=<your-github-username> \
     --docker-password="$GHCR_TOKEN"

   kubectl patch serviceaccount default \
     -p '{"imagePullSecrets": [{"name": "ghcr-creds"}]}'
   ```

   Then delete the failing pods so they are recreated and can pull:

   ```sh
   kubectl delete pods --all
   ```

   > [`kubernetes-manifests/rum-loadgen.yaml`](/kubernetes-manifests/rum-loadgen.yaml) is optional RUM traffic simulation and pulls from a separate image (`ghcr.io/splunk/online-boutique/rumloadgen`). Skip it if you do not need automated RUM load: `kubectl delete deployment bankofsplunk-loadgen --ignore-not-found`
   >
   > For **iOS mobile RUM** sessions, see [`src/ios/rum-loadgen/README.md`](/src/ios/rum-loadgen/README.md) — run Appium scenario replay locally on macOS against your k3d backend.

   **Option B — Build locally and load into the cluster (recommended)**

   Build all services from source and load images directly into your local cluster — no GHCR credentials, no outbound image pulls, and no registry to run. This is the most secure default for local development and air-gapped environments.

   For **backend APM** (in addition to browser RUM/DXA), install the Splunk OTel Collector before deploying the app. Use your Splunk Observability **access token** (not the RUM token):

   ```sh
   export SPLUNK_REALM=us0
   export SPLUNK_ACCESS_TOKEN=<your-observability-access-token>
   ./extras/local-k8s/install-splunk-otel-collector.sh
   ```

   Or set `SPLUNK_ACCESS_TOKEN` when running the deploy script below (it installs the collector automatically unless `SKIP_COLLECTOR=true`).

   The fastest path is the helper script (tested on k3d + Apple Silicon):

   ```sh
   export SPLUNK_ACCESS_TOKEN=<your-observability-access-token>   # optional but required for APM
   ./extras/local-k8s/deploy-option-b.sh
   ```

   It builds the databases with Skaffold, builds the application images with Docker/Jib, imports them into k3d, and deploys the development overlays. Re-run with `SKIP_BUILD=true ./extras/local-k8s/deploy-option-b.sh` to redeploy without rebuilding.

   After a full build, the script writes `.local-build-artifacts.json` at the repo root — a Skaffold-style manifest of the images that were built (`:local` tags for application services; SHA256 content tags for the database images, matching Skaffold's `tagPolicy: sha256` on the DB modules). This file is **local-only**: it is listed in `.gitignore`, regenerated on each Option B build, and is **not** read by CI, Cloud Build, or release scripts (those use ephemeral `artifacts.json` instead). It exists so you can inspect or wire local tooling against the exact tags from your last build without committing machine-specific hashes.

   **Manual equivalent** (if you prefer not to use the script):

   ```sh
   # Shared config
   kubectl apply -f ./extras/jwt/jwt-secret.yaml
   kubectl apply -f ./kubernetes-manifests/config.yaml
   kubectl apply -f ./iac/acm-multienv-cicd-anthos-autopilot/base/sa.yaml

   skaffold config set --kube-context k3d-bank-of-splunk local-cluster true

   # Databases (Skaffold modules — no e2e-tests dependency)
   skaffold run --module=accounts-db --profile=development \
     --default-repo=bank-of-splunk --skip-tests=true
   skaffold run --module=ledger-db --profile=development \
     --default-repo=bank-of-splunk --skip-tests=true

   # Application images — see deploy-option-b.sh for build commands, then:
   k3d image import bank-of-splunk/frontend:local ... -c bank-of-splunk

   # Deploy overlays (substitute bank-of-splunk/<service>:local into each kustomize output)
   kubectl kustomize src/frontend/k8s/overlays/development \
     | sed 's|image: frontend|image: bank-of-splunk/frontend:local|' | kubectl apply -f -
   # ... repeat for contacts, userservice, balancereader, ledgerwriter, transactionhistory, loadgenerator
   ```

   > **Do not use a bare `skaffold run` at the repo root** for Option B. The root Skaffold config pulls in an `e2e-tests` image build (Cypress) that is unrelated to running the app and often fails on corporate networks or Docker Desktop proxy settings. The script and manual flow above avoid it.

   To tear down: `kubectl delete -f ./kubernetes-manifests/config.yaml` plus `skaffold delete --module=accounts-db --profile=development` (repeat per module), or `k3d cluster delete bank-of-splunk`. To stop loading images locally: `skaffold config unset --kube-context k3d-bank-of-splunk local-cluster`.

   > **kind / minikube / Docker Desktop**: set `KUBE_CONTEXT=$(kubectl config current-context)` when running the script. Skaffold detects these runtimes and loads images the same way when `local-cluster` is enabled.
   >
   > **Local registry (optional)**: create the cluster with a localhost-only registry — `k3d cluster create bank-of-splunk --registry-create bank-of-splunk-registry:127.0.0.1:5111` — push built images there, and point `--default-repo=localhost:5111/bank-of-splunk` in Skaffold build steps.

   <details>
   <summary><strong>Option B troubleshooting</strong> (Apple Silicon, Docker proxy, build errors)</summary>

   **Apple Silicon (M-series Mac)** — k3d nodes are usually `arm64`. Use `--platform=linux/arm64` (the script detects this automatically). For Java services, the pinned Jib base image (`eclipse-temurin:17-jre-alpine`) is amd64-only; the script switches to `eclipse-temurin:17-jre` on arm64. On Intel Macs / amd64 Linux, `linux/amd64` is used instead.

   **Docker Desktop HTTP proxy** — if Debian-based image builds fail with `apt-get update` / `404 Not Found` against `deb.debian.org` while the host can reach the internet, Docker Desktop's internal proxy is usually the cause (`docker info | grep -i proxy`). Pass empty proxy build-args to clear it:

   ```sh
   docker build \
     --build-arg HTTP_PROXY= --build-arg HTTPS_PROXY= \
     --build-arg http_proxy= --build-arg https_proxy= \
     -t bank-of-splunk/frontend:local src/frontend
   ```

   **Python build: `ModuleNotFoundError: pkg_resources`** — Splunk OTel bootstrap requires `setuptools` with `pkg_resources` on Python 3.12. The service Dockerfiles pin `setuptools>=70,<81`; pull the latest repo if you see this during `splunk-py-trace-bootstrap`.

   **Pods stuck with `FailedCreate` / `serviceaccount "bank-of-anthos" not found`** — apply the ServiceAccount: `kubectl apply -f ./iac/acm-multienv-cicd-anthos-autopilot/base/sa.yaml`, then `kubectl rollout restart deployment --all`.

   **Frontend `CreateContainerConfigError` / `couldn't find key app in Secret workshop-secret`** — the development overlay expects four secret keys (`realm`, `rum_token`, `app`, `env`). Recreate the secret as shown in step 4.

   **Only three Docker containers visible** — `k3d-bank-of-splunk-server-0`, `k3d-bank-of-splunk-serverlb`, and `k3d-bank-of-splunk-tools` are the k3d cluster itself, not Bank of Splunk application images. Application images are imported into the k3s node filesystem via `k3d image import` or Skaffold's `local-cluster` mode.

   </details>

6. Wait for the pods to be ready (Ctrl-C to exit the watch):

   ```sh
   kubectl get pods --watch
   ```

7. Open the frontend with a port-forward (run in a separate terminal):

   ```sh
   kubectl port-forward service/frontend 8083:8083
   ```

   Then browse to <http://localhost:8083>. This same command works for kind, minikube, and Docker Desktop clusters too.

8. Sign in with the demo credentials defined in [`kubernetes-manifests/config.yaml`](/kubernetes-manifests/config.yaml):

   - **Username**: `testuser`
   - **Password**: `bankofsplunk`

9. When you are done, tear it all down:

   ```sh
   k3d cluster delete bank-of-splunk
   ```

   For kind / minikube / Docker Desktop, use that tool's cluster-delete command. To remove workloads without deleting the cluster, run `kubectl delete -f ./kubernetes-manifests` (Option A) or `skaffold delete --profile development` (Option B).

> **Note on backend telemetry**: Option B dev overlays export OTLP to the node Splunk OTel Collector at `http://<node-ip>:4317`. Without the collector, browser **RUM and DXA still work** (browser → Splunk directly via `rum_token`), but **backend APM traces are dropped**. Install the collector with [`extras/local-k8s/install-splunk-otel-collector.sh`](/extras/local-k8s/install-splunk-otel-collector.sh) or let [`deploy-option-b.sh`](/extras/local-k8s/deploy-option-b.sh) install it when `SPLUNK_ACCESS_TOKEN` is set. See [`kubernetes-deployment/AB-VARIANT-DEPLOYMENT.md`](/kubernetes-deployment/AB-VARIANT-DEPLOYMENT.md) for multi-namespace A/B deployments.

### Digital Experience Analytics (DXA)

The frontend is instrumented for **Splunk RUM** and **Splunk DXA** using stable `data-*` attributes on interactive elements. DXA builds on RUM data — there is no separate browser agent.

**Data attribute taxonomy** (low cardinality only; never put PII in attribute values):

| Attribute | Purpose | Examples |
|-----------|---------|----------|
| `data-trackid` | Primary action ID for DXA event definitions | `login-submit`, `deposit-open`, `payment-submit` |
| `data-component` | UI region / widget | `auth-form`, `deposit-modal`, `account-nav` |
| `data-flow` | Funnel / journey name | `authentication`, `deposit`, `payment`, `registration` |

Each page sets `data-trackid="{{ dxa_page }}"` on `<body>` (`home`, `login`, `signup`, `consent`). The RUM agent allowlists these attributes via `dataAttributesToCapture` in [`src/frontend/templates/shared/html_head.html`](/src/frontend/templates/shared/html_head.html).

**Recommended DXA event definitions** (create in Observability Cloud → Digital Experience Analytics → Event Definitions, using the element picker):

| Event | Filter |
|-------|--------|
| Login submitted | click + `data-trackid=login-submit` |
| Deposit completed (intent) | click + `data-trackid=deposit-submit` |
| Payment completed (intent) | click + `data-trackid=payment-submit` |
| Registration started | click + `data-trackid=signup-navigate` |
| Auth failure | custom event `auth.login_failed` |
| Form validation issue | custom event `form.validation_failed` |

**Verification checklist**:

1. Collector ready: `kubectl get daemonset -n default splunk-otel-collector-agent`
2. RUM click spans include `data-trackid` tags in Observability Cloud
3. DXA element picker shows allowlisted attributes on tagged buttons
4. Deposit submit links browser interaction span to `frontend` → downstream APM trace via shared trace ID
5. Session replay masks balances, account numbers, and form inputs

See [`src/frontend/README.md`](/src/frontend/README.md) for frontend service details.

### Native iOS app

A SwiftUI iOS client lives in [`src/ios/BankOfSplunk/`](src/ios/BankOfSplunk/). It uses the same backend via a JSON API (`/api/v1/*` on the Flask frontend) and is instrumented with **Splunk RUM for Mobile 2.x** and DXA-compatible tracking.

**Mobile DXA event definitions** (create in Observability Cloud, parallel to web):

| Event | Filter |
|-------|--------|
| Login submitted | `track.id=login-submit` |
| Deposit completed (intent) | `track.id=deposit-submit` |
| Payment completed (intent) | `track.id=payment-submit` |
| Registration started | `track.id=signup-navigate` |
| Auth failure | custom event `auth.login_failed` |
| Form validation issue | custom event `form.validation_failed` |

Setup: copy `src/ios/BankOfSplunk/Config/Secrets.xcconfig.example` to `Secrets.xcconfig`, port-forward frontend to `:8083`, open `BankOfSplunk.xcodeproj`. See [`src/ios/BankOfSplunk/README.md`](/src/ios/BankOfSplunk/README.md).

## Additional deployment options

- **Workload Identity**: [See these instructions.](/docs/workload-identity.md)
- **Cloud SQL**: [See these instructions](/extras/cloudsql) to replace the in-cluster databases with hosted Google Cloud SQL.
- **Multi-Cluster with Cloud SQL**: [See these instructions](/extras/cloudsql-multicluster) to replicate the app across two regions using GKE, Multi-Cluster Ingress, and Google Cloud SQL.
- **Istio**: [See these instructions](/extras/istio) to configure an IngressGateway.
- **Anthos Service Mesh**: ASM requires Workload Identity to be enabled in your GKE cluster. [See the workload identity instructions](/docs/workload-identity.md) to configure and deploy the app. Then, apply `extras/istio/` to your cluster to configure frontend ingress.
- **Java Monolith (VM)**: We provide a version of this app where the three Java microservices are coupled together into one monolithic service, which you can deploy inside a VM (eg. Google Compute Engine). See the [ledgermonolith](/src/ledgermonolith) directory.

## Documentation

<!-- This section is duplicated in the docs/ README: https://github.com/GoogleCloudPlatform/bank-of-anthos/blob/main/docs/README.md -->

- [Development](/docs/development.md) to learn how to run and develop this app locally.
- [Environments](/docs/environments.md) to learn how to deploy on non-GKE clusters.
- [Workload Identity](/docs/workload-identity.md) to learn how to set up Workload Identity.
- [CI/CD pipeline](/docs/ci-cd-pipeline.md) to learn details about and how to set up the CI/CD pipeline.
- [Troubleshooting](/docs/troubleshooting.md) to learn how to resolve common problems.

## Demos featuring Bank of Anthos

- [Tutorial: Explore Anthos (Google Cloud docs)](https://cloud.google.com/anthos/docs/tutorials/explore-anthos)
- [Tutorial: Migrating a monolith VM to GKE](https://cloud.google.com/migrate/containers/docs/migrating-monolith-vm-overview-setup)
- [Tutorial: Running distributed services on GKE private clusters using ASM](https://cloud.google.com/service-mesh/docs/distributed-services-private-clusters)
- [Tutorial: Run full-stack workloads at scale on GKE](https://cloud.google.com/kubernetes-engine/docs/tutorials/full-stack-scale)
- [Architecture: Anthos on bare metal](https://cloud.google.com/architecture/ara-anthos-on-bare-metal)
- [Architecture: Creating and deploying secured applications](https://cloud.google.com/architecture/security-foundations/creating-deploying-secured-apps)
- [Keynote @ Google Cloud Next '20: Building trust for speedy innovation](https://www.youtube.com/watch?v=7QR1z35h_yc)
- [Workshop @ IstioCon '22: Manage and secure distributed services with ASM](https://www.youtube.com/watch?v=--mPdAxovfE)
