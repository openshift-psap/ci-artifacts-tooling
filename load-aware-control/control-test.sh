#!/bin/bash
set -x;

# Clear prometheus data so it doesn't pollute the test
PROM_PODS=$(oc get pods -lapp.kubernetes.io/component=prometheus -n openshift-monitoring -oname)
oc delete $PROM_PODS -n openshift-monitoring
sleep 60

artifact_archive="artifacts_$(date +%m%d%Y_%H-%M-%S)"
mkdir $artifact_archive

for scheduler in "trimaran" "default"
do
    oc get pods -n load-aware -owide
    time oc apply -f "${scheduler}_test/pod-t1.yaml" -n load-aware
    time oc apply -f "${scheduler}_test/pod-t2.yaml" -n load-aware
    time oc apply -f "${scheduler}_test/pod-t3.yaml" -n load-aware

    echo "Let history build up for 5 minutes..."
    sleep 300

    time oc apply -f "${scheduler}_test/pod-t4.yaml" -n load-aware

    echo "Waiting for pod-t4 to finish..."
    sleep 180

    artifacts="${artifact_archive}/${scheduler}_artifacts_$(date +%m%d%Y_%H-%M-%S)"
    mkdir $artifacts

    oc logs -n trimaran $(oc get pod -n trimaran -l "app=trimaran-scheduler" | awk 'NR > 1 {print $1}') > "${artifacts}/trimaran.log"
    oc get events -n trimaran > "${artifacts}/trimaran_events.log"
    oc get events -n load-aware > "${artifacts}/load_aware_events.log"
    oc get pods -n load-aware -ojson > "${artifacts}/pods.json"
    oc get pods -n load-aware -owide > "${artifacts}/pods.status"
    oc get nodes -n load-aware -ojson > "${artifacts}/nodes.json"
    oc get nodes -n load-aware -owide > "${artifacts}/nodes.status"
    oc delete pods --all -n load-aware

done
