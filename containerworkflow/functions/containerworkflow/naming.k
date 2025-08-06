### naming.k

import crypto

schema NamingParams:
    """
    Input structure for resource naming convention.

    Attributes
    ----------
    environment: str
        Environment name. One of: dev, test, prod, core.
    serviceLine: str
        Functional group or application area. Will be truncated to 8 characters.
    system: str
        Business or technical domain owning the resource. Will be truncated to 8 characters.
    """
    environment: str
    serviceLine: str
    system: str

    check:
        environment in ["dev", "test", "prod", "core"], "Invalid environment: {}".format(environment)

# Environment prefixes
_environmentMap = {
    "dev": "occdev",
    "test": "occtest",
    "prod": "occprod",
    "core": "occcore",
}

# Clean input string (remove separators, lowercase)
_sanitize = lambda s: str -> str {
    s.replace(" ", "").replace("-", "").replace("_", "").replace(".", "").lower()
}

# Truncate string to max length
_truncate = lambda s: str, n: int -> str {
    s[0:n]
}

# Deterministic 6-character hash suffix from name input
_hash_suffix = lambda input: str -> str {
    crypto.sha1(input)[0:6]
}

# Final resource name with optional deterministic suffix
resource_name = lambda p: NamingParams, resourceName: str -> str {
    prefix = _environmentMap[p.environment]
    sys = _sanitize(_truncate(p.system, 8))
    svc = _sanitize(_truncate(p.serviceLine, 8))
    base = _sanitize(resourceName)

    base_name = "{}-{}-{}-{}".format(prefix, sys, svc, base)
    suffix = _hash_suffix(base_name)

    name = "{}-{}".format(base_name, suffix)

    assert len(name) <= 63, "Generated name exceeds 63 characters: {}".format(name)

    name
}
