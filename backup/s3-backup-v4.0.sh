#!/bin/bash

if [ -z $NEO4J_ADDR ] ; then
    echo "You must specify a NEO4J_ADDR env var"
    exit 1
fi

if [ -z $DATABASE ] ; then
    echo "You must specify a DATABASE env var"
    exit 1
fi

if [ -z $BUCKET ]; then
    echo "You must specify a BUCKET name to form the path like s3://my-backups"
    exit 1
fi



if [ -z $HEAP_SIZE ] ; then
    HEAP_SIZE=2G
fi

if [ -z $PAGE_CACHE ]; then
    PAGE_CACHE=4G
fi

if [ -z $COS_ENDPOINT ]; then
    COS_ENDPOINT=https://s3.us-south.cloud-object-storage.appdomain.cloud
fi

if [ -z $BACKUP_PREFIX ]; then
    echo "BACKUP_PREFIX not specified"
    BACKUP_SET="$DATABASE-$(date "+%Y-%m-%d-%H:%M:%S")"
else
    BACKUP_SET="$BACKUP_PREFIX-$DATABASE-$(date "+%Y-%m-%d-%H:%M:%S")"
fi

# echo "Activating google credentials before beginning"
# gcloud auth activate-service-account --key-file "$GOOGLE_APPLICATION_CREDENTIALS"

# if [ $? -ne 0 ] ; then
#     echo "Credentials failed; no way to copy to google."
#     echo "Ensure GOOGLE_APPLICATION_CREDENTIALS is appropriately set."
# fi

#Helping functions
benchmark_and_execute() {
echo "\n[START] - $1"
date1=$(date +"%s")
eval $2
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne 0 ]; then 
    echo "$1 failed; will not continue"
    echo "Exit Code: $EXIT_CODE"
    exit $BACKUP_EXIT_CODE
fi
date2=$(date +"%s")
echo "[END] - $1"
diff=$(($date2-$date1))
echo "[BENCHMARK] - $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed.\n"
}  

# Configure heap size for the backup
export HEAP_SIZE=$HEAP_SIZE

echo "=============== Neo4j Backup ==============================="
echo "Beginning backup from $NEO4J_ADDR to /data/$DATABASE and tarring to /data/$BACKUP_SET"
echo "Using heap size $HEAP_SIZE and page cache $PAGE_CACHE"
echo "To IBM COS bucket $BUCKET at endpoint $COS_ENDPOINT"
echo "============================================================"

cmd="neo4j-admin backup \
    --from="$NEO4J_ADDR" \
    --backup-dir=/data \
    --database="$DATABASE" \
    --pagecache=$PAGE_CACHE"

benchmark_and_execute "NEO4J BACKUP" "$cmd"

echo "Backup size:"
du -hs "/data/$DATABASE"

echo "Tarring -> /data/$BACKUP_SET.tar"
tar -cvf "/data/$BACKUP_SET.tar" "/data/$DATABASE" --remove-files

echo "Zipping -> /data/$BACKUP_SET.tar.gz"
gzip -9 "/data/$BACKUP_SET.tar"

echo "Zipped backup size:"
du -hs "/data/$BACKUP_SET.tar.gz"

echo "Pushing /data/$BACKUP_SET.tar.gz -> $BUCKET"

cmd="aws --endpoint-url=$COS_ENDPOINT  s3 cp /data/$BACKUP_SET.tar.gz $BUCKET"
benchmark_and_execute "UPLOAD COMPRESSED FILE TO IBM COS" "$cmd"

exit $?
