ARG EE_BASE_IMAGE=docker.io/ashish1981/ansible-runner:latest
ARG EE_BUILDER_IMAGE=docker.io/ashish1981/ansible-builder:latest

FROM $EE_BASE_IMAGE as galaxy
ARG ANSIBLE_GALAXY_CLI_COLLECTION_OPTS=
USER root

ADD _build /build
WORKDIR /build

RUN ansible-galaxy role install -r requirements.yml --roles-path /usr/share/ansible/roles
RUN ansible-galaxy collection install $ANSIBLE_GALAXY_CLI_COLLECTION_OPTS -r requirements.yml --collections-path /usr/share/ansible/collections

FROM $EE_BUILDER_IMAGE as builder

COPY --from=galaxy /usr/share/ansible /usr/share/ansible
RUN dnf install -y --allowerasing libcurl libcurl-devel openssl-devel libxml2 libxml2-devel libxslt libxslt-devel
ADD _build/bindep.txt bindep.txt
RUN ansible-builder introspect --sanitize --user-bindep=bindep.txt --write-bindep=/tmp/src/bindep.txt --write-pip=/tmp/src/requirements.txt
RUN assemble

FROM $EE_BASE_IMAGE
USER root

COPY --from=galaxy /usr/share/ansible /usr/share/ansible

COPY --from=builder /output/ /output/
RUN /output/install-from-bindep && rm -rf /output/wheels
#RUN alternatives --set python /usr/bin/python3
COPY --from=docker.io/ashish1981/receptor /usr/bin/receptor /usr/bin/receptor
RUN mkdir -p /var/run/receptor
ADD run.sh /run.sh
CMD /run.sh
USER 1000
RUN git lfs install
