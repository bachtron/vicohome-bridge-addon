ARG BUILD_FROM
FROM $BUILD_FROM

ENV LANG C.UTF-8

# Python + Go + certs (for HTTPS to Vicohome)
RUN apk add --no-cache python3 py3-pip go ca-certificates

WORKDIR /usr/src/app

# ---- Vicohome CLI (Go) ----
COPY vico-cli-main/ ./vico-cli-main/
WORKDIR /usr/src/app/vico-cli-main
RUN go build -o /usr/local/bin/vicohome .

# ---- HTTP bridge server ----
WORKDIR /usr/src/app
COPY server.py ./server.py
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
