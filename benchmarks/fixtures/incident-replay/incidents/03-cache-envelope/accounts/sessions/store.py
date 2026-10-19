import msgpack

TTL = 60 * 60 * 24 * 14   # two weeks


class SessionStore:
    def __init__(self, redis):
        self.redis = redis

    def _key(self, sid):
        return "sess:%s" % sid

    def load(self, sid):
        raw = self.redis.get(self._key(sid))
        if raw is None:
            return {}
        return msgpack.unpackb(raw)["data"]

    def save(self, sid, data):
        self.redis.set(self._key(sid), msgpack.packb({"v": 2, "data": data}), ex=TTL)
