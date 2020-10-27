null, TODOS, 1, Assinatura, 2, Inclusão

SELECT null, 'TODOS'
UNION ALL (SELECT DISTINCT 1, 'Assinatura' FROM tb_agrupamento fase)
UNION ALL (SELECT DISTINCT 2, 'Inclusão' FROM tb_agrupamento fase)