FROM python:3.9-alpine

RUN pip3 --no-cache-dir install awscli==1.44.87

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
