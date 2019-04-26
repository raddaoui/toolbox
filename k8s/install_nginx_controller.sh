#/bin/bash

set -x
set -e

# source: https://kubernetes.github.io/ingress-nginx/deploy/#gce-gke
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
kubectl create ns ingress-nginx && sleep 2 || echo 'ingress-nginx ns exists'

# to make the nginx ingress controller use a private or a static ip, you can add a couple of annotations
# for more information on using internal and static service with gke:
# https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balancing
curl -o ~/nginx_controller_service.yaml \
    https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/cloud-generic.yaml

# NOTE: you must reserve an external static ip with your cloud provider and export the ip as follows export ingress_controller_ip=[ip]
# edit the nginx controller manifest to listen on our reserved static ip
awk -v v="${ingress_controller_ip}" '/type: LoadBalancer/{print;print "  loadBalancerIP: "v;next}1' ~/nginx_controller_service.yaml > tmp && mv tmp ~/nginx_controller_service.yaml

# install the ingress controller service into the cluster
kubectl apply -f ~/nginx_controller_service.yaml

sleep 30
POD_NAMESPACE=ingress-nginx
POD_NAME=$(kubectl get pods -n $POD_NAMESPACE -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -n $POD_NAMESPACE -- /nginx-ingress-controller --version
