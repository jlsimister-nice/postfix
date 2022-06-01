# Inspired by: 
#    http://uname.pingveno.net/blog/index.php/post/2014/02/01/Configure-Postfix-as-STMP-standalone-single-domain-server-using-Unix-users-and-PAM-on-Debian
#
# Test with:  
#   testsaslauthd -u postmaster -p password -f /var/spool/postfix/var/run/saslauthd/mux
#   perl -MMIME::Base64 -e 'print encode_base64("\000postmaster\000password")'  
#   openssl s_client -starttls smtp -crlf -connect localhost:587
#   AUTH PLAIN AHBvc3RtYXN0ZXIAcGFzc3dvcmQ=

FROM ubuntu:20.04
MAINTAINER James Simister <james.simister@nice.com>

ARG HOSTNAME=email.sink
ARG SSL_DIR=/etc/ssl
ARG SSL_PRIV_DIR=/etc/ssl/private
ARG TESTCLIENT_USER=testclient
ARG TESTCLIENT_PASS=testclient

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true
ENV POSTMASTER_USER postmaster
ENV POSTMASTER_PASS password
ENV RELAY_AUTH_ENABLED true
ENV RELAY_AUTH_DOMAIN $HOSTNAME
ENV RELAY_AUTH_USER $TESTCLIENT_USER
ENV RELAY_AUTH_PASS $TESTCLIENT_PASS

ENTRYPOINT ["/start"]
# SMTP+STARTTLS
EXPOSE 25
# SMTP+TLS+SASLAUTH
EXPOSE 465
# SMTP+STARTTLS+SASLAUTH
EXPOSE 587
# SMTP+TLS+CLIENTCERT
EXPOSE 25465
# SMTP+STARTTLS+CLIENTCERT
EXPOSE 25587
# SMTP
EXPOSE 25025

RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup && \
    apt-get update && \
    echo "postfix postfix/mailname string $HOSTNAME" | debconf-set-selections && \
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections && \
    echo "tzdata tzdata/Areas select Etc" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections && \
    apt-get --no-install-recommends -y install rsyslog iproute2 postfix sipcalc sasl2-bin libsasl2-modules && \
    postconf -X 'smtpd_tls_cert_file' && \
    postconf -X 'smtpd_tls_key_file' && \
    postconf -e 'compatibility_level = 3' && \
    postconf -e 'smtpd_sasl_auth_enable = yes' && \
    postconf -e 'smtpd_sasl_path = smtpd' && \
    postconf -e 'smtpd_sasl_local_domain =' && \
    postconf -e 'smtpd_sasl_authenticated_header = yes' && \
    postconf -e 'smtpd_sasl_tls_security_options = noanonymous' && \
    postconf -e 'smtpd_tls_auth_only = yes' && \
    postconf -e 'smtpd_tls_ciphers = medium' && \
    postconf -e 'smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1' && \
    postconf -e "smtpd_tls_chain_files = $SSL_PRIV_DIR/server.key, $SSL_DIR/server.crt" && \
    postconf -e 'mua_client_restrictions = permit_sasl_authenticated, reject' && \
    postconf -e 'mua_helo_restrictions = permit_sasl_authenticated, reject' && \
    postconf -e 'mua_sender_restrictions = reject_non_fqdn_sender, permit_sasl_authenticated, reject' && \
    postconf -e 'muacc_client_restrictions = permit' && \
    postconf -e 'muacc_helo_restrictions = permit' && \
    postconf -e 'muacc_sender_restrictions = reject_non_fqdn_sender, permit' && \
    postconf -e 'smtpd_helo_required = yes' && \
    postconf -e 'smtpd_client_restrictions = permit' && \
    postconf -e 'smtpd_helo_restrictions = reject_invalid_helo_hostname, reject_non_fqdn_hostname, permit' && \
    postconf -e 'smtpd_recipient_restrictions = reject_unauth_pipelining, reject_non_fqdn_recipient, permit' && \
    postconf -e 'smtpd_sender_restrictions = reject_non_fqdn_sender, permit' && \
    postconf -e 'smtpd_data_restrictions = reject_unauth_pipelining, reject_multi_recipient_bounce' && \
    postconf -e 'message_size_limit = 41943040' && \
    postconf -e 'local_recipient_maps =' && \
    postconf -e 'default_transport = local' && \
    postconf -e 'default_destination_recipient_limit = 1' && \
    postconf -e 'local_destination_recipient_limit = 1' && \
    rm /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/private/ssl-cert-snakeoil.key && \
    find /etc/ssl/certs -type l -xtype l -delete && \
    apt-get clean && \
    rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup && \
    find /var/lib/apt/lists -mindepth 1 -delete -print && \
    find /tmp /var/tmp -mindepth 2 -delete -print && \
    rm -f /etc/rsyslog.d/50-default.conf  && \
    sed -e 's/\(^module.*imklog.*\)/#\1/g' -i /etc/rsyslog.conf && \
    adduser postfix sasl && \
    adduser --quiet --disabled-password -shell /bin/bash --home /home/$POSTMASTER_USER --gecos "Postmaster" $POSTMASTER_USER && \
    echo "$POSTMASTER_USER:$POSTMASTER_PASS" | chpasswd
    

ADD rootfs /

# Generate root CA certificate and key
RUN openssl req -x509 -newkey rsa:8192 -nodes -keyout $SSL_PRIV_DIR/testca.key -subj "/C=US/CN=testca/O=testca" -sha256 -days 3654 -out $SSL_DIR/testca.pem

# Generate server certificate and key
RUN openssl req -newkey rsa:4096 -nodes -keyout $SSL_PRIV_DIR/server.key -subj "/C=US/CN=$HOSTNAME" -addext "subjectAltName = DNS:$HOSTNAME" -out $SSL_DIR/server.req && \
    openssl x509 -req -in $SSL_DIR/server.req -CA $SSL_DIR/testca.pem -CAkey $SSL_PRIV_DIR/testca.key -set_serial 101 -days 3653 -outform PEM -out $SSL_DIR/server.crt

# Generate client certificate and key (including PKCS#12 format version)
RUN openssl req -newkey rsa:4096 -nodes -keyout $SSL_PRIV_DIR/$TESTCLIENT_USER.key -subj "/C=US/CN=$TESTCLIENT_USER" -out $SSL_DIR/$TESTCLIENT_USER.req && \
    openssl x509 -req -in $SSL_DIR/$TESTCLIENT_USER.req -CA $SSL_DIR/testca.pem -CAkey $SSL_PRIV_DIR/testca.key -set_serial 101 -extensions client -days 3653 -outform PEM -out $SSL_DIR/$TESTCLIENT_USER.crt && \
    openssl pkcs12 -export -inkey $SSL_PRIV_DIR/$TESTCLIENT_USER.key -in $SSL_DIR/$TESTCLIENT_USER.crt -out $SSL_DIR/$TESTCLIENT_USER.p12 -passout pass:$TESTCLIENT_PASS
