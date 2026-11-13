"""Select a local CLI matching the server, before touching its auth database."""
import os
import re
import shutil
import stat
import subprocess

VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?")


def valid_version(version):
    return isinstance(version, str) and len(version) <= 128 and VERSION.fullmatch(version) is not None


class CliError(Exception):
    def __init__(self, reason):
        self.reason = reason
        super().__init__(reason)


def run_cli(command):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=12, check=True).stdout
    except FileNotFoundError as error:
        raise CliError('cli_missing') from error
    except subprocess.TimeoutExpired as error:
        raise CliError('cli_timeout') from error
    except subprocess.CalledProcessError as error:
        # T3 emits this error on stdout. Never forward raw CLI output: a failed
        # auth command can contain credentials or arbitrary local diagnostics.
        reason = 'database' if 'ServerOwnsDatabaseError' in (error.stdout or '') + (error.stderr or '') else 'cli_failed'
        raise CliError(reason) from error
    except (OSError, UnicodeError) as error:
        raise CliError('cli_failed') from error


class LocalCli:
    def __init__(self):
        self.path = ''
        self.version = ''
        self.source = ''

    def select(self, base, version):
        if not valid_version(version):
            raise CliError('server_version')
        # Only the conventional version cache is executable input; the server
        # cannot supply an arbitrary path, and escaping symlinks are rejected.
        versions = (base / 'runtime/versions').resolve()
        candidate = versions / version / 't3'
        try:
            resolved = candidate.resolve(strict=True)
            info = resolved.stat()
            if (resolved == candidate and stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                    and not info.st_mode & 0o022 and os.access(resolved, os.X_OK)):
                try:
                    self.probe(str(candidate), 'cache')
                    if self.version == version:
                        return
                except CliError:
                    pass  # A broken cache may still have a matching PATH CLI.
        except OSError:
            pass
        path = shutil.which('t3')
        if not path:
            raise CliError('cli_missing')
        self.probe(path, 'path')
        if self.version != version:
            raise CliError('cli_version')

    def probe(self, path, source):
        self.path, self.source, self.version = path, source, ''
        output = run_cli([path, '--version']).strip()
        match = re.fullmatch(r'(?:t3\s+)?v?(' + VERSION.pattern + r')', output)
        if not match:
            raise CliError('cli_version')
        self.version = match[1]

    def auth(self, base, *args):
        return run_cli([self.path, 'auth', 'session', *args, '--base-dir', str(base)])
