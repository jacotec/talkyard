#!/bin/bash

# Replace variable placeholders, like in 'limit_rate_after ${ED_NGX_LIMIT_RATE_AFTER}',
# with OS environment variable values.
# Don't forget to add default values in the Dockerfile. [0KW2UY3]
# RENAME from ED_* to TY_*  [ty_v1]

vars='
  \${TY_NGX_ERROR_LOG}
  \${TY_NGX_ACCESS_LOG}
  \${ED_NGX_LIMIT_CONN_PER_IP}
  \${ED_NGX_LIMIT_CONN_PER_SERVER}
  \${ED_NGX_LIMIT_REQ_PER_IP}
  \${ED_NGX_LIMIT_REQ_PER_IP_BURST}
  \${ED_NGX_LIMIT_REQ_PER_SERVER}
  \${ED_NGX_LIMIT_REQ_PER_SERVER_BURST}
  \${TY_NGX_LIMIT_REQ_BODY_SIZE}
  \${ED_NGX_LIMIT_RATE}
  \${ED_NGX_LIMIT_RATE_AFTER}
  \${TY_MAX_AGE_YEAR}
  \${TY_MAX_AGE_MONTH}
  \${TY_MAX_AGE_WEEK}
  \${TY_MAX_AGE_DAY}'


# Or use instead: https://github.com/a8m/envsubst
# so can place default values in the placeholders instead, not
# everything here.

# https://stackoverflow.com/questions/22541333/have-nginx-access-log-and-error-log-log-to-stdout-and-stderr-of-master-process
# To log errors to stdout, log level 'notice':
#   TY_NGX_ERROR_LOG="/dev/stdout notice"
#
# To log requests to stdout, and buffer messages:
#   TY_NGX_ACCESS_LOG="/dev/stdout main buffer=64K flush=5m"
#
TY_NGX_ERROR_LOG="${TY_NGX_ERROR_LOG:-/var/log/nginx/error.log notice}"  \
TY_NGX_ACCESS_LOG="${TY_NGX_ACCESS_LOG:-/var/log/nginx/access.log tyalogfmt}"  \
  \
  envsubst "$vars" < /etc/nginx/nginx.conf.template           > /etc/nginx/nginx.conf

envsubst "$vars" < /etc/nginx/http-limits.conf.template       > /etc/nginx/http-limits.conf
envsubst "$vars" < /etc/nginx/server-limits.conf.template     > /etc/nginx/server-limits.conf
envsubst "$vars" < /etc/nginx/server-locations.conf.template  > /etc/nginx/server-locations.conf

# Old, can remove? See comments in Dockerfile.  [ty_v1]
envsubst "$vars" < /etc/nginx/vhost.conf.template  > /etc/nginx/vhost.conf
envsubst "$vars" < /etc/nginx/server.conf.template > /etc/nginx/server.conf


# Generate a LetsEncrypt account key; otherwise LetsEncrypt might rate limit
# this server a bit much.  Used in nginx.conf (search for 'account_key_path').
account_key_path='/etc/nginx/acme-account.key'

if [ ! -f $account_key_path ]; then
  echo
  echo "Generating a LetsEncrypt account key,"
  echo "  storing in: $account_key_path ..."
  echo
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096  \
      -out  $account_key_path
fi

# Nginx won't start without a cert if TLS enabled, so generate a self signed
# cert. It'll get used only temporarily, until we have a LetsEncrypt cert.
fallback_cert_path='/etc/nginx/https-cert-self-signed-fallback'
fallback_cert_path_key="$fallback_cert_path.key"
fallback_cert_path_pem="$fallback_cert_path.pem"

if [ ! -f $fallback_cert_path_pem ]; then
  echo
  echo "Generating a fallback self signed cert,"
  echo "  storing in: $fallback_cert_path_key"
  echo "         and: $fallback_cert_path_pem ..."
  echo
  # -subj makes this non-interactive.
  # -days maybe doesn't matter — is self signed anyway.
  openssl req -newkey rsa:4096 -nodes -x509 -days 365 \
      -subj '/C=AQ/ST=Penguin Plains/L=Penguin Palace/O=Aviation Research/CN=temp-cert.example.com' \
      -keyout $fallback_cert_path_key \
      -out $fallback_cert_path_pem
fi
