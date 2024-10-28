import typing as t


def get_fqdn(host: str, env: t.Optional[str] = None, prefix: t.Optional[str] = None) -> str:
    if prefix:
        if env and env != "prod":
            return f"{prefix}.{env}.{host}"
        else:
            return f"{prefix}.{host}"
    else:
        if env and env != "prod":
            return f"{env}.{host}"
        else:
            return host
