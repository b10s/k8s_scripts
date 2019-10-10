#!/bin/bash

set -e

# The idea of the script is to find k8s objects in all namespaces which use deprecated api in upcoming k8s version

#TODO:
# - create temp directory
# - do clean up or keep all in mem without files at all
# - play with IFS more gracefull via function and local
# - generate deprecation in more easy way
# - verify is it trusty way or not
# - check list of requirements (jq, yaml2json, kubectl)
# - print out more info: cluster, found object, maybe count each type of objects
# - color maybe in function
# - allow arguments (deprecations), print help
# - run check do I have access to all namespaces (objects) or not somehow

find_deprecated_api()
{
  # expected format is Object:api, e.g. Deployment:apps/v1beta2
  local deprecation=$1;
  # expected format is a string with object and api in any order e.g. ["apps/v1beta2","Deployment"]
  local all_svc=$2;

  local IFS=':';
  local ARR;
  read -ra ARR <<< "$deprecation";
  printf "%-35s %-30s %s " "kind:${ARR[0]}" "in api:${ARR[1]}" "result:";
  cat $all_svc | grep -i "${ARR[0]}" | grep -iq "${ARR[1]}" && echo -e "\e[31mfound\e[0m" || echo -e "\e[32mnot found\e[0m"
}

main()
{
  temp_dir=$(mktemp -d)
  echo "[INFO] debug files will be saved in $temp_dir";
  echo "[INFO] your context: $(kubectl config current-context)";
  
  all_svc_file="$temp_dir/all-deployed.yaml";
  all_svc_formated_file="$temp_dir/all-deployed-formated.txt";
  
  # hardcoded deprecation, valid for upgrade from 1.15.0 to 1.16.0
  # https://kubernetes.io/blog/2019/07/18/api-deprecations-in-1-16
  # WARNING Pod:v1 keep here for debug purpose
  deprecations='Pod:v1 NetworkPolicy:extensions/v1beta1 PodSecurityPolicy:extensions/v1beta1 DaemonSet:extensions/v1beta1 Deployment:extensions/v1beta1 StatefulSet:extensions/v1beta1 ReplicaSet:extensions/v1beta1 DaemonSet:apps/v1beta2 Deployment:apps/v1beta2 StatefulSet:apps/v1beta2 ReplicaSet:apps/v1beta2'
  
  
  kubectl get all --all-namespaces -o yaml > $all_svc_file;
  yaml2json $all_svc_file | jq -c '.items[]|[.apiVersion, .kind]' > $all_svc_formated_file;
  
  printf "[INFO] found %d objects\n\n" $(wc -l $all_svc_formated_file | grep -Po '^\d+');

  cat $all_svc_formated_file | sort | uniq > "${all_svc_formated_file}.uniq";
  echo "DEPRECATIONS:"
  for d in $deprecations; do
    find_deprecated_api $d "${all_svc_formated_file}.uniq"
  done
}

main
