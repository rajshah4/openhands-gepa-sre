FROM jenkins/jenkins:lts-jdk21

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git python3 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://download.docker.com/linux/static/stable/aarch64/docker-29.2.1.tgz -o /tmp/docker.tgz \
    && tar -xzf /tmp/docker.tgz -C /tmp \
    && install /tmp/docker/docker /usr/local/bin/docker \
    && rm -rf /tmp/docker /tmp/docker.tgz

COPY --from=ghcr.io/astral-sh/uv:0.8.15 /uv /uvx /usr/local/bin/

RUN jenkins-plugin-cli --plugins workflow-aggregator

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

RUN mkdir -p /var/jenkins_home/casc_configs /workspace
