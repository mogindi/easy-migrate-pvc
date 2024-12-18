
##############
# INPUT VARS #
##############

SRC_KUBECONFIG=$SRC_KUBECONFIG
SRC_NAMESPACE=$SRC_NAMESPACE
SRC_PVC_NAME=$SRC_PVC_NAME

DST_KUBECONFIG=$DST_KUBECONFIG
DST_NAMESPACE=$DST_NAMESPACE
DST_PVC_NAME=$DST_PVC_NAME

#################
# Optional Vars #
#################

MIG_CONTAINER_IMAGE=${MIG_CONTAINER_IMAGE:-ubuntu}  # can be any image that has the 'tar' command utility. Defaults to 'ubuntu'
DEBUG=${DEBUG:-false}  # set to 'true' if troubleshooting needed

###################

if [[ -z $SRC_KUBECONFIG ]]; then echo SRC_KUBECONFIG not set. ; exit 1; fi
if [[ -z $SRC_NAMESPACE ]]; then echo SRC_NAMESPACE not set. ; exit 1; fi
if [[ -z $SRC_PVC_NAME ]]; then echo SRC_PVC_NAME not set. ; exit 1; fi
if [[ -z $DST_KUBECONFIG ]]; then echo DST_KUBECONFIG not set. ; exit 1; fi
if [[ -z $DST_NAMESPACE ]]; then echo DST_NAMESPACE not set. ; exit 1; fi
if [[ -z $DST_PVC_NAME ]]; then echo DST_PVC_NAME not set. ; exit 1; fi

SUFFIX=$RANDOM
SRC_CONTAINER_NAME=src-migrate-pvc-$SRC_PVC_NAME-$SUFFIX
SRC_CONTAINER_IMAGE=$MIG_CONTAINER_IMAGE
DST_CONTAINER_NAME=dst-migrate-pvc-$DST_PVC_NAME-$SUFFIX
DST_CONTAINER_IMAGE=$MIG_CONTAINER_IMAGE
SRC_EXTRA_ARGS="--kubeconfig $SRC_KUBECONFIG -n $SRC_NAMESPACE"
DST_EXTRA_ARGS="--kubeconfig $DST_KUBECONFIG -n $DST_NAMESPACE"

function print_green {
  GREEN='\033[0;32m'
  NC='\033[0m' # No Color
  echo -e "${GREEN}$1${NC}"
}

set -e
if [[ $DEBUG == true ]]; then
  set -x
fi

# checks
source_pvc_used_by=$(kubectl $SRC_EXTRA_ARGS describe pvc $SRC_PVC_NAME  | grep "^Used By:" | awk '{print $3}')
test $source_pvc_used_by == "<none>" || ( echo "source pvc used by pod(s) $source_pvc_used_by. Please ensure they are not used. Exiting.." ; exit 1 )
dest_pvc_used_by=$(kubectl $DST_EXTRA_ARGS describe pvc $DST_PVC_NAME  | grep "^Used By:" | awk '{print $3}')
test $dest_pvc_used_by == "<none>" || ( echo "dest pvc used by pod(s) $dest_pvc_used_by. Please ensure they are not used. Exiting.." ; exit 1 )

# create pods
print_green "----> Creating pods.."
cat <<EOF | kubectl $SRC_EXTRA_ARGS apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $SRC_CONTAINER_NAME
spec:
  containers:
  - image: $SRC_CONTAINER_IMAGE
    command:
      - "sleep"
      - "infinity"
    imagePullPolicy: IfNotPresent
    name: src-migrate-pvc
    volumeMounts:
    - name: src-pvc
      mountPath: /mnt/
  restartPolicy: Always
  volumes:
  - name: src-pvc
    persistentVolumeClaim:
      claimName: $SRC_PVC_NAME
EOF
cat <<EOF | kubectl $DST_EXTRA_ARGS apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $DST_CONTAINER_NAME
spec:
  containers:
  - image: $DST_CONTAINER_IMAGE
    command:
      - "sleep"
      - "infinity"
    imagePullPolicy: IfNotPresent
    name: dst-migrate-pvc
    volumeMounts:
    - name: dest-pvc
      mountPath: /mnt/
  restartPolicy: Always
  volumes:
  - name: dest-pvc
    persistentVolumeClaim:
      claimName: $DST_PVC_NAME
EOF

# wait for pods to be ready
print_green "----> Waiting for pods to be ready.."
while kubectl $SRC_EXTRA_ARGS get pods $SRC_CONTAINER_NAME --output="jsonpath={.status.containerStatuses[*].ready}" | grep -q false; do sleep 5; done
while kubectl $DST_EXTRA_ARGS get pods $DST_CONTAINER_NAME --output="jsonpath={.status.containerStatuses[*].ready}" | grep -q false; do sleep 5; done

# prepare pods with pre-migration commands (i.e install packages?)
print_green "----> Prepare pods.."
STARTUP_COMMANDS="/bin/true"  # If additional tools want to be installed - here is where u do it
( kubectl $SRC_EXTRA_ARGS exec $SRC_CONTAINER_NAME -- /bin/bash -c "$STARTUP_COMMANDS" ) &
( kubectl $DST_EXTRA_ARGS exec $DST_CONTAINER_NAME -- /bin/bash -c "$STARTUP_COMMANDS" ) &
wait

# clean destination files (just incase)
print_green "----> Wiping out destination pvc.."
kubectl $DST_EXTRA_ARGS exec $DST_CONTAINER_NAME -- /bin/bash -c 'cd /mnt; ls -A1 | xargs rm -rf'

# copy with tar
print_green "----> Migrating source pvc to destination pvc.."
kubectl $SRC_EXTRA_ARGS exec $SRC_CONTAINER_NAME -- /bin/bash -c 'tar czf - -C / mnt/ --totals' | kubectl $DST_EXTRA_ARGS exec -i $DST_CONTAINER_NAME -- /bin/bash -c 'tar xzf - -C / --totals'

# delete pods
print_green "----> Deleting pods.."
( kubectl $SRC_EXTRA_ARGS delete pod $SRC_CONTAINER_NAME ) &
( kubectl $DST_EXTRA_ARGS delete pod $DST_CONTAINER_NAME ) &
wait

