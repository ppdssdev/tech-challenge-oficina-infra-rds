\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout = '3s';
SET LOCAL lock_timeout = '1s';
SELECT current_setting('transaction_read_only') = 'on' AS read_only,
       coalesce((SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()), false) AS tls;
WITH identity_orders AS (
    SELECT i.customer_id, i.active, count(w.id) AS orders
    FROM auth.customer_identity_v2 i
    LEFT JOIN public.work_orders w ON w.customer_id = i.customer_id
    GROUP BY i.customer_id, i.active
)
SELECT count(*) FILTER (WHERE active AND orders > 0) AS enabled_owners_with_orders,
       count(*) FILTER (WHERE NOT active) AS disabled_identities,
       count(*) FILTER (WHERE active AND orders > 0) >= 2 AS two_owner_candidates
FROM identity_orders;
SELECT count(*) AS ambiguous_normalized_cpf_groups
FROM (
    SELECT regexp_replace(document_number, '[^0-9]', '', 'g')
    FROM public.customers
    WHERE document_type = 'CPF'
    GROUP BY regexp_replace(document_number, '[^0-9]', '', 'g')
    HAVING count(*) > 1
) ambiguous;
SELECT count(*) AS auth_enabled_business_inactive
FROM auth.customer_identity_v2 i
JOIN public.customers c ON c.id = i.customer_id
WHERE i.active AND NOT c.active;
ROLLBACK;
