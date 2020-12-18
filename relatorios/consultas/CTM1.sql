-- [54930][CTM1] Mandados Cumpridos PJe 2

select distinct cm.nm_central_mandados AS "Central"
              , oj.nm_oficial_justica AS "Oficial(a)"
              , m.nr_processo_externo AS "Processo"
              , m.nr_mandado AS "Mandado"
              , REPLACE(m.nm_orgao_julgador_externo, 'VARA DO TRABALHO', 'VT' ) AS "Unidade"
              , m.dt_criacao::date as "Data de Expedição"
              , pm.dt_recebimento::date as "Data de Distribuição"
              , pm.dt_devolucao::date as "Data da Devolução"
--               , (select trt4_dias_uteis_entre_datas(date(m.dt_criacao), date(pm.dt_devolucao))) as "Dias úteis"
FROM ctm.tb_mandado m
    -- left outer join ctm.tb_endereco_mandado em on m.id_mandado = em.id_endereco_mandado
    left outer join ctm.tb_posse_mandado pm on pm.id_mandado = m.id_mandado
    -- left outer join ctm.tb_anotacao_mandado am on am.id_mandado = m.id_mandado
    left outer join ctm.tb_situacao_mandado sm on sm.id_mandado = m.id_mandado
    left outer join ctm.tb_pendencia_distribuicao_mandado pdm on pdm.id_mandado = m.id_mandado
    left outer join ctm.tb_mandado_documento md on md.id_mandado = m.id_mandado
    left outer join ctm.tb_oficial_justica oj on oj.id_oficial_justica = pm.id_oficial_justica
    left outer join ctm.tb_central_mandados cm on cm.id_central_mandados = pm.id_central_mandados
where
    sm.id_tipo_situacao_mandado = 3
    and pm.dt_devolucao is not null
    and ((pm.in_redistribuido = 'N') or (pm.in_redistribuido is null))
    and m.id_tipo_resultado_mandado is not null
    AND pm.dt_devolucao :: date between
      coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and
      (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
    AND cm.id_central_mandados = coalesce(:CENTRAL_MANDADOS_CTM2, cm.id_central_mandados)
order by pm.dt_devolucao
