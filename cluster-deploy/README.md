# Neo4j Causal cluster deployment

##  Deployment

- Login to the openshift cluster


- Create a project 
```
▶ oc new-project demo
```
- Navigate to the correct directory. The yamls related to neo4j-cluster deployment are located in `neo4j-cluster-deploy` directory
```
▶ cd cluster-deploy
```

- Create COS secret using HMAC creds. The secret is referenced in the helm values file to access the database dump file stored in cos bucket
```
▶ oc create -f cos-secret.yaml
```

- To avoid any permission issues, provide priviliges to `default` svc account to run as `anyuid`
```
▶ oc adm policy add-scc-to-user anyuid -z default
```

- Edit the helm values file before installing the helm chart - `deploy-values.yaml`

- (Optional) To deploy all the pods of the neo4j cluster to a specific workerpool, provide the workerpool name


```
## Affinity for pod assignment
## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: ibm-cloud.kubernetes.io/worker-pool-name
          operator: In
          values:
          - <workerpool-name>
```
- Note the authentication config. By not providing a pwd, one is created and stored in a secret with name `<helm-release-name>-neo4j-secrets`
```
# Use password authentication
authEnabled: true

## Specify password for neo4j user
## Defaults to a random 10-character alphanumeric string if not set and authEnabled is true
# neo4jPassword:
```
- (Optional) Create a custom storage class according to you requirements 
```
▶ oc create -f custom-storageclass.yaml 
```

- Note the storageclass being used in values file to create storage volumes. 
    - IBM standard StorageClasses can be used (or)
    - Custom storageclass name created in the above step can be used  
    To view standard storage classes,
    ```
    ▶ oc get storageclasses
    NAME                        PROVISIONER         AGE
    default                     ibm.io/ibmc-file    172m
    ibmc-block-bronze           ibm.io/ibmc-block   172m
    ibmc-block-custom           ibm.io/ibmc-block   172m
    ibmc-block-gold (default)   ibm.io/ibmc-block   172m
    ibmc-block-retain-bronze    ibm.io/ibmc-block   172m
    ibmc-block-retain-custom    ibm.io/ibmc-block   172m
    ibmc-block-retain-gold      ibm.io/ibmc-block   172m
    ibmc-block-retain-silver    ibm.io/ibmc-block   172m
    ibmc-block-silver           ibm.io/ibmc-block   172m
    ibmc-file-bronze            ibm.io/ibmc-file    172m
    ibmc-file-bronze-gid        ibm.io/ibmc-file    172m
    ibmc-file-custom            ibm.io/ibmc-file    172m
    ibmc-file-gold              ibm.io/ibmc-file    172m
    ibmc-file-gold-gid          ibm.io/ibmc-file    172m
    ibmc-file-retain-bronze     ibm.io/ibmc-file    172m
    ibmc-file-retain-custom     ibm.io/ibmc-file    172m
    ibmc-file-retain-gold       ibm.io/ibmc-file    172m
    ibmc-file-retain-silver     ibm.io/ibmc-file    172m
    ibmc-file-silver            ibm.io/ibmc-file    172m
    ibmc-file-silver-gid        ibm.io/ibmc-file    172m
    ```
```
storageClass: "ibmc-block-gold"
```
- Note, the env vars used for neo4j config
```
  ## Pass extra environment variables to the Neo4j container.
  ##
  extraVars:
  - name: NEO4J_ACCEPT_LICENSE_AGREEMENT
    value: "yes"
  - name: NEO4J_dbms_backup_address
    value: "0.0.0.0:6362"
  - name: NEO4J_dbms_backup_enabled
    value: "true"
  - name: NEO4J_dbms_allow__upgrade
    value: "true"
```


- Install the helm chart

```
▶ helm install test -f deploy-values.yaml stable/neo4j
```

- Install the helm chart from `deploy-with-restore-values.yaml`. This is used when you have to standup a neo4j cluster from a stored backupfile

## Verification


## Deletion