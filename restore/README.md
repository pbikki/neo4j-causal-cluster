# Neo4j restore container 

The docker image is created for performing neo4j restore. This image can be used in an initContainer during the neo4j causal cluster deployment to restore the data from a backup onto all the cores before starting the neo4j server

```
├── Dockerfile
├── README.md
├── restore-configmap.yaml
├── restore-pod.yaml
├── gcs-restore-v3.5.sh
├── s3-restore-v3.5.sh
└── s3-restore-v4.0.sh
```
- `gcs-backup-v3.5.sh` - script to perform restore from a backup in stored in google cloud storage (used as a reference to customize scripts for S3/IBM COS)
- `s3-backup-v3.5.sh` - script to perform restore for neo4j-3.5 from a backup stored in s3 (This is the one that is used as entrypoint script because the neo4j cluster deployments files deploy neo4j 3.5)
- `s3-backup-v4.0.sh` - script to perform restore for neo4j-3.5 from a backup stored in s3 (The configmap yaml may have to be changed accordingly according to the env vars the 4.0 restore scripts expect)

**References**
- [Restoring a backup](https://neo4j.com/docs/operations-manual/3.5/backup/restoring/)
- [How to Restore Neo4j Backups on Kubernetes](https://medium.com/google-cloud/how-to-restore-neo4j-backups-on-kubernetes-and-gke-6841aa1e3961)


## Building the backup image
```
▶ docker build -t custom-neo4j-db-restore .


▶ docker tag custom-neo4j-db-restore us.icr.io/<your_namespace>/custom-neo4j-db-restore
```

Push image to IBM CR
```
▶ docker push us.icr.io/<your_namespace>/custom-neo4j-db-restore
```

## Running on kube/openshift cluster

- Change configmap values from `restore-configmap.yaml`
    ```
    ▶ oc create -f <restore-configmap.yaml>
    ```
    ```
    - BACKUP_SET_DIR: 
    - COS_ENDPOINT: https://<cos-bucket-endpoint>
    - PURGE_ON_COMPLETE: "true"
    - REMOTE_BACKUP_FILE: s3://<bucket-name>/<backup-file>
    - FORCE_OVERWRITE: "true"
    ```
    Setting `FORCE_OVERWRITE: "true"` wipes out the current database and overwrites it with the new backup
    ```
    # CAUTION: Read documentation before proceeding with this flag.
    - name: FORCE_OVERWRITE
      value: "true"
    ```

- Create a pod for testing restore
    ```
    ▶ oc create -f <restore-test-pod.yaml>
    ```
    (This pod may not help much. But with the while loop in the yaml, we can shell into the pod and manually execute and test restore script)

- The purpose of creating this restore image is to be used as an `initContainer` to restore from a backup for neo4j causal cluster deployments

  The structure of initContainer and how restore can be done is given in `cluster-deploy/deploy-with-restore-value.yaml`
  ```
    initContainers:
  # init containers to run before the Neo4j core pod e.g. to install
  # plugins or restore backups
  - name: neo4j-restore
    image: <restore-docker-image-location>
    # command: [ "/bin/bash", "-c", "--" ]
    # args: [ "while true; do sleep 30; done;" ]
    imagePullPolicy: Always
    envFrom:
    - configMapRef:
        name: restore-config
    env:
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          key: access_key_id
          name: cos-secret 
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          key: secret_access_key
          name: cos-secret 
    volumeMounts:
    - name: datadir
      mountPath: /data
  ```

  The `initContainer` restores the data from a backup onto all the cores before starting the neo4j server. The `/data` is mounted to the volume. So the data that restored here is available for the neo4j cores that start and form the cluster

### Cleanup
```
▶ oc delete configmap <configmap-name>

▶ oc delete pod <pod-name>

```