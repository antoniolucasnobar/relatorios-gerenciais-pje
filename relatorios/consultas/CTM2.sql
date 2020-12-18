-- [54930][CTM2] Mandados Pendentes PJe 2

select distinct cm.nm_central_mandados AS "Central"
              , oj.nm_oficial_justica AS "Oficial(a)"
              , m.nr_processo_externo AS "Processo"
              , m.nr_mandado AS "Mandado"
              , REPLACE(m.nm_orgao_julgador_externo, 'VARA DO TRABALHO', 'VT' ) AS "Unidade"
              , to_char(m.dt_criacao, 'dd/mm/yyyy') as "Data de Expedição"
              , pm.dt_recebimento::date as "Data de Distribuição"
              , to_char(pm.dt_devolucao_prevista, 'dd/mm/yyyy') as "Prazo"
              , (select trt4_dias_uteis_entre_datas(date(m.dt_criacao), current_date)) as "Dias úteis"
from ctm.tb_mandado m
         -- left outer join ctm.tb_endereco_mandado em on m.id_mandado = em.id_endereco_mandado
         left outer join ctm.tb_posse_mandado pm on pm.id_mandado = m.id_mandado
    -- left outer join ctm.tb_anotacao_mandado am on am.id_mandado = m.id_mandado
         left outer join ctm.tb_situacao_mandado sm on sm.id_mandado = m.id_mandado
         left outer join ctm.tb_pendencia_distribuicao_mandado pdm on pdm.id_mandado = m.id_mandado
         left outer join ctm.tb_mandado_documento md on md.id_mandado = m.id_mandado
         left outer join ctm.tb_oficial_justica oj on oj.id_oficial_justica = pm.id_oficial_justica
         left outer join ctm.tb_central_mandados cm on cm.id_central_mandados = m.id_central_mandados
where
        sm.id_tipo_situacao_mandado = 1
  and pm.dt_devolucao is null
  AND cm.id_central_mandados = coalesce(:CENTRAL_MANDADOS_CTM2, cm.id_central_mandados)
order by pm.dt_recebimento::date
