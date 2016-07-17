from __future__ import print_function
import requests
import jwt
import sys
import os
import redis
import json
from select import select

usage = "Usage: echo <claims> | %s <url> <(add|remove) client>" % sys.argv[0]
redis_client = redis.StrictRedis(host=os.getenv("REDIS_HOST", '127.0.0.1'),
                                 port=int(os.getenv("REDIS_PORT", 6379)))


def get_claims():
    if select([sys.stdin, ], [], [], 0.0)[0]:
        claims = json.load(sys.stdin)
        if not all(x in claims for x in ["service", "client"]):
            raise ValueError("service or client keys are missing from claims")
        return claims
    raise IOError(usage)


def get_url():
    if len(sys.argv) < 2:
        raise IOError(usage)
    return sys.argv[1]


def unknown_op(claims):
    raise NotImplementedError("operation '%s' is not supported" % sys.argv[2])

def add_client(claims):
    redis_client.sadd(claims["service"],
                      claims["client"])


def remove_client(claims):
    redis_client.srem(claims["service"],
                      claims["client"])


def main():
    claims = get_claims()
    if len(sys.argv) > 2:
        # add or remove a client, then quit!
        ops = dict(add=add_client, rem=remove_client)
        op = ops.get(sys.argv[2], unknown_op)
        op(claims)

    token = jwt.encode(claims,
                       'secret',
                       algorithm='HS256')

    headers = {'Authorization': "Bearer %s" % token}

    response = requests.get(url=get_url(),
                            headers=headers)

    if not response.ok:
        raise ValueError(response.text)

    print(response.text.strip())

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(e.message.strip())
