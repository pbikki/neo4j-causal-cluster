# Neo4j Causal cluster deployment

The directory `cluster-deploy` has files required for install of neo4j cluster deployment using a helm chart. 

- `deploy-values.yaml` - values file that will be used while installing the helm chart of neo4j with `initContainer` to load the data from adump file stored in S3/COS
- `deploy-with-restore-values.yaml` - values file that will be used while installing the helm chart of neo4j with `initContainer` to restore data from a backup stored in S3/COS


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
- (Optional) Note the parameters in `cores`. Change the number of cores, size of the volumes being mounted and storage class if required
  ```
  # Cores
  core:
    numberOfServers: 3
    persistentVolume:
      ## whether or not persistence is enabled
      ##
      enabled: true

      ## core server data Persistent Volume mount root path
      ##
      mountPath: /data

      ## core server data Persistent Volume size
      ##
      size: 30Gi

      ## core server data Persistent Volume Storage Class
      ## If defined, storageClassName: <storageClass>
      ## If set to "-", storageClassName: "", which disables dynamic provisioning
      ## If undefined (the default) or set to null, no storageClassName spec is
      ##   set, choosing the default provisioner.  (gp2 on AWS, standard on
      ##   GKE, AWS & OpenStack)
      storageClass: "ibmc-block-gold"

      ## Subdirectory of core server data Persistent Volume to mount
      ## Useful if the volume's root directory is not empty
      ##
      ## subPath: ""
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

### Installing the helm chart for neo4j

- Install the helm chart

  ```
  ▶ helm install test -f deploy-values.yaml stable/neo4j
  ```

- Install the helm chart from `deploy-with-restore-values.yaml`. This is used when you have to standup a neo4j cluster from a stored backupfile

  ```
  ▶ helm install test1 -f deploy-with-restore-values.yaml stable/neo4j
  ```

## Verification
- All core pods must be in `Running` state eventually
- Check the pod logs and initContainer logs
  ```
  ▶ oc logs -f `pod-name`
  ```
  ```
  ▶ oc logs -f `pod-name` -c `container-name`
  ```
  If the casual is successfully formed, the last few lines of the logs like below will be seen on all cores
  ```
  2020-04-25 02:49:24.362+0000 INFO  This instance bootstrapped the cluster.
  2020-04-25 02:49:54.725+0000 INFO  Waiting to hear from leader...
  2020-04-25 02:50:22.726+0000 INFO  Waiting to hear from leader...
  2020-04-25 02:50:50.728+0000 INFO  Waiting to catchup with leader... we are 0 entries behind leader at 2.
  2020-04-25 02:50:50.729+0000 INFO  Successfully joined the Raft group.
  2020-04-25 02:50:50.818+0000 INFO  Sending metrics to CSV file at /var/lib/neo4j/metrics
  2020-04-25 02:50:51.537+0000 INFO  Bolt enabled on 0.0.0.0:7687.
  2020-04-25 02:50:53.834+0000 WARN  Server thread metrics not available (missing neo4j.server.threads.jetty.all)
  2020-04-25 02:50:53.835+0000 WARN  Server thread metrics not available (missing neo4j.server.threads.jetty.idle)
  2020-04-25 02:50:53.961+0000 INFO  Started.
  2020-04-25 02:50:54.287+0000 INFO  Mounted REST API at: /db/manage
  2020-04-25 02:50:54.387+0000 INFO  Server thread metrics have been registered successfully
  2020-04-25 02:50:55.453+0000 INFO  Remote interface available at http://test-neo4j-core-0.test-neo4j.demo.svc.cluster.local:7474/
  ```


## Deletion

- Executing the below command will delete the neo4j cluster (deployment, statefulset, any secrets created by the helm install and eventually the pods). Be absoluetly sure before executing it
  ```
  ▶ helm uninstall test
  ```
- PVCs might have to be deleted manually

  Check for pvcs created by the helm install and delete them carefully

  ```
  ▶ oc get pvc
  NAME                           STATUS    VOLUME                     CAPACITY   ACCESS MODES   STORAGECLASS                  AGE
  datadir-test-neo4j-core-0   Bound     pvc-6938cd51-a040-467c-a1cc0   30Gi       RWO            ibmc-block-gold               19d
  datadir-test-neo4j-core-1   Bound     pvc-467719e4-b022-489e-bb65   30Gi       RWO            ibmc-block-gold               19d
  datadir-test-neo4j-core-2   Bound     pvc-cebe88b4-8a39-4cc2-8497   30Gi       RWO            ibmc-block-gold               19d
  ```
- Delete each pvc. Make sure to delete only the PVCs create by the helm chart you are trying to uninstall
  ```
  ▶ oc delete pvc <pvc-name>
  ```

