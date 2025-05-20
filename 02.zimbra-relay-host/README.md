## Relay Host in Zimbra:

SMTP relay in Zimbra allows your mail server to send outgoing emails through an external SMTP server (relay host), which is useful for improving deliverability, complying with ISP requirements, or routing emails through a specific service.


### Prerequisites: 

- Zimbra is already configured to send emails externally.
- Credentials (username and password) for the external SMTP relay service 
- The hostname and port of the relay server (e.g., smtp.gmail.com:587)



_Check if the required SASL packages are installed:_

```
rpm -q cyrus-sasl cyrus-sasl-plain


yum install cyrus-sasl-plain
```



### Set Relay Host:

Run the following command to set the relay host or outgoing server  (replace `smtp.relay.com` with your SMTP relay server and port (`587`) if needed):


_Syntax:_

```
zmprov ms `zmhostname` zimbraMtaRelayHost smtp.relay.com:587
```


_For `mail.technbd.net`:_

```
zmprov ms `zmhostname` zimbraMtaRelayHost mail.technbd.net:587
```



_Set Gmail as the SMTP Relay Host:_

```
zmprov ms `zmhostname` zimbraMtaRelayHost smtp.gmail.com:587
```



### User Create:

If your relay service provides `testuser@technbd.net` and `test123`, use:

```
zmprov ca testuser@technbd.net test123

zmprov ma testuser@technbd.net zimbraMailTransport smtp:mail.technbd.net:587
```


```
zmprov ga testuser@technbd.net | grep zimbraMailTransport

zimbraMailTransport: smtp:mail.technbd.net:587
```





#### Enable SMTP Authentication:

Create a SASL password map file if your relay requires authentication.


_Create a text file mapping which name/password:_

```
echo mail.technbd.net username:password > /opt/zimbra/conf/relay_password
```


Or,

```
vim /opt/zimbra/conf/relay_password


mail.technbd.net testuser@technbd.net:test123
```



_Add your Gmail credentials:_

```
vim /opt/zimbra/conf/relay_password


smtp.gmail.com your_email@gmail.com:app_password
```



```
chmod 600 /opt/zimbra/conf/relay_password

chown zimbra:zimbra /opt/zimbra/conf/relay_password
```


#### Generate Postfix SASL Password Map:

```
postmap /opt/zimbra/conf/relay_password
```


_To check that the lookup table is correct:_

```
postmap -q mail.technbd.net /opt/zimbra/conf/relay_password
```



#### Configure Postfix to Use Auth File:

To use `zmprov` to set SASL authentication:

```
zmprov ms `zmhostname` zimbraMtaSmtpSaslPasswordMaps lmdb:/opt/zimbra/conf/relay_password

zmprov ms `zmhostname` zimbraMtaSmtpSaslAuthEnable yes
zmprov ms `zmhostname` zimbraMtaSmtpCnameOverridesServername no

zmprov ms `zmhostname` zimbraMtaSmtpSaslSecurityOptions noanonymous
```


_Enable TLS (Optional but Recommended):_

```
zmprov ms `zmhostname` zimbraMtaSmtpTlsSecurityLevel may
```



_Verify `zimbraMtaSmtpSaslPasswordMaps` is set:_

```
zmprov gs `zmhostname` | grep zimbraMtaSmtpSaslPasswordMaps

zimbraMtaSmtpSaslPasswordMaps: lmdb:/opt/zimbra/conf/relay_password
```


_Restart the MTA:_

```
zmmtactl restart
```



### Test the Configuration:

_Check the Relay Server:_
- Look for lines like: `250-AUTH PLAIN LOGIN`

```
openssl s_client -connect mail.technbd.net:587 -starttls smtp
```




Send a test email to an external address (e.g., a Gmail account) and if you're running as the `zimbra` user, you can use `sendmail` directly, which comes with Zimbra:

```
su - zimbra

sendmail recipient@gmail.com
Subject: Test Mail
This is a test email from Zimbra.
.
```



```
yum install mailx
```


```
echo "This is a test email from Zimbra." | mail -s "Test Subject" recipient@gmail.com
```



_Check the mail logs for success or errors:_

- Look for successful delivery (e.g., status=sent).

```
tail -f /var/log/zimbra.log
```


### links:
- [Zimbra SMTP relay host](https://wiki.zimbra.com/wiki/Outgoing_SMTP_Authentication)


