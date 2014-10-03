#!/bin/bash 
#
# depends on requests package
# pip install requests

# and : https://github.com/jeid64/chronos_backup.git
# install -p $ATTACH_DIR/response.py -d /var/chronos/bin

function log()
{ 
    echo $@
    logger -t "Chronos-Backup" "$@"
}

if [ ! -x /usr/local/bin/aws ]; then
  log "ERROR aws tool not found in /usr/local/bin/aws...exiting"
  exit 1
fi
source ~root/.aws/aws_env.sh

while [[ -n "$1" ]];
do
  case $1 in 
    -e|--env*)
      environment=$2;
      shift;shift;;
    -h|--host*)
      chronos_urls=$2;
      shift;shift;;
    *)
      shift;;
esac

set -x

backup_dir="/var/tmp/chronos-backup-$$"
mkdir -p $backup_dir

got_backup="false"
for chronos_url in $chronos_urls
do
  python /var/chronos/bin/response.py -u $chronos_url -b "$backup_dir"
  rv=$?
  if [[ "$rv" != "0" ]]; then
    log "WARN unable to get chronos job definitions backup from $chronos_url"
  else
    got_backup="true"
    break
  fi
done
if [[ "$got_backup" == "false" ]]
then
  log "ERROR unable to get chronos job definitions backup from $chronos_url"
  exit $rv
else
  backup_bucket="s3://pg-chronos-backup-$environment"
  file=$( ls -1tr $backup_dir/*.json | tail -1 )
  response=$( /usr/local/bin/aws --output text s3 cp $file $backup_bucket )
  rv=$?
  if [[ "$rv" != "0" ]]; then
    log "ERROR unable to copy file $file to bucket $backup_bucket : $response"
    exit $rv
  fi
  log "INFO Backed up chronos job definitions file $file to bucket $backup_bucket : OK"
  rm -rf $backup_dir
fi
