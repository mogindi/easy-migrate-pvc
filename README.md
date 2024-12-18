# easy-migrate-pvc

Effortlessly migrate Kubernetes PersistentVolumeClaims (PVCs) with a single command. Say goodbye to complicated PVC migration workflows and hello to a fast, customizable, and API-powered solution that just works. Whether you're migrating across clusters, within a single cluster, or even in airgapped environments, **easy-migrate-pvc** has you covered.

## Why Use easy-migrate-pvc?

### 🕶️ Readable & Easy to Use

- The script is designed for clarity and simplicity.
- Minimal dependencies: all you need is `kubectl`, a `kubeconfig`, and permission to create pods.

### ⚡ Speed

- Data is piped through API connections, ensuring secure and efficient transfers.
- Optimized for quick migrations, even for large volumes of data.

### 🔧 Customizable

- Tailor the migration process to your specific needs.
- Use the script out-of-the-box or modify it to fit your environment.

### 🌐 Works Anywhere

- **Cross-cluster migrations**: Transfer PVCs between two clusters without requiring them to directly communicate.
- **In-cluster migrations**: Move PVCs between namespaces within the same cluster.
- **Airgapped environments**: Migrate data even in isolated environments with no direct internet access.

---

## Key Features

- **API-Powered**: No need for rsync, SCP, or other tools. Data transfer is handled entirely via Kubernetes API calls.
- **Versatile Use Cases**: Suitable for migrations involving live workloads, staging environments, or complex multi-cluster setups.
- **Minimal Setup**: Requires only `kubectl` and proper permissions.
- **Handles Edge Cases**: Works in scenarios where traditional rsync solutions over the internet aren't possible.

---

## Example Use Cases

1. **Cross-Cluster Migrations**

   - You're migrating from an on-premises Kubernetes cluster to a cloud-based cluster but can't set up direct network connectivity between the two.

2. **Namespace Cleanup and Reorganization**

   - Consolidating resources into a new namespace within the same cluster while retaining PVC data.

3. **Disaster Recovery in Airgapped Environments**

   - Transferring PVCs between environments that are fully isolated from external networks.

4. **Test Environment Cloning**

   - Duplicate PVCs from production to a staging or testing environment for debugging or development purposes.

5. **Cluster Upgrades**

   - Migrate workloads to a fresh cluster during an upgrade, without worrying about data loss or downtime.

---

## How It Works

### Visual Overview

Below is a high-level diagram illustrating the migration process:

1. **Source Cluster**: Temporary pod reads the data from the source PVC.
2. **Kubernetes API**: Data is securely transferred via `kubectl` commands.
3. **Destination Cluster**: Temporary pod writes the data to the destination PVC.

```
+------------------+                  +-------------------+
|                  |                  |                   |
|  Source Cluster  |   kubectl/API   | Destination Cluster|
|  (src kubeconfig)|<--------------->| (dst kubeconfig)   |
|                  |                  |                   |
+------------------+                  +-------------------+
        |                                      |
   [SRC PVC]                              [DST PVC]
```

This ensures no direct connectivity is needed between the source and destination clusters.

1. Run the script with the required variables provided directly in the execution command.
2. The script creates temporary pods to transfer data between source and target volumes via `kubectl`.
3. Data is securely piped through the Kubernetes API, with no direct connectivity required between clusters.

---

## Prerequisites

1. The source and destination PVCs must already exist before running the script.
2. The source and destination PVCs must not be mounted by other pods during the migration to ensure data consistency.
3. `kubectl` installed and configured.
4. Access to `kubeconfig` files for both source and destination clusters (if applicable).
5. Permissions to create and delete pods in both source and destination namespaces.

---

## Required Variables

### Required Variables in Command
```bash
SRC_KUBECONFIG=~/.kube/config-src \
SRC_NAMESPACE=prod \
SRC_PVC_NAME=app-data \
DST_KUBECONFIG=~/.kube/config-dst \
DST_NAMESPACE=prod \
DST_PVC_NAME=app-data \
easy-migrate-pvc.sh
```

