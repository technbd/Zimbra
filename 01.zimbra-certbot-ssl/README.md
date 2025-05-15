## Certbot with Zimbra:

The default installation of **Zimbra generates self-signed SSL certificate** for Mails services – POP3/IMAP/SMTP over TLS and for HTTPS access to Zimbra console services. Let’s Encrypt is a free, automated, and open certificate authority brought to you by the nonprofit **Internet Security Research Group** (ISRG). 

To configure Certbot with Zimbra for automatic Let's Encrypt SSL certificate issuance and renewal, you'll need to follow a setup that bridges Certbot and Zimbra's custom certificate handling.


### Step-1: Issue Certificate:
If your Zimbra server is not running on port 80 (needed for HTTP-01 challenge), **stop Zimbra server** and requests the cert be chained to **ISRG Root X1** (Let’s Encrypt's root).



```
sudo su - zimbra -c "zmcontrol stop"
```


```
sudo su - zimbra -c 'source ~/bin/zmshutil; zmsetvars'
sudo su - zimbra -c 'zmhostname'
sudo su - zimbra -c 'hostname --fqdn'
```



_To run Certbot in `standalone` mode:_


```
certbot --version
```


```
certbot certonly --standalone -d mail.example.com

certbot certonly --standalone -d mail.example.com --preferred-chain "ISRG Root X1"


certbot certonly --standalone -d mail.example.com --preferred-chain "ISRG Root X1" --force-renewal

certbot certonly --standalone -d mail.example.com --preferred-chain "ISRG Root X1" --agree-tos --register-unsafely-without-email
```




_You’ll see a number of files:_

- `cert.pem`: The actual certificate file
- `chain.pem`: The chain file
- `fullchain.pem`: Concatenation of cert.pem + chain.pem
- `privkey.pem`: Private key


```
ll /etc/letsencrypt/live/mail.example.com/


```






### Step-2: Install Certificate into Zimbra:


Prepare the files:

```
mkdir -p /opt/zimbra/ssl/letsencrypt
```


```
cp /etc/letsencrypt/live/mail.example.com/* /opt/zimbra/ssl/letsencrypt
```


```
cd /opt/zimbra/ssl/letsencrypt

cp chain.pem zm_chain.pem
```



```
wget -O /tmp/ISRG-X1.pem https://letsencrypt.org/certs/isrgrootx1.pem.txt

//cat /tmp/ISRG-X1.pem >> /opt/zimbra/ssl/letsencrypt/zm_chain.pem

cat /tmp/ISRG-X1.pem >> /opt/zimbra/ssl/letsencrypt/chain.pem
```



```
chown -R zimbra:zimbra /opt/zimbra/ssl/letsencrypt
```




### Step-3: Verify:

```
su - zimbra
```


```
cd  /opt/zimbra/ssl/letsencrypt
```


```
/opt/zimbra/bin/zmcertmgr verifycrt comm privkey.pem cert.pem chain.pem
```


```
### Output:


```


_Backup current certificate files:_

```
sudo cp -a /opt/zimbra/ssl/zimbra /opt/zimbra/ssl/zimbra-$(date "+%Y.%m.%d-%H.%M")

or,

sudo cp -a /opt/zimbra/ssl/zimbra /opt/zimbra/ssl/zimbra-$(date "+%F")
```



You must name your **private key** file `commercial.key` and upload it to the following directory:` /opt/zimbra/ssl/zimbra/commercial`.

```
cp /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key

chown zimbra:zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key
```





### Step-4: Deploy:

```
su - zimbra
```


```
cd  /opt/zimbra/ssl/letsencrypt
```


```
/opt/zimbra/bin/zmcertmgr deploycrt comm cert.pem chain.pem
```



```
zmcontrol restart
```





---
---





### Automate Renewal & Deployment:


You **must first obtain the certificate** with the `--standalone` method before `certbot renew` can work automatically with it.

After the first successful issue with `--standalone`, `certbot renew` will automatically reuse the same method during renewal.


> [!NOTE]  
> Because `--standalone` runs a temporary web server, **Zimbra or any other service using port 80 must be stopped before renewal**.


_Run a renewal test:_

```
certbot renew --dry-run
```


_It should show:_

```

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/mail.example.com.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Renewing an existing certificate for mail.example.com
...
...


```







#### Option-1: Use Certbot's Renewal Hook Directly: 

_Create the directory if it doesn't exist:_

```
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
```


_Create script:_

```
vim /etc/letsencrypt/renewal-hooks/deploy/zimbra-renew.sh


#!/bin/bash

#export DOMAIN=$(hostname -f)
DOMAIN="mail.example.com"


#certbot certonly --standalone -d mail.example.com --preferred-chain "ISRG Root X1" --agree-tos --register-unsafely-without-email

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

```



```
chmod +x /etc/letsencrypt/renewal-hooks/deploy/zimbra-renew.sh
```



```
sudo crontab -e

15 3 * * * certbot renew --quiet --pre-hook "su - zimbra -c 'zmcontrol stop'" --post-hook "/etc/letsencrypt/renewal-hooks/deploy/zimbra-renew.sh"
```




#### Option 2: Use a Cron Job (Recommended for Simplicity)


```
cp /etc/letsencrypt/renewal-hooks/deploy/zimbra-renew.sh /usr/local/bin/zimbra-renew.sh
```


```
sudo crontab -e


## Run every day at 3:30 AM:
30 3 * * * certbot renew --quiet --deploy-hook "/usr/local/bin/zimbra-renew.sh"
```



Now, every time `certbot renew` runs, Zimbra will get the updated certificate automatically.




### Links:
- [Install SSL Cert on Zimbra](https://inguide.in/how-to-install-free-ssl-certificate-on-zimbra-mail-server/)
- [SSL on Zimbra](https://vkttech.com/how-to-install-free-ssl-certificates-on-zimbra-mail-server-ubuntu/)
- [Let’s Encrypt SSL on Zimbra](https://computingforgeeks.com/secure-zimbra-mail-server-with-letsencrypt-ssl-certificate/)



