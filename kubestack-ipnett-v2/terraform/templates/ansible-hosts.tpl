[master]
${master_hosts}

[etcd]
${etcd_hosts}

[worker]
${worker_hosts}

[coreos:children]
master
etcd
worker

[coreos:vars]
ansible_ssh_user=core
ansible_python_interpreter="/home/core/bin/python"
ansible_ssh_private_key_file="${ssh_key}"

[kubernetes]
${cluster_name} ansible_connection=local

[root:children]
coreos
kubernetes

[root:vars]
dns_service_ip=${dns_service_ip}
cluster_dns_domain=${cluster_dns_domain}
cluster_name=${cluster_name}
k8s_ver=${k8s_ver}
k8s_ver_kubelet=${k8s_ver_kubelet}
network_plugin=${network_plugin}
service_ip_range=${service_ip_range}
