#/bin/bash
set -x

kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
kubectl delete -f ~/nginx_controller_service.yaml
kubectl delete ns ingress-nginx --ignore-not-found
rm -f ~/nginx_controller_service.yaml
kubectl delete ns ingress-nginx
