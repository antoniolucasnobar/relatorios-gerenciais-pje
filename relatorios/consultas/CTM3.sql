-- [54930][CTM3] Mandados expedidos - PJe 2

select distinct cm.nm_central_mandados AS "Central"
              , oj.nm_oficial_justica AS "Oficial(a)"
              , m.nr_processo_externo AS "Processo"
              , m.nr_mandado AS "Mandado"
              , REPLACE(m.nm_orgao_julgador_externo, 'VARA DO TRABALHO', 'VT' ) AS "Unidade"
              , m.dt_criacao::date as "Data de Expedição"
              , pm.dt_recebimento::date as "Data de Distribuição"
              , pm.dt_devolucao::date as "Data da Devolução"
-- comentando calculo de dias uteis por deixar a consulta muito lenta.
--              , (select trt4_dias_uteis_entre_datas(date(m.dt_criacao), date(pm.dt_devolucao))) as "Dias úteis"
from ctm.tb_mandado m
    left outer join ctm.tb_posse_mandado pm on pm.id_mandado = m.id_mandado
    left outer join ctm.tb_situacao_mandado sm on sm.id_mandado = m.id_mandado
    left outer join ctm.tb_oficial_justica oj on oj.id_oficial_justica = pm.id_oficial_justica
    left outer join ctm.tb_central_mandados cm on cm.id_central_mandados = pm.id_central_mandados
where
    pm.dt_recebimento :: date between
      coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and
      (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
    AND cm.id_central_mandados = coalesce(:CENTRAL_MANDADOS_CTM2, cm.id_central_mandados)
order by pm.dt_recebimento::date
