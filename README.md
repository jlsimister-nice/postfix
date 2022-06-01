# postfix-email-sink

This is project implements as a docker container a postfix email sink suitable for testing.
It supports a configurable hostname, proper shutdown handling, and TLS/STARTTLS security (including a client certificate).
The server logs all mail transferred successfully. **This server does not deliver or relay email.**

## Notes

This project was originally forked from [cloudposse/postfix](https://github.com/cloudposse/postfix) and updated to Ubuntu 20.04 LTS with Postfix >= 3.4.

By default, connected rfc1918 networks are detected and allowed. Local networks 
(127.0.0.1, ::1) are also allowed.

You can optionally enable the Carrier Grade NAT, RFC6598 (100.64.0.0/10).  
RFC1918 is still the default.  RFC6598 does not include the RFC1918 subnets, because
CGN is not meant to be used at the same time as private subnets.  If you really want 
both, you'll need to override the entrypoint to include both arguments.

## Syslog

Rsyslog is started automatically and sends logs to stdout

## Suggested Volumes

  * `/var/spool/postfix` is the spool directory. Its also where postfix chroots to by default.
  * `/etc/postfix` is the configuation directory
  
## Configuration

You can customize the image behavior using environmental variables or entrypoint
arguments.


| Enviromental Variable(s)                                | Entrypoint Option                                                                                      | Description                                                                              |
|---------------------------------------------------------|--------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| (use --hostname)                                        | --mail-name                                                                                            | Mail name to use (appears in mail headers). Defaults to hostname                         |
| RELAYHOST="[relay hostname]                             | --relayhost []                                                                                         | The host to relay mail to.                                                               |
| TRUST="local" or TRUST_LOCAL="0"                        | --trust-local                                                                                          | Trust addresses on the lo interface. Enabled by default                                  |
| TRUST="connected-rfc1918" or TRUST_CONNECTED_RFC="1"    | --trust-connected-rfc1918                                                                              | Trust all locally connected rfc1918 subnets. Enabled by default                          |
| TRUST="connected" or TRUST_CONNECTED="1"                | --trust-connected                                                                                      | Trust all addresses connected (excluding IPv6 local-link addresses). Disabled by default |
| TRUST="rfc1918" or TRUST_RFC1918="1"                    | --trust-rfc1918                                                                                        | Trust all rfc1918 address. Disabled by default                                           |
| TRUST="rfc6598" or TRUST_RFC6598="1"                    | --trust-rfc6598                                                                                        | Trust rfc6598 address.   This doesn't include RFC1918.  Disabled by default              |
| TRUST_LLA="1"                                           | --trust-lla                                                                                            | Trust the fe80::/64 IPv6 subnet. Disabled by default                                     |
| TRUST_SUBNETS="[space separated list of subnets]"       | --trust-subnet []                                                                                      | Trust the specified subnet (IPv4 and IPv6 supported). Disabled by default                |
| TRUST_INTERFACES="[space separated list of interfaces]" | --trust-interface []                                                                                   | Trust all network address on the interface (excluding IPv6 LLA). Disabled by default     |
|                                                         | --skip-trust-*                                                                                         | `local`, `connected-rfc1918`, `connected`, `rfc1918`, or `lla` to skip trusting it.      |
|                                                         | --skip-all                                                                                             | Disable/reset all trusts. Disabled by default                                            |


# Development

## Units tests

Regexp unit tests can be executed by running

`cd ./rootfs/`

`./test_ip_regexps`

Any output should be fixed.
