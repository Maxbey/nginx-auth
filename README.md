nginx-auth
==========

A demo of how to leverage [OpenResty](https://openresty.org) (a dynamic web platform based on NGINX and LuaJIT), [JSON Web Tokens](https://jwt.io/introduction) and [OAuth2](http://oauth.net/2) to authenticate nginx routes.

The idea is that in order to access any resource, one needs either:
* Basic Authentication Credentials
* A JWT token.
* An OAuth2 provider.

### OAuth2

OAuth2 authentication uses [oauth2_proxy](https://github.com/bitly/oauth2_proxy).
specifically in this example, we use [GitHub](https://github.com) authentication.

### JWT

Each token encodes the following data:
```json
{
  "service": "my-service",
  "client": "name-of-client",
  "expires-at": "time-since-epoch"
}
```


for sake of clarity, our example token would be:

```json
{
  "service": "foo",
  "client": "john.doe",
}
```

Once a client performs a request, the token is decrypted, and the following checks are made:
- The request domain equals to the encoded `service` field. In our example, if a request was made to `foo.example.com`, it would be authorized. to authorize the root domain, than the service should be "\_".

- The encoded `client` field is validated against a [Redis](http://redis.io) cluster, to allow more granular token revocation. Redis holds all the registered clients for the specific service, and checks that the encoded client is still registered. [Adding a token](http://redis.io/commands/sadd) is as easy as `SADD <service> <client>`, and to [revoke a token](http://redis.io/commands/srem) one only needs to `SREM <service> <client>`.

- The encoded `expires-at` field is checked against the current time. the request wouldn't pass if the token has expired.

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

##### Domain

This example uses the `example.com` domain:
```bash
$ sudo bash -c 'echo "127.0.0.1 auth.example.com foo.example.com  bar.example.com example.com" >> /etc/hosts'`
```

##### OAuth2

1. Go through the steps to [setup GitHub OAuth2](https://github.com/bitly/oauth2_proxy#github-auth-provider) authentication.
2. Use the following `Authorization callback URL` - `http://auth.example.com/oauth2/callback`
3. update the `client_id` and `client_secret` values in `oath2_proxy/config/oauth2_proxy.cfg`

##### jwt-tool

1. install the nginx-auth tool into a temporary virtualenv:  `mktmpenv -n`
2. install the tool: `pip install -r tools/requirements.txt `

##### Basic authentication

Use the following snippet to generate basic auth users:
```bash
$ cd /path/to/nginx-auth
$ echo -n '<username>:' >> nginx/conf/.htpasswd
$ openssl passwd -apr1 >> nginx/conf/.htpasswd
# Enter a password...
```

#### Example usage

The root location (`/`) handles requests in the following manner:
```
if request has an 'Authorization' header that starts with `Basic`:
   authorize the request with basic authentication
elif request has an 'Authorization' header that starts with `Bearer`:
   authorize the request using its jwt token
else:
   authorize the request using OAuth2
```

##### Basic authentication

```bash
# curl while supplying an invalid user
$ curl -u invalid:user http://foo.example.com/secure
<html>
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>openresty/1.9.15.1</center>
</body>
</html>

# curl while supplying a valid user
$ curl -u john.doe:secret http://example.com/secure
Hello! you have been authorized!
```

#### JWT

```bash
# the tool adds the 'expires-at' field that expires 10 seconds after it was generated
$ echo '{"service": "foo", "client": "12345" }'| python tools/auth.py http://foo.example.com/secure
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>openresty/1.9.15.1</center>
</body>
</html>

# Lets add this client, so we'll be able to authenticate...
$ echo '{"service": "foo", "client": "12345" }'| python tools/auth.py http://foo.example.com/secure add
Hello! you have been authorized!

# Lets check if the client can access a different service (bar)
# it shouldn't, because the token is only for the 'foo' sub-domain,
# and we're trying to access the 'bar' sub-domain.
$ echo '{"service": "foo", "client": "12345" }'| python tools/auth.py http://bar.example.com/secure
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>openresty/1.9.15.1</center>
</body>
</html>

# Lets remove the client and check if it can access the 'foo' sub-domain...
$ echo '{"service": "foo", "client": "12345" }'| python tools/auth.py http://foo.example.com/secure rem
<head><title>401 Authorization Required</title></head>
<body bgcolor="white">
<center><h1>401 Authorization Required</h1></center>
<hr><center>openresty/1.9.15.1</center>
</body>
</html>
```

##### OAuth2 Single-Sign-On

1. fire up the browser and go to: `example.com/secure`
2. you will be redirected to a `Sign in` page
3. press the `Sign in with a GitHub Account` button
4. you will be redirected to `example.com/secure`

#### Environment Variables

| Environment Variables         | Type   | Description                              |
|:-----------------------------:|:------:|:-----------------------------------------|
| REDIS_HOST                    | string | The redis host. defaults to **redis**    |
| REDIS_PORT                    | int    | The redis port. defaults to **6379**     |
