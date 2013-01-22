#!/bin/bash
#
# Argument = -u user -p password -k key -s secret -b bucket
#
# To Do - Add logging of output.
# To Do - Abstract bucket region to options

set -e

usage()
{
cat << EOF
usage: $0 options

This script dumps the current mongo database, tars it, then sends it to an Amazon S3 bucket.

OPTIONS:
   -h      Show this message
   -u      Mongodb user
   -p      Mongodb password
   -k      AWS Access Key
   -s      AWS Secret Key
   -b      Amazon S3 bucket name
EOF
}

MONGODB_USER=
MONGODB_PASSWORD=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_BUCKET=

while getopts “ht:u:p:k:s:b:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    u)
      MONGODB_USER=$OPTARG
      ECHO "Mongodb User: $OPTARG"
      ;;
    p)
      MONGODB_PASSWORD=$OPTARG
      ECHO "Mongodb Password: $OPTARG"
      ;;
    k)
      AWS_ACCESS_KEY=$OPTARG
      ECHO "AWS Access Key: $OPTARG"
      ;;
    s)
      AWS_SECRET_KEY=$OPTARG
      ECHO "AWS Secret Key: $OPTARG"
      ;;
    b)
      S3_BUCKET=$OPTARG
      ECHO "Amazon S3 Bucket: $OPTARG"
      ;;
    ?)
      usage
      exit
    ;;
  esac
done

if [[ -z $MONGODB_USER ]] || [[ -z $MONGODB_PASSWORD ]] || [[ -z $AWS_ACCESS_KEY ]] || [[ -z $AWS_SECRET_KEY ]] || [[ -z $S3_BUCKET ]]
then
  usage
  exit 1
fi

# Store the current date in YYYY-mm-DD-HHMMSS
DATE=$(date -u "+%F-%H%M%S")
FILE_NAME="backup-$DATE"
ARCHIVE_NAME="$FILE_NAME.tar.gz"

# Lock the database
# Note there is a bug in mongo 2.2.0 where you must touch all the databases before you run mongodump
mongo -username $MONGODB_USER -password $MONGODB_PASSWORD admin --eval "var databaseNames = db.getMongo().getDBNames(); for (var i in databaseNames) { printjson(db.getSiblingDB(databaseNames[i]).getCollectionNames()) }; printjson(db.fsyncLock());"

# Dump the database
mongodump -username $MONGODB_USER -password $MONGODB_PASSWORD --out $FILE_NAME

# Unlock the database
mongo -username $MONGODB_USER -password $MONGODB_PASSWORD admin --eval "printjson(db.fsyncUnlock());"

# Tar Gzip the file
tar -zcvf ./backup/$ARCHIVE_NAME $FILE_NAME

# Remove the backup directory
rm -r $FILE_NAME

# Send the file to the backup drive or S3

HEADER_DATE=$(date -u "+%a, %d %b %Y %T %z")
CONTENT_MD5=$(openssl dgst -md5 -binary ./backup/$ARCHIVE_NAME | openssl enc -base64)
CONTENT_TYPE="application/x-download"
STRING_TO_SIGN="PUT\n$CONTENT_MD5\n$CONTENT_TYPE\n$HEADER_DATE\n/$S3_BUCKET/$ARCHIVE_NAME"
SIGNATURE=$(echo -e -n $STRING_TO_SIGN | openssl dgst -sha1 -binary -hmac $AWS_SECRET_KEY | openssl enc -base64)

curl -X PUT \
--header "Host: $S3_BUCKET.s3-ap-southeast-1.amazonaws.com" \
--header "Date: $HEADER_DATE" \
--header "content-type: $CONTENT_TYPE" \
--header "Content-MD5: $CONTENT_MD5" \
--header "Authorization: AWS $AWS_ACCESS_KEY:$SIGNATURE" \
--upload-file ./backup/$ARCHIVE_NAME \
https://$S3_BUCKET.s3-ap-southeast-1.amazonaws.com/$ARCHIVE_NAME