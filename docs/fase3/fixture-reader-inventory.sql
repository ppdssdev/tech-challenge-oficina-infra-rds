\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout = '3s';
SET LOCAL lock_timeout = '1s';
SELECT current_setting('transaction_read_only') = 'on' AS read_only,
       coalesce((SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()), false) AS tls;
SELECT count(*) AS identities_v2,
       count(*) FILTER (WHERE active) AS enabled_v2,
       count(*) FILTER (WHERE NOT active) AS disabled_v2
FROM auth.customer_identity_v2;
ROLLBACK;
