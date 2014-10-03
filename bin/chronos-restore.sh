#!/bin/bash 
#
# depends on requests package
# pip install requests

# and : https://github.com/jeid64/chronos_backup.git
# install -p $ATTACH_DIR/response.py -d /var/chronos/bin

function log()
{ 
    echo $@
    logger -t "Chronos-Restore" "$@"
}

if [ ! -x /usr/local/bin/aws ]; then
  log "ERROR aws tool not found in /usr/local/bin/aws...exiting"
  exit 1
fi
source ~root/.aws/aws_env.sh

while [[ -n "$1" ]];
do
  case $1 in 
    -f|--file)
      file=$2;
      shift;shift;;
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
cd $backup_dir

backup_bucket="s3://pg-chronos-backup-$environment"
if [[ -z "$file" ]]; then 
  file=$( /usr/local/bin/aws --output text s3 ls  $backup_bucket | sort | tail -1 | awk ' { print $4 }' )
  log "WARN No file specified; restoring from lastest backup file: $file"
fi

response=$( /usr/local/bin/aws --output text s3 cp "$backup_bucket/$file" . )
rv=$?
if [[ "$rv" != "0" ]]; then
  log "ERROR unable to copy file $backup_bucket/$file to directory $backup_dir : $response"
  exit $rv
fi

did_backup="false"
for chronos_url in $chronos_urls
do
  python /var/chronos/bin/response.py -u $chronos_url -r "$backup_dir/$file"
  rv=$?
  if [[ "$rv" != "0" ]]; then
    log "WARN unable to get chronos job definitions backup from $chronos_url to $chronos_url"
  else
    did_backup="true"
    break
  fi
done
if [[ "$did_backup" == "false" ]]
then
  log "ERROR unable to restore chronos job definitions backup from $backup_dir/$file"
  exit $rv
else
  log "INFO Restored chronos job definitions from file $backup_bucket/$file : OK"
  rm -rf $backup_dir
fi
