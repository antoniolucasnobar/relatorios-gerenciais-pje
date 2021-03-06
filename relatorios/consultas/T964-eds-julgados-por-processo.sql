-- [R136875][T964] - EMBARGOS DECLARATÓRIOS JULGADOS por processo
-- explain
WITH RECURSIVE movimentos_embargos_declaracao_julgados AS (
    SELECT ev.id_evento_processual
    FROM tb_evento_processual ev
    WHERE
        -- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}
        -- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}
        -- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}
        -- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa}
        ev.cd_evento IN
        ('198', '871', '200', '235')
)
   -- diferente dos outros relatorios, pois esse busca por processo
   -- usando o mesmo nome para simplificar manutencao dos relatorios: T961, T963 e T964
, processos_com_eds_assinados AS (
    SELECT id_processo FROM tb_processo WHERE nr_processo = :NUM_PROCESSO
--     SELECT julgamento.id_processo
--     FROM tb_processo_evento julgamento
--     INNER JOIN tb_processo USING (id_processo)
--     WHERE
--     CASE
--         WHEN : NUM_PROCESSO = ''
--         THEN
--             (julgamento.id_evento = 50088
--                 AND julgamento.ds_texto_final_externo
--                 ilike
--                 'Alterado o tipo de peti__o de Embargos de Declara__o%'
--             )
--         ELSE nr_processo ilike '%' || : NUM_PROCESSO || '%'
--     END
)
, peticoes_eds (id_processo, id_peticao, id_julgamento) AS (
    (
        SELECT DISTINCT ON (ed.id_processo) ed.id_processo
             , ed.id_processo_evento             AS id_peticao
             , julgamento.id_processo_evento     AS id_julgamento
             , ed.dt_atualizacao                 AS data_ed
             , ed.ds_texto_final_externo         AS tx_ed
             , julgamento.dt_atualizacao         AS dt_j
             , julgamento.ds_texto_final_externo AS tx_j
             , julgamento.id_evento              AS mov_julgamento
        FROM tb_processo_evento ed
                 LEFT JOIN tb_processo_evento julgamento ON
            (ed.id_processo = julgamento.id_processo
                AND julgamento.dt_atualizacao > ed.dt_atualizacao
                AND julgamento.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
                AND (
                     (julgamento.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                         AND julgamento.id_evento IN
                             (
                                 SELECT id_evento_processual
                                 FROM movimentos_embargos_declaracao_julgados
                             )
                         )
                     OR
                     (julgamento.id_evento = 50088
                         AND julgamento.ds_texto_final_externo
                          ilike
                             'Alterado o tipo de peti__o de Embargos de Declara__o%'
                         )
                 )
                )
        WHERE ed.id_processo IN (
            SELECT id_processo FROM processos_com_eds_assinados
        )
          AND ed.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date

          AND (
                (ed.id_evento = 85
                    AND ed.ds_texto_final_externo
                     ilike 'Juntada a petição de Embargos de Declara__o%'
                    )
                OR
                (ed.id_evento = 50088
                    AND ed.ds_texto_final_externo
                     ilike 'Alterado o tipo de peti__o de % para Embargos de Declara__o'
                    )
            )
        ORDER BY ed.id_processo, ed.dt_atualizacao, julgamento.id_processo_evento
    )
    UNION
    (
        SELECT DISTINCT ON (ed.id_processo) ed.id_processo
             , ed.id_processo_evento             AS id_peticao
             , julgamento.id_processo_evento     AS id_j
             , ed.dt_atualizacao                 AS data_ed
             , ed.ds_texto_final_externo         AS tx_ed
             , julgamento.dt_atualizacao         AS dt_j
             , julgamento.ds_texto_final_externo AS tx_j
             , julgamento.id_evento              AS mov_julgamento
        FROM peticoes_eds pj
                 INNER JOIN tb_processo_evento ed ON (ed.id_processo = pj.id_processo)
                 LEFT JOIN tb_processo_evento julgamento ON
            (ed.id_processo = julgamento.id_processo
                AND julgamento.id_processo_evento > pj.id_julgamento
                AND julgamento.dt_atualizacao > ed.dt_atualizacao
                AND julgamento.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
                AND (
                     (julgamento.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                         AND julgamento.id_evento IN
                             (
                                 SELECT id_evento_processual
                                 FROM movimentos_embargos_declaracao_julgados
                             )
                         )
                     OR
                     (julgamento.id_evento = 50088
                         AND julgamento.ds_texto_final_externo
                          ilike
                             'Alterado o tipo de peti__o de Embargos de Declara__o%'
                         )
                 )
                )
        WHERE ed.id_processo_evento > id_peticao
          AND ed.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
          AND ed.id_processo = pj.id_processo
          AND (
                (ed.id_evento = 85
                    AND ed.ds_texto_final_externo
                     ilike 'Juntada a petição de Embargos de Declara__o%'
                    )
                OR
                (ed.id_evento = 50088
                    AND ed.ds_texto_final_externo
                     ilike 'Alterado o tipo de peti__o de % para Embargos de Declara__o'
                    )
            )
        ORDER BY ed.id_processo, ed.dt_atualizacao, julgamento.id_processo_evento
    )
)
, eds_sem_alterada_peticao AS (
    SELECT peticoes_eds.* FROM peticoes_eds
    WHERE peticoes_eds.mov_julgamento IS DISTINCT FROM 50088
    )
-- abaixo da pra ver cada ED julgado por processo
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " "
       , p.nr_processo AS "Número do Processo"
       , eds_sem_alterada_peticao.data_ed AS "Data Petição ED"
       , eds_sem_alterada_peticao.tx_ed AS "Movimento Juntada Petição ED"
       , eds_sem_alterada_peticao.dt_j AS "Data Julgamento ED"
       , eds_sem_alterada_peticao.tx_j AS "Movimento Julgamento ED"
--        , eds_sem_alterada_peticao.mov_julgamento
--        , eds_sem_alterada_peticao.mov_julgamento IS DISTINCT FROM 50088 AS diferente_alterado
FROM eds_sem_alterada_peticao
         INNER JOIN tb_processo p ON (p.id_processo = eds_sem_alterada_peticao.id_processo)
WHERE eds_sem_alterada_peticao.dt_j::date BETWEEN
    COALESCE(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date
  AND
    COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
ORDER BY 2, eds_sem_alterada_peticao.dt_j

