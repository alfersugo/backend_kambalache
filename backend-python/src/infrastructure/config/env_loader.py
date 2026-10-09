import os


def load_env(env_path: str) -> None:
    if not os.path.exists(env_path):
        return

    with open(env_path) as env_file:
        for line in env_file:
            if "=" not in line:
                continue
            key, val = line.strip().split("=", 1)
            if key and key not in os.environ:
                os.environ[key] = val
