"""Validate the exact RDS fragment with the pinned K3s root, without state/AWS."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

K3S_COMMIT = '2314744b57fdccb86802a773159f24b97b977e49'
p = argparse.ArgumentParser()
p.add_argument('k3s_checkout', type=Path)
a = p.parse_args()
repo = Path(__file__).resolve().parents[1]
# git archive reads only committed configuration: excludes local state, vars and secrets.
with tempfile.TemporaryDirectory(prefix='rds-validate-') as d:
    archive = subprocess.check_output(['git', '-C', str(a.k3s_checkout), 'archive', K3S_COMMIT])
    subprocess.run(['tar', '-x', '-C', d], input=archive, check=True)
    shutil.copyfile(repo / 'shared-root/rds.tf', Path(d) / 'rds.tf')
    shutil.copyfile(repo / 'shared-root/.terraform.lock.hcl', Path(d) / '.terraform.lock.hcl')
    subprocess.run(['terraform', f'-chdir={d}', 'init', '-backend=false', '-input=false', '-lockfile=readonly'], check=True)
    subprocess.run(['terraform', f'-chdir={d}', 'validate'], check=True)
print('RDS + pinned K3s root validated; no state copied, no plan/apply.')
