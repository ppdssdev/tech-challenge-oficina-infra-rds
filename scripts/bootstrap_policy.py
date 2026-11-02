"""Keep the repository root inert and shared-root restricted to existing addresses."""
from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parents[1]
for path in root.glob('*.tf'):
    if re.search(r'^\s*(resource|data|provider|module|import)\s+["{]', path.read_text(), re.M):
        raise SystemExit(f'{path}: root must remain metadata-only')
assert sorted(p.name for p in (root / 'shared-root').glob('*.tf')) == ['rds.tf']
fragment = root / 'shared-root/rds.tf'
expected = (root / 'docs/rds-source.sha256').read_text().split()[0]
assert hashlib.sha256(fragment.read_bytes()).hexdigest() == expected, 'Provisioned source changed; review evidence baseline'
addresses = set(re.findall(r'resource "([^"]+)" "([^"]+)"', fragment.read_text()))
assert addresses == {
    ('aws_db_instance', 'postgres'), ('aws_db_subnet_group', 'postgres'),
    ('aws_security_group', 'postgres'),
    ('aws_vpc_security_group_ingress_rule', 'postgres_from_app'),
    ('aws_vpc_security_group_egress_rule', 'app_to_postgres'),
}, addresses
assert not re.search(r'^\s*(module|import|data|provider)\s', fragment.read_text(), re.M)
print('Policy passed: inert root, exact provisioned fragment, five existing addresses, no VPC')
