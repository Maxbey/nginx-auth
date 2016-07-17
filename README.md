nginx-auth
==========

A demo of how to leverage [OpenResty](https://openresty.org) (a dynamic web platform based on NGINX and LuaJIT) and [JSON Web Tokens](https://jwt.io/introduction) to authenticate routes with JWT and Basic Authentication.


The idea is that in order to access any resource, one needs basic auth credentials, or can supply a JWT token. Each token encodes the following data:
```json
{
  "service": "my-service",
  "client": "name-of-client"
}
```

for sake of clarity, our example token would be:

```json
{
  "service": "foo",
  "client": "john.doe"
}
```

Once a client performs a request, the token is decrypted, and the following checks are made:
- The request sub-domain equals to the encoded service. In our example, if a request was made to `foo.example.com`, it would be authorized.

- The encoded client is validated against a [Redis](http://redis.io) cluster, to allow more granular token revocation. Redis holds all the registered clients for the specific service, and checks that the encoded client is still registered. [Adding a token](http://redis.io/commands/sadd) is as easy as `SADD <service> <client>`, and to [revoke a token](http://redis.io/commands/srem) one only needs to `SREM <service> <client>`.

### Getting Started

A demo docker-compose file has been created, that fires up Redis & nginx instances.
The demo contains a default user with the following user/password: `john.doe/secret`

open one terminal, and type:
```bash
$ docker network create nginx-auth
$ docker-compose nginx up
```

open another and use the `auth` tool to perform requests.

#### Setup

```bash
# we need to add foo.localhost & bar.localhost to /etc/hosts
# so tokens could be validated against to foo sub-domain
$ sudo bash -c 'echo "127.0.0.1 foo.localhost bar.localhost" >> /etc/hosts'
# install the nginx-auth tool into a temporary virtualenv
# this is an optional step
$ mktmpenv -n
$ pip install -r tools/requirements.txt
```


#### Basic authentication

```bash
$ curl http://foo.localhost/secure
<html>
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>openresty/1.9.15.1</center>
</body>
</html>

# now, lets authenticate...
$ curl -u john.doe:secret http://foo.localhost/secure
Hello! you have been authorized!
```

#### JWT

```bash
$ echo '{"service": "foo", "client": "12345" }'| python tools/auth.py http://foo.localhost/secure
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>openresty/1.9.15.1</center>
</body>
</html>

# Lets add this client, so we'll be able to authenticate...
$ echo '{"service": "foo", "client": "12345" }'| python tools/auth.py http://foo.localhost/secure add
Hello! you have been authorized!

# Lets check if the client can access a different service (bar)
# it shouldn't, because the token is only for the 'foo' sub-domain,
# and we're trying to access the 'bar' sub-domain.
$ echo '{"service": "foo", "client": "12345" }'| python tools/auth.py http://bar.localhost/secure
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>openresty/1.9.15.1</center>
</body>
</html>

# Lets remove the client and check if it can access the 'foo' sub-domain...
$ echo '{"service": "foo", "client": "12345" }'| python tools/auth.py http://foo.localhost/secure rem
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>openresty/1.9.15.1</center>
</body>
</html>
```

### Configuration

#### Basic Authentication

Use the following snippet to generate basic auth users:
```bash
$ cd /path/to/nginx-auth
$ echo -n '<username>:' >> nginx/conf/.htpasswd
$ openssl passwd -apr1 >> nginx/conf/.htpasswd
# Enter a password...
```

#### Environment Variables

| Environment Variables         | Type   | Description                              |
|:-----------------------------:|:------:|:-----------------------------------------|
| REDIS_HOST                    | string | The redis host. defaults to **redis**    |
| REDIS_PORT                    | int    | The redis port. defaults to **6379**     |
