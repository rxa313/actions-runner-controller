#!/usr/bin/env bash

set -e

tpe=${ACCEPTANCE_TEST_SECRET_TYPE}

VALUES_FILE=${VALUES_FILE:-$(dirname $0)/values.yaml}

echo "Setup controller secret before deployment"
if [ "${tpe}" == "token" ]; then
  if ! kubectl get secret controller-manager -n actions-runner-system >/dev/null; then
    kubectl create secret generic controller-manager \
      -n actions-runner-system \
      --from-literal=github_token=${GITHUB_TOKEN:?GITHUB_TOKEN must not be empty}
  fi
elif [ "${tpe}" == "app" ]; then
  kubectl create secret generic controller-manager \
    -n actions-runner-system \
    --from-literal=github_app_id=${APP_ID:?must not be empty} \
    --from-literal=github_app_installation_id=${INSTALLATION_ID:?must not be empty} \
    --from-file=github_app_private_key=${PRIVATE_KEY_FILE_PATH:?must not be empty}
else
  echo "ACCEPTANCE_TEST_SECRET_TYPE must be set to either \"token\" or \"app\"" 1>&2
  exit 1
fi

tool=${ACCEPTANCE_TEST_DEPLOYMENT_TOOL}

echo "Deploy controller ..."
if [ "${tool}" == "helm" ]; then
  echo "Helm selected as deployment tool"
  helm upgrade --install actions-runner-controller \
    charts/actions-runner-controller \
    -n actions-runner-system \
    --create-namespace \
    --set syncPeriod=${SYNC_PERIOD} \
    --set authSecret.create=false \
    --set image.repository=${NAME} \
    --set image.tag=${VERSION} \
    -f ${VALUES_FILE}
  kubectl apply -f charts/actions-runner-controller/crds
  kubectl -n actions-runner-system wait deploy/actions-runner-controller --for condition=available --timeout 60s
else
  echo "kubectl selected as deployment tool"
  kubectl apply \
    -n actions-runner-system \
    -f release/actions-runner-controller.yaml
  kubectl -n actions-runner-system wait deploy/controller-manager --for condition=available --timeout 120s
fi