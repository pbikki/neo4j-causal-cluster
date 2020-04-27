FROM launcher.gcr.io/google/debian9
RUN apt-get update
RUN apt-get install -y bash curl wget gnupg apt-transport-https apt-utils lsb-release iputils-ping
RUN echo "deb http://httpredir.debian.org/debian stretch-backports main" | tee -a /etc/apt/sources.list.d/stretch-backports.list
RUN apt-get update
RUN wget -O - https://debian.neo4j.org/neotechnology.gpg.key | apt-key add -
# RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
# RUN echo 'deb https://debian.neo4j.org/repo stable/' | tee -a /etc/apt/sources.list.d/neo4j.list
RUN echo 'deb https://debian.neo4j.com stable 3.5' | tee /etc/apt/sources.list.d/neo4j.list
# RUN echo "deb http://packages.cloud.google.com/apt cloud-sdk-$(lsb_release -c -s) main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

RUN echo "neo4j-enterprise neo4j/question select I ACCEPT" | debconf-set-selections
RUN echo "neo4j-enterprise neo4j/license note" | debconf-set-selections

RUN apt-get update
RUN apt list -a neo4j
# RUN apt-get install -y neo4j-enterprise=1:3.4.11
RUN apt-get install -y neo4j-enterprise=1:3.5.17

# Install awscli
# Install groff - dependency for awscli
RUN apt-get install -y groff
RUN apt-get install -y python python-pip && pip install awscli  

# create directory to store backups
RUN mkdir /data
# add backup scripts
ADD gcs-backup-v3.5.sh /scripts/gcs-backup-v3.5.sh
ADD s3-backup-v4.0.sh /scripts/s3-backup-v4.0.sh
ADD s3-backup-v3.5.sh /scripts/s3-backup-v3.5.sh

# assign execute permissions on scripts folder
RUN chmod +x scripts/*


CMD ["/scripts/s3-backup-v3.5.sh"]