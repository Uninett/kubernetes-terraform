#!/bin/bash

# Make manifest to create default-deny networkpolicy for namespaces which have this in annotations
# Send output to file, or to kubectl apply -f -

kubeconfig=/paas/ansible/kubeconfig
tmpl="---\napiVersion: extensions/v1beta1\nkind: NetworkPolicy\nmetadata:\n  name: default-deny\n  namespace:"
namespaces=$(kubectl --kubeconfig=$kubeconfig get ns -o json | jq '.items[].metadata.name' | tr -d '"')
for ns in $namespaces
do
	kubectl --kubeconfig=$kubeconfig get ns $ns -o json | jq '.metadata.annotations."net.beta.kubernetes.io/network-policy"' | grep DefaultDeny > /dev/null 2>&1
	if [ "$?" = "0" ]
	then
		echo "${tmpl}$ns"
	fi
done
