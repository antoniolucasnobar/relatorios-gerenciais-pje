SELECT 'http://processo='||cle.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||cle.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cj.ds_classe_judicial_sigla||' '||cle.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade",
    cle.dt_inicio_clet as "Data de cadastro da CLE", 
    cle.dt_ajuizamento as "Data de ajuizamento da ação",
    fase.nm_agrupamento_fase as "Fase",
    pt.nm_tarefa as "Tarefa"
FROM
    tb_processo_clet cle
    INNER JOIN tb_processo p ON p.id_processo = cle.id_processo_trf
	inner join tb_processo_trf ptrf on ptrf.id_processo_trf = cle.id_processo_trf
	inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
WHERE
    cle.dt_inicio_clet:: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
    AND oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
    AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
ORDER BY cle.dt_inicio_clet
