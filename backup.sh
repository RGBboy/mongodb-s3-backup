#!/bin/bash
#
# Argument = -u user -p password -k key -s secret -b bucket
#
# To Do - Add logging of output.
# To Do - Abstract bucket region to options

set -e

export PATH="$PATH:/usr/local/bin"

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
   -r      Amazon S3 region
   -b      Amazon S3 bucket name
   -d      Directory where to dump
   -m      Mongodb host (eg: localhost:27017)
EOF
}

MONGODB_USER=
MONGODB_PASSWORD=
MONGOD_HOST=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_REGION=
S3_BUCKET=
DUMP_DIR=

while getopts "ht:u:p:k:s:r:b:d:m:" OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    u)
      MONGODB_USER=$OPTARG
      ;;
    p)
      MONGODB_PASSWORD=$OPTARG
      ;;
    k)
      AWS_ACCESS_KEY=$OPTARG
      ;;
    s)
      AWS_SECRET_KEY=$OPTARG
      ;;
    r)
      S3_REGION=$OPTARG
      ;;
    b)
      S3_BUCKET=$OPTARG
      ;;
    d)
      DUMP_DIR=$OPTARG
      ;;
    m)
      MONGOD_HOST=$OPTARG
      ;;
    ?)
      usage
      exit
    ;;
  esac
done

if [[ -z $MONGODB_USER ]] || [[ -z $MONGODB_PASSWORD ]] || [[ -z $AWS_ACCESS_KEY ]] || [[ -z $AWS_SECRET_KEY ]] || [[ -z $S3_REGION ]] || [[ -z $S3_BUCKET ]] || [[ -z $DUMP_DIR ]] || [[ -z $MONGOD_HOST ]]
then
  usage
  exit 1
fi

# Store the current date in YYYY-mm-DD-HHMMSS
DATE=$(date -u "+%F-%H%M%S")
FILE_NAME="$MONGOD_HOST-backup-$DATE"
ARCHIVE_NAME="$FILE_NAME.tar.gz"

# Dump the database
echo "Dumping $MONGOD_HOST in $DUMP_DIR/backup/$FILE_NAME"
mongodump -h "$MONGOD_HOST" --username "$MONGODB_USER" --password "$MONGODB_PASSWORD" --out $DUMP_DIR/backup/$FILE_NAME > /dev/null

# Tar Gzip the file
echo "Compressing the dump"
tar -C $DUMP_DIR/backup/ -zcf $DUMP_DIR/backup/$ARCHIVE_NAME $FILE_NAME/

# Remove the backup directory
echo "Cleaning up"
rm -r $DUMP_DIR/backup/$FILE_NAME

# Send the file to the backup drive or S3
echo "Uploading archive to $S3_BUCKET"
HEADER_DATE=$(date -u "+%a, %d %b %Y %T %z")
CONTENT_MD5=$(openssl dgst -md5 -binary $DUMP_DIR/backup/$ARCHIVE_NAME | openssl enc -base64)
CONTENT_TYPE="application/x-download"
STRING_TO_SIGN="PUT\n$CONTENT_MD5\n$CONTENT_TYPE\n$HEADER_DATE\n/$S3_BUCKET/$ARCHIVE_NAME"
SIGNATURE=$(echo -e -n $STRING_TO_SIGN | openssl dgst -sha1 -binary -hmac $AWS_SECRET_KEY | openssl enc -base64)

curl -X PUT \
--header "Host: $S3_BUCKET.s3-$S3_REGION.amazonaws.com" \
--header "Date: $HEADER_DATE" \
--header "content-type: $CONTENT_TYPE" \
--header "Content-MD5: $CONTENT_MD5" \
--header "Authorization: AWS $AWS_ACCESS_KEY:$SIGNATURE" \
--upload-file $DUMP_DIR/backup/$ARCHIVE_NAME \
https://$S3_BUCKET.s3-$S3_REGION.amazonaws.com/$ARCHIVE_NAME

rm -r $DUMP_DIR/backup/$ARCHIVE_NAME

echo "Backup completed"