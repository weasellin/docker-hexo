FROM node:13.1.0-alpine

LABEL maintainer="Ansel Lin<weasellin@gmail.com>"

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh

RUN npm install hexo-cli@3.1.0 -g

RUN hexo init blog && \
    cd blog && \
    npm install && \
    npm install --save hexo-deployer-git && \
    git clone https://github.com/weasellin/hexo-theme-jane.git themes/jane

COPY _config.yml /blog/_config.yml

RUN cd blog && hexo clean

WORKDIR /blog

ENTRYPOINT ["hexo", "server"]
