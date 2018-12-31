FROM dm848/cs-jolie-postgresql:v1.3.0

WORKDIR /service
COPY . /service

# add ContainerPilot configuration
RUN mv service.json5 /etc/containerpilot.json5
ENV CONTAINERPILOT=/etc/containerpilot.json5

# expose http port
EXPOSE 8888:8888
CMD ["/bin/containerpilot"]
