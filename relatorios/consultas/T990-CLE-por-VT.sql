-- [R149090][T990] Listagem de CLE

SELECT 'http://processo='||cle.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||cle.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cle.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade"
    , cle.dh_cadastro_clet AS "Data Cadastro"
    , fase_cadastro.nm_agrupamento_fase as "Fase de cadastro"
    , fase_atual.nm_agrupamento_fase as "Fase Atual"
    , pt.nm_tarefa as "Tarefa"
    , CASE
        WHEN fase_atual.id_agrupamento_fase = 5 AND pe.id_evento = 246 THEN pe.dt_atualizacao
    END AS "Data Arquivamento definitivo"
FROM
    tb_processo_clet cle
    INNER JOIN tb_processo p ON (cle.id_processo_trf = p.id_processo)
    INNER JOIN tb_processo_trf ptrf ON (cle.id_processo_trf = ptrf.id_processo_trf)
    INNER JOIN tb_orgao_julgador oj ON (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
    INNER JOIN tb_agrupamento_fase fase_cadastro on
        (cle.id_fase_processual_inicio_clet = fase_cadastro.id_agrupamento_fase)
    INNER JOIN tb_agrupamento_fase fase_atual on
        (p.id_agrupamento_fase = fase_atual.id_agrupamento_fase)
    INNER JOIN tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    LEFT JOIN LATERAL (
        SELECT * FROM tb_processo_evento pe WHERE p.id_processo = pe.id_processo
            AND pe.id_processo_evento_excludente is null
            AND pe.id_evento IN (246, 245, 893)
        ORDER BY pe.dt_atualizacao DESC
        LIMIT 1
        ) pe ON TRUE
WHERE
    cle.dh_cadastro_clet::date BETWEEN
            coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('year', current_date))::date
            AND (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
    AND oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
    AND fase_atual.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase_atual.id_agrupamento_fase)
ORDER BY cle.dh_cadastro_clet
