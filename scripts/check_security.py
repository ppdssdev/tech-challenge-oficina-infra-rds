"""Fail on unexpected Checkov findings; retain a visible existing-risk baseline."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
result = subprocess.run(['checkov', '-d', str(root / 'shared-root'), '--framework', 'terraform', '--skip-download', '--output', 'json'], capture_output=True, text=True)
if result.returncode not in (0, 1):
    raise SystemExit(result.stderr)
report = json.loads(result.stdout)
expected = {(x, 'aws_db_instance.postgres') for x in [
    'CKV_AWS_161', 'CKV_AWS_226', 'CKV_AWS_118', 'CKV_AWS_129',
    'CKV_AWS_353', 'CKV_AWS_157', 'CKV2_AWS_30']}
actual = {(x['check_id'], x['resource']) for x in report['results']['failed_checks']}
print(json.dumps(report['summary'], indent=2))
for check, resource in sorted(actual):
    print(f'Existing risk (docs/evidence.md): {check} {resource}')
assert report['summary']['parsing_errors'] == 0
assert report['summary']['resource_count'] == 5
assert actual == expected, f'Security baseline changed: {actual ^ expected}'
print('No unexpected findings. Existing risks remain unresolved, not security approval.')
