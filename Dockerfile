FROM legionio/legion:latest
LABEL maintainer="Matthew Iverson <matthewdiverson@gmail.com>"

RUN mkdir /etc/legionio
RUN apk update && apk add build-base tzdata postgresql-dev mysql-client mariadb-dev tzdata gcc git

COPY . ./
RUN gem install lex-scheduler legion-data --no-document --no-prerelease
CMD ruby --jit $(which legionio)
