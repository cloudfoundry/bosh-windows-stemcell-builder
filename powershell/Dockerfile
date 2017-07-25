FROM vmware/powerclicore:latest
MAINTAINER Mike Lloyd <mlloyd@pivotal.io>

ENV PSModuleLocation "/root/.local/share/powershell/Modules/"

COPY ./install-tools.ps1 /root

RUN /root/install-tools.ps1