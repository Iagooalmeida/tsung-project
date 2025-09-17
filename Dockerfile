FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# Instala Tsung e dependências para geração de relatórios
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      tsung \
      gnuplot \
      perl \
      libtemplate-perl \
      libgd-perl \
      libio-socket-ssl-perl \
      libwww-perl \
      ca-certificates \
      curl \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /usr/lib/tsung/bin \
 && ln -sf /usr/lib/x86_64-linux-gnu/tsung/bin/tsung_stats.pl /usr/lib/tsung/bin/tsung_stats.pl

WORKDIR /work

EXPOSE 8091

# Comando padrão apenas informativo; o docker-compose define o comando de execução do teste
CMD ["tsung", "-v"]
