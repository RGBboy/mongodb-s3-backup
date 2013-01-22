# Mongodb to Amazon s3 Backup Script

## Requirements

* Running mongod process
* mongodump
* mongo
* openssl
* tar
* rm
* curl

## Usage

`bash backup.sh -u MONGODB_USER -p MONGODB_PASSWORD -k AWS_ACCESS_KEY -s AWS_SECRET_KEY -b S3_BUCKET`

