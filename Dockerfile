FROM python:3.9-alpine

RUN pip3 --no-cache-dir install --upgrade awscli

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
