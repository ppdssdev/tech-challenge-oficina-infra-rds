"""Política estática da stack RDS. Nome preservado para compatibilidade com CI."""
from pathlib import Path
import unittest
import hcl2

ROOT = Path(__file__).resolve().parents[1]


def normalize(value):
    # bc-python-hcl2 (mesmo parser do Checkov) agrupa atributos em listas.
    block_keys = {'resource', 'data', 'variable', 'output', 'provider', 'terraform',
                  'locals', 'lifecycle', 'precondition', 'validation', 'required_providers',
                  'default_tags', 'module', 'import', 'moved', 'removed', 'check', 'backend'}
    if not isinstance(value, dict):
        return value
    result = {}
    for key, item in value.items():
        if key.startswith('__'):
            continue
        if isinstance(item, list):
            if key in block_keys:
                result[key] = [normalize(v) for v in item]
            else:
                assert len(item) == 1, f'Atributo duplicado: {key}'
                result[key] = normalize(item[0])
        else:
            result[key] = normalize(item)
    return result


def load():
    result = {}
    for path in ROOT.glob('*.tf'):
        with path.open() as stream:
            for key, values in normalize(hcl2.load(stream)).items():
                result.setdefault(key, []).extend(values)
    return result


def blocks(config, kind):
    return {f'{typ}.{name}': body for group in config.get(kind, [])
            for typ, names in group.items() for name, body in names.items()}


