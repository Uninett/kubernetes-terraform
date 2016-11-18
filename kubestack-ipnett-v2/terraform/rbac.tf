output "rbac-setup" {
    value = <<EOF
###
# You will need to bootstrap RBAC policies to make cluster fully operational
# Repo is here:
# git clone git@scm.uninett.no:system/kubernetes-rbac-policies.git
#
# Apply config from correct dir like this, for example:
kubectl apply -f kubernetes-rbac-policies/pilot
EOF
}