### Optional Variables in Command
```bash
MIG_CONTAINER_IMAGE=ubuntu \  # Can be any image that has the 'tar' command utility. Defaults to 'ubuntu'.
DEBUG=true \                  # Set to 'true' if troubleshooting is needed.
```

---

## Installation

Download the script directly:

```bash
curl -LO https://raw.githubusercontent.com/mogindi/easy-migrate-pvc/main/easy-migrate-pvc.sh
chmod +x easy-migrate-pvc.sh
```

---

## Usage

### Basic Command

Provide the required variables directly in the execution command:

```bash
SRC_KUBECONFIG=~/.kube/config-src \
SRC_NAMESPACE=prod \
SRC_PVC_NAME=app-data \
DST_KUBECONFIG=~/.kube/config-dst \
DST_NAMESPACE=prod \
DST_PVC_NAME=app-data \
easy-migrate-pvc.sh
```

### Example: Cross-Cluster Migration

```bash
SRC_KUBECONFIG=~/.kube/config-src \
SRC_NAMESPACE=prod \
SRC_PVC_NAME=app-data \
DST_KUBECONFIG=~/.kube/config-dst \
DST_NAMESPACE=prod \
DST_PVC_NAME=app-data \
easy-migrate-pvc.sh
```

### Example: In-Cluster Namespace Migration

```bash
SRC_KUBECONFIG=~/.kube/config \
SRC_NAMESPACE=dev \
SRC_PVC_NAME=dev-db-data \
DST_KUBECONFIG=~/.kube/config \
DST_NAMESPACE=staging \
DST_PVC_NAME=staging-db-data \
easy-migrate-pvc.sh
```

---

## Full Application Migration Example

**Note**: This process should be run from a location that has access to both clusters' API endpoints.

1. **Deploy Application Manifests at Destination**

   - Ensure the application manifests (e.g., Deployment, StatefulSet, Service) are deployed in the destination namespace.

2. **Snapshot Source PVC** *(Optional)*

   - If your storage provider supports it, create a snapshot of the source PVC for additional safety.

3. **Set Replicas to 0**

   - Scale down the application at both source and destination to avoid data inconsistency:
     ```bash
     kubectl scale deployment my-app --replicas=0 --kubeconfig=$SRC_KUBECONFIG --namespace=$SRC_NAMESPACE
     kubectl scale deployment my-app --replicas=0 --kubeconfig=$DST_KUBECONFIG --namespace=$DST_NAMESPACE
     ```

4. **Run easy-migrate-pvc**

   - Execute the migration script with the appropriate variables:
     ```bash
     SRC_KUBECONFIG=~/.kube/config-src \
     SRC_NAMESPACE=prod \
     SRC_PVC_NAME=app-data \
     DST_KUBECONFIG=~/.kube/config-dst \
     DST_NAMESPACE=prod \
     DST_PVC_NAME=app-data \
     easy-migrate-pvc.sh
     ```

5. **Scale Up Application**

   - Once the migration is complete, scale the application back up at the destination:
     ```bash
     kubectl scale deployment my-app --replicas=3 --kubeconfig=$DST_KUBECONFIG --namespace=$DST_NAMESPACE
     ```

   - Update DNS and networking configurations as needed to point to the new application endpoint.

---

## Notes

- Temporary pods are automatically created and cleaned up during the process.
- Ensure your destination PVC has adequate storage capacity to handle the data from the source PVC.
- Test migrations in non-production environments before using the script in production.

---

## Contributing

Found a bug or have an idea for an improvement? Contributions are welcome! Feel free to submit a pull request or open an issue on the [GitHub repository](https://github.com/mogindi/easy-migrate-pvc).

---

## License

This project is licensed under the MIT License. See the [LICENSE](https://github.com/mogindi/easy-migrate-pvc/blob/main/LICENSE) file for details.