class Policy(unittest.TestCase):
    def setUp(self):
        self.config = load()
        self.resources = blocks(self.config, 'resource')
        self.variables = {k: v for group in self.config['variable'] for k, v in group.items()}

    def test_ownership_and_state(self):
        self.assertEqual(set(self.resources), {
            'aws_db_instance.postgres', 'aws_db_subnet_group.postgres',
            'aws_security_group.postgres', 'aws_vpc_security_group_ingress_rule.postgres'})
        self.assertEqual(set(blocks(self.config, 'data')), {
            'aws_vpc.network', 'aws_subnet.private', 'aws_security_group.clients',
            'aws_rds_engine_version.postgres', 'aws_rds_orderable_db_instance.postgres'})
        for kind in ('module', 'import', 'moved', 'removed', 'check'):
            self.assertNotIn(kind, self.config)
        self.assertNotIn('backend', self.config['terraform'][0])
        provider = self.config['provider'][0]['aws']
        self.assertEqual(provider['allowed_account_ids'], ['${var.aws_account_id}'])
        self.assertEqual(provider['profile'], 'oficina-staging')
        self.assertEqual(provider['region'], '${var.aws_region}')

    def test_rds_security_and_cost(self):
        db = self.resources['aws_db_instance.postgres']
        expected = {
            'db_name': 'oficina_db',
            'engine': 'postgres', 'allocated_storage': 20, 'max_allocated_storage': 0,
            'storage_type': 'gp3', 'storage_encrypted': True, 'multi_az': False,
            'publicly_accessible': False, 'manage_master_user_password': True,
            'performance_insights_enabled': False, 'monitoring_interval': 0,
            'backup_retention_period': 7, 'skip_final_snapshot': False,
            'delete_automated_backups': False, 'allow_major_version_upgrade': False,
            'engine_lifecycle_support': 'open-source-rds-extended-support-disabled',
            'deletion_protection': '${var.deletion_protection}',
            'final_snapshot_identifier': '${var.final_snapshot_identifier}',
            'port': 5432, 'db_subnet_group_name': '${aws_db_subnet_group.postgres.name}',
            'vpc_security_group_ids': ['${aws_security_group.postgres.id}'],
            'engine_version': '${data.aws_rds_engine_version.postgres.version}',
            'instance_class': '${data.aws_rds_orderable_db_instance.postgres.instance_class}',
        }
        for key, value in expected.items():
            self.assertEqual(db[key], value, key)
        for key in ('password', 'password_wo', 'replicate_source_db', 'snapshot_identifier'):
            self.assertNotIn(key, db)
        self.assertTrue(self.variables['deletion_protection']['default'])
        self.assertIn('var.deletion_protection || var.final_snapshot_identifier != None',
                      str(self.variables['final_snapshot_identifier']['validation']))
        offer = blocks(self.config, 'data')['aws_rds_orderable_db_instance.postgres']
        self.assertEqual(offer['instance_class'], 'db.t4g.micro')
        self.assertEqual(offer['engine_version'], '${data.aws_rds_engine_version.postgres.version}')
        self.assertEqual(offer['storage_type'], 'gp3')
        self.assertIn('^16', str(self.variables['postgres_engine_version']['validation']))

    def test_only_two_sg_ingresses(self):
        sg = self.resources['aws_security_group.postgres']
        self.assertNotIn('ingress', sg)
        self.assertNotIn('egress', sg)
        self.assertEqual(sg['vpc_id'], '${var.network_contract.vpc_id}')
        self.assertEqual(sg['depends_on'], ['${aws_db_subnet_group.postgres}'])
        rule = self.resources['aws_vpc_security_group_ingress_rule.postgres']
        self.assertEqual(rule['for_each'], {
            'app': '${var.network_contract.app_security_group_id}',
            'auth': '${var.network_contract.auth_security_group_id}'})
        self.assertEqual(rule['security_group_id'], '${aws_security_group.postgres.id}')
        self.assertEqual(rule['referenced_security_group_id'], '${each.value}')
        self.assertEqual((rule['from_port'], rule['to_port'], rule['ip_protocol']), (5432, 5432, 'tcp'))
        for key in ('cidr_ipv4', 'cidr_ipv6', 'prefix_list_id'):
            self.assertNotIn(key, rule)

    def test_contract_and_blocking_preconditions(self):
        contract = self.variables['network_contract']
        for field in ('schema_version', 'account_id', 'region', 'environment', 'vpc_id',
                      'private_subnet_ids', 'app_security_group_id', 'auth_security_group_id'):
            self.assertIn(field, contract['type'])
        validations = [v['condition'] for v in contract['validation']]
        for expression in ('var.network_contract.schema_version == 3',
                           'var.network_contract.account_id == var.aws_account_id',
                           'var.network_contract.region == var.aws_region',
                           'var.network_contract.environment == var.environment'):
            self.assertIn('${' + expression + '}', validations)
        self.assertIn('length(distinct(var.network_contract.private_subnet_ids)) >= 2', str(validations))
        subnet = self.resources['aws_db_subnet_group.postgres']
        self.assertEqual(subnet['subnet_ids'], '${var.network_contract.private_subnet_ids}')
        conditions = str(subnet['lifecycle'][0]['precondition'])
        for expression in ('data.aws_vpc.network.owner_id == var.aws_account_id',
                           'subnet.vpc_id == var.network_contract.vpc_id',
                           'subnet.owner_id == var.aws_account_id', '!subnet.map_public_ip_on_launch',
                           'subnet.availability_zone_id])) >= 2',
                           'sg.vpc_id == var.network_contract.vpc_id', 'split(":", sg.arn)[4] == var.aws_account_id'):
            self.assertIn(expression, conditions)
        self.assertEqual(len(subnet['lifecycle'][0]['precondition']), 4)

    def test_regressions_are_rejected(self):
        cases = [
            ('test_rds_security_and_cost', 'aws_db_instance.postgres', 'db_name', 'oficina'),
            ('test_rds_security_and_cost', 'aws_db_instance.postgres', 'publicly_accessible', True),
            ('test_rds_security_and_cost', 'aws_db_instance.postgres', 'storage_encrypted', False),
            ('test_rds_security_and_cost', 'aws_db_instance.postgres', 'manage_master_user_password', False),
            ('test_only_two_sg_ingresses', 'aws_vpc_security_group_ingress_rule.postgres', 'cidr_ipv4', '0.0.0.0/0'),
            ('test_only_two_sg_ingresses', 'aws_vpc_security_group_ingress_rule.postgres', 'to_port', 65535),
            ('test_contract_and_blocking_preconditions', 'aws_db_subnet_group.postgres', 'lifecycle', [{'precondition': []}]),
        ]
        for method, resource, field, value in cases:
            with self.subTest(field=field):
                policy = Policy(method)
                policy.setUp()
                policy.resources[resource][field] = value
                with self.assertRaises(AssertionError):
                    getattr(policy, method)()
        policy = Policy('test_contract_and_blocking_preconditions')
        policy.setUp()
        policy.variables['network_contract']['validation'][0]['condition'] = '${var.network_contract.schema_version == 2}'
        with self.assertRaises(AssertionError):
            policy.test_contract_and_blocking_preconditions()
        policy = Policy('test_ownership_and_state')
        policy.setUp()
        policy.resources['aws_vpc.forbidden'] = {}
        with self.assertRaises(AssertionError):
            policy.test_ownership_and_state()

    def test_output_allowlist(self):
        outputs = {k: v['value'] for group in self.config['output'] for k, v in group.items()}
        self.assertEqual(outputs, {
            'rds_identifier': '${aws_db_instance.postgres.identifier}',
            'db_endpoint': '${aws_db_instance.postgres.address}',
            'db_port': '${aws_db_instance.postgres.port}',
            'db_name': '${aws_db_instance.postgres.db_name}',
            'db_security_group_id': '${aws_security_group.postgres.id}',
            'admin_secret_arn': '${aws_db_instance.postgres.master_user_secret[0].secret_arn}',
        })


if __name__ == '__main__':
    unittest.main(verbosity=2)
