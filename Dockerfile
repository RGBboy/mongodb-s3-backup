FROM buildpack-deps:jessie-curl

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927 \
  && echo "deb http://repo.mongodb.org/apt/debian wheezy/mongodb-org/3.2 main" | tee /etc/apt/sources.list.d/mongodb-org-3.2.list \
  && apt-get update \
  && apt-get install mongodb-org-tools

RUN apt-get update \
  && apt-get install -y python python-pip \
  && pip install awscli

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
ADD . /usr/src/app

ENTRYPOINT ["bash", "backup.sh"]
