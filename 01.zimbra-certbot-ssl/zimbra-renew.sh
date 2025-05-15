#!/bin/bash

#export DOMAIN=$(hostname -f)
DOMAIN="mail.technbd.net"


#certbot certonly --standalone -d mail.technbd.net --preferred-chain "ISRG Root X1" --agree-tos --register-unsafely-without-email

mkdir -p /opt/zimbra/ssl/letsencrypt

cp /etc/letsencrypt/live/$DOMAIN/* /opt/zimbra/ssl/letsencrypt

wget -O /tmp/ISRG-X1.pem https://letsencrypt.org/certs/isrgrootx1.pem.txt
cat /tmp/ISRG-X1.pem >> /opt/zimbra/ssl/letsencrypt/chain.pem

chown -R zimbra:zimbra /opt/zimbra/ssl/letsencrypt



## Verify certificates:
su - zimbra -c '/opt/zimbra/bin/zmcertmgr verifycrt comm /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/chain.pem'


## Backup current used zimbra certificates:
cp -a /opt/zimbra/ssl/zimbra /opt/zimbra/ssl/zimbra.$(date "+%F")


## Stop Zimbra services:
su - zimbra -c 'zmcontrol stop'


## Copy privkey key to Zimbra commercial key:
cp /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key

chown zimbra:zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key


## Deploy Let's Encrypt SSL certificates
su - zimbra -c '/opt/zimbra/bin/zmcertmgr deploycrt comm /opt/zimbra/ssl/letsencrypt/cert.pem /opt/zimbra/ssl/letsencrypt/chain.pem'


## Restart Zimbra services
su - zimbra -c "zmcontrol start"

