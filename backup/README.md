# Creating neo4j backups 

The docker image is created for performing neo4j database backups. The entrypoint script `s3-backup-v3.5.sh` runs a backup command on the neo4j deployment (address supplied through env vars or configmap (if running on kube)); compresses the backup directory; and stores the file in COS bucket (cos bucket details supplied)

```
├── Dockerfile
├── README.md
├── backup-configmap.yaml
├── backup-cronjob.yaml
├── backup-pod.yaml
├── backup-vars.env
├── cos-secret.yaml
├── gcs-backup-v3.5.sh
├── s3-backup-v3.5.sh
└── s3-backup-v4.0.sh
```
- `gcs-backup-v3.5.sh` - script to create and store backup in google cloud storage (used as a reference to customize scripts for S3/IBM COS)
- `s3-backup-v3.5.sh` - scripts to create backup of neo4j-3.5 and store it in s3 (This is the one that is used as entrypoint script because the neo4j cluster we deployed is 3.5)
- `s3-backup-v4.0.sh` - script to create backup of neo4j-4.0 and store it in s3 (The configmap yaml have to changed accordingly according to the env vars the 4.0 backup scripts expect)

**References**
- [Performing backup](https://neo4j.com/docs/operations-manual/3.5/backup/performing/#backup-performing-full)
- [How to backup Neo4j Running in Kubernetes](https://medium.com/neo4j/how-to-backup-neo4j-running-in-kubernetes-3697761f229a)


## Building the backup image 
```
▶ docker build -t custom-neo4j-db-backup .


▶ docker tag custom-neo4j-db-backup us.icr.io/<your_namespace>/custom-neo4j-db-backup
```
To test locally using docker,

```
▶ docker run -it --env-file=backup-vars.env custom-neo4j-db-backup
```
Push image to IBM CR
```
▶ docker push us.icr.io/<your_namespace>/custom-neo4j-db-backup
```

## Running on kube/openshift cluster
- Create secret if it does not already exists in the project
  ```
  ▶ oc create -f <cos-secret.yaml>
  ```
- Change configmap values from `backup-configmap.yaml`
    ```
    ▶ oc create -f <backup-configmap.yaml>
    ```
    ```
    - NEO4J_ADDR - The neo4j pod internal DNS 
    Format: <pod-name>.<subdomain>.<namespace>.svc.cluster.local:<backup-port>
    The hostname and subdomain can be found in the neo4j core pod's yaml
    Eg: `NEO4J_ADDR: <helm-release-name>-neo4j-core-0.<helm-release-name>-neo4j.<project-name>.svc.cluster.local:6362`
    - BACKUP_NAME - Name for the backup file that will be stored in COS bucket (will be suffixed with file creation timestamp)
    - BUCKET - S3 Uri for the bucket
    - COS_ENDPOINT - Endpoint URL for COS bucket
    Eg: `https://s3.us-south.cloud-object-storage.appdomain.cloud`
    Format: `s3://<bucket-name>
    - HEAP_SIZE and PAGE_CACHE - BAckup options. For more info, [NEO4j backups](https://neo4j.com/docs/operations-manual/3.5/backup/performing/#backup-performing-commands)
   ```
   
NOTE: 
Deployed neo4j config should have backup enabled and backup port 6362 open

- Create a pod for running/testing backup once 
    ```
    ▶ oc create -f <backup-pod.yaml>
    ```
- Create a cronjob to schedule backup job periodically as specified in the  `backup-cronjob.yaml`
  ```
  ▶ oc create -f <backup-cronjob.yaml>
  ```

### Cleanup
```
▶ oc delete configmap <configmap-name>

▶ oc delete pod <pod-name>

▶ oc delete cronjob <cronjob-name>
```