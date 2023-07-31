FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

# 更新源、配置基础
RUN apt update

RUN apt install -y apt-transport-https ca-certificates software-properties-common
RUN apt install -y g++ tzdata bash-completion

# 配置 bash 补全
RUN echo ". /etc/bash_completion" >> /root/.bashrc

# 配置时区
ENV TZ=Asia/Shanghai

RUN ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata

# 安装其它一些常用工具
RUN apt install -y wget curl net-tools netcat-traditional git-core vim 
RUN apt install -y sudo
RUN apt install -y openssh-server

# 配置非root用户
ARG USERNAME=ubuntu
ARG PASSWORD=ubuntu

RUN useradd -rm -d /home/${USERNAME} -s /bin/bash -g root -G sudo -u 1001 -p "$(openssl passwd -1 ${PASSWORD})" ${USERNAME}

# 切换到普通用户
USER ${USERNAME}

# 普通用户的基础环境等配置
ENV HOME=/home/${USERNAME}
ENV LANG='C.UTF-8' LC_ALL='C.UTF-8'

WORKDIR ${HOME}
RUN echo ". /etc/bash_completion" >> ${HOME}/.bashrc

ARG PROXY=""
ENV http_proxy=${PROXY}
ENV https_proxy=${PROXY}

# 安装 nodejs、golang、etc
ENV NODEVERSION=v14.17.6
ENV NODEDISTRO=linux-x64

RUN wget https://nodejs.org/dist/${NODEVERSION}/node-${NODEVERSION}-${NODEDISTRO}.tar.xz && \
    echo ${PASSWORD} | sudo -S mkdir -p /usr/local/lib/nodejs && \
    echo ${PASSWORD} | sudo -S tar -xJvf ./node-${NODEVERSION}-${NODEDISTRO}.tar.xz -C /usr/local/lib/nodejs && \
    rm -rf ./node-${NODEVERSION}-${NODEDISTRO}.tar.xz && \
    echo ${PASSWORD} | sudo -S ln -s /usr/local/lib/nodejs/node-${NODEVERSION}-${NODEDISTRO}/bin/node /usr/bin/node && \
    echo ${PASSWORD} | sudo -S ln -s /usr/local/lib/nodejs/node-${NODEVERSION}-${NODEDISTRO}/bin/npm /usr/bin/npm && \
    echo ${PASSWORD} | sudo -S ln -s /usr/local/lib/nodejs/node-${NODEVERSION}-${NODEDISTRO}/bin/npx /usr/bin/npx && \
    echo ${PASSWORD} | sudo -S chown -R $(whoami) $(npm config get prefix)/lib/node_modules && \
    echo ${PASSWORD} | sudo -S chown -R $(whoami) $(npm config get prefix)/bin && \
    echo ${PASSWORD} | sudo -S chown -R $(whoami) $(npm config get prefix)/share && \
    npm install -g nrm  && \
    npm install -g yarn  && \
    npm install -g yrm 

# \n放前面可以防止 docker 将'#'开头行认为是 dockerfile 中的注释行，造成其未被写入到文件中
RUN nodeConfig="\
    \n# config nodejs. \
    \nNODEVERSION=${NODEVERSION} \
    \nNODEDISTRO=${NODEDISTRO} \
    \nexport PATH=/usr/local/lib/nodejs/node-\$NODEVERSION-\$NODEDISTRO/bin:\$PATH \
    " && \
    echo $nodeConfig >> ${HOME}/.bashrc && \
    echo ${PASSWORD} | sudo -S /bin/bash -c "echo -e '${nodeConfig}' >> /etc/profile" && \
    /bin/bash -ic " \
    source ${HOME}/.bashrc; \
    "

RUN wget https://go.dev/dl/go1.20.6.linux-amd64.tar.gz && \
    echo ${PASSWORD} | sudo -S tar -C /usr/local/lib -zxvf  go1.20.7.linux-amd64.tar.gz && \
    rm -rf go1.20.7.linux-amd64.tar.gz

RUN goConfig="\
    \n# config golang. \
    \nexport GOROOT=/usr/local/lib/go \
    \nexport GOPATH=/home/ubuntu/go \
    \nexport PATH=\$PATH:\$GOPATH/bin:\$GOROOT/bin \
    " && \
    echo $goConfig >> ${HOME}/.bashrc && \
    # 多个命令使用 sudo 权限执行的话，可以以这样的形式：sh -c "xxx"，否则的话, >> 不是 sudo 权限，会报 permission 错误
    echo ${PASSWORD} | sudo -S /bin/bash -c "echo -e '${goConfig}' >> /etc/profile" && \
    /bin/bash -ic " \
    source ${HOME}/.bashrc; \
    go install github.com/cweill/gotests/gotests@latest; \
    go install github.com/fatih/gomodifytags@latest; \
    go install github.com/josharian/impl@latest; \
    go install github.com/haya14busa/goplay/cmd/goplay@latest; \
    go install github.com/go-delve/delve/cmd/dlv@latest; \
    go install honnef.co/go/tools/cmd/staticcheck@v0.2.2; \
    go install golang.org/x/tools/gopls@latest \
    "

RUN echo ${PASSWORD} | sudo -S curl -L https://dl.k8s.io/release/v1.21.0/bin/linux/amd64/kubectl -o /usr/bin/kubectl && \
    echo ${PASSWORD} | sudo -S chmod +x /usr/bin/kubectl 

# install vscode server https://stackoverflow.com/questions/56671520/how-can-i-install-vscode-server-in-linux-offline
ENV VSCODESERVERVERSION c3511e6c69bb39013c4a4b7b9566ec1ca73fc4d5
RUN wget https://update.code.visualstudio.com/commit:${VSCODESERVERVERSION}/server-linux-x64/stable -O vscode-server-linux-x64.tar.gz && \
    mkdir -p ${HOME}/.vscode-server/bin/${VSCODESERVERVERSION} && \
    tar zxvf vscode-server-linux-x64.tar.gz -C ${HOME}/.vscode-server/bin/${VSCODESERVERVERSION} --strip 1 && \
    touch ~/.vscode-server/bin/${VSCODESERVERVERSION}/0 && \
    rm -rf vscode-server-linux-x64.tar.gz

ENV http_proxy=""
ENV https_proxy=""

# 工作目录
ENV WORKDIR ${HOME}
WORKDIR ${WORKDIR}

# COPY 的都是root权限, 这统一修改家目录下的文件权限
RUN echo ${PASSWORD} | sudo -S chown -R $(id -u):$(id -g) ${WORKDIR} /home /var/

EXPOSE 22
CMD ["/bin/bash"]
