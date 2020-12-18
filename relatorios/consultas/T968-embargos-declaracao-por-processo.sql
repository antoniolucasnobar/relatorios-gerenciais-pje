-- [T968] - Relatório SAO - Embargos de Declaração por processo

-- explain analyze
-- explain
WITH RECURSIVE
    movimentos_julgado_incidentes_execucao AS (
        SELECT ev.id_evento_processual
        FROM tb_evento_processual ev
        WHERE
            -- eh movimento de julgamento
            -- 198   - Acolhimento de Embargos de Declaração
            -- 871   - Acolhimento em parte de Embargos de Declaração
            -- 200   - Não acolhimento de Embargos de Declaração
            -- 230 - Prejudicado
            ev.cd_evento IN
            ('198', '871', '200', '230')
    )
   , processos_com_incidentes_assinados AS (
--     SELECT edj.id_processo, edj.id_pessoa
--     FROM incidentes_execucao_julgados edj
--     GROUP BY edj.id_processo, edj.id_pessoa
    SELECT id_processo FROM tb_processo WHERE nr_processo = :NUM_PROCESSO

)
   , peticoes_incidentes_exec (id_processo, id_peticao, id_julgamento, julgamentos_efetuados) AS (
    (
        SELECT DISTINCT ON (ed.id_processo) ed.id_processo
                                          , ed.id_processo_evento             AS id_peticao
                                          , julgamento.id_processo_evento     AS id_julgamento
                                          -- -1 para o array nao ficar vazio nunca
                                          , ARRAY[-1, julgamento.id_processo_evento]    AS julgamentos_efetuados
                                          , ed.dt_atualizacao                 AS data_ed
                                          , ed.ds_texto_final_externo         AS tx_ed
                                          , julgamento.dt_atualizacao         AS dt_j
                                          , julgamento.ds_texto_final_externo AS tx_j
                                          , julgamento.id_evento              AS mov_julgamento
        FROM tb_processo_evento ed
                 LEFT JOIN tb_processo_evento julgamento ON
            (ed.id_processo = julgamento.id_processo
                AND julgamento.dt_atualizacao > ed.dt_atualizacao
--                 AND julgamento.dt_atualizacao::date <= COALESCE(: DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
                AND (
                     (julgamento.ds_texto_final_interno ilike ANY (
                         ARRAY['%Embargos de Declaração%']
                         )
                         AND julgamento.id_evento IN
                             (
                                 SELECT id_evento_processual
                                 FROM movimentos_julgado_incidentes_execucao
                             )
                         )
                     OR
                     (julgamento.id_evento = 50088
                         AND julgamento.ds_texto_final_externo
                          ilike ANY (
                                 ARRAY['Alterado o tipo de peti__o de Embargos de Declaração%']
                                 )
                         )
                 )
--                  AND CASE
--                      WHEN ed.ds_texto_final_interno ilike '%Embargos à Execução%'
--                          THEN julgamento.ds_texto_final_externo ilike '%Embargos à Execução%'
--                      WHEN ed.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%'
--                          THEN julgamento.ds_texto_final_externo ilike '%Impugnação à Sentença de Liquidação%'
--                      END
                )
        WHERE ed.id_processo IN (
            SELECT id_processo FROM processos_com_incidentes_assinados
        )
--           AND ed.dt_atualizacao::date <= COALESCE(: DATA_OPCIONAL_FINAL, CURRENT_DATE)::date

          AND (
                (ed.id_evento = 85
                    AND ed.ds_texto_final_externo
                     ilike ANY (
                            ARRAY['Juntada a peti__o de Embargos de Declaração%']
                            )
                    )
                OR
                (ed.id_evento = 50088
                    AND ed.ds_texto_final_externo
                     ilike ANY (
                            ARRAY['Alterado o tipo de peti__o de % para Embargos de Declaração%']
                            )
                    )
            )
        ORDER BY ed.id_processo, ed.dt_atualizacao, julgamento.id_processo_evento
    )
    UNION
    (
        SELECT DISTINCT ON (ed.id_processo) ed.id_processo
                                          , ed.id_processo_evento             AS id_peticao
                                          , julgamento.id_processo_evento     AS id_j
                                          , julgamentos_efetuados || julgamento.id_processo_evento::integer AS
                                              julgamentos_efetuados
                                          , ed.dt_atualizacao                 AS data_ed
                                          , ed.ds_texto_final_externo         AS tx_ed
                                          , julgamento.dt_atualizacao         AS dt_j
                                          , julgamento.ds_texto_final_externo AS tx_j
                                          , julgamento.id_evento              AS mov_julgamento
        FROM peticoes_incidentes_exec pj
                 INNER JOIN tb_processo_evento ed ON (ed.id_processo = pj.id_processo)
                 LEFT JOIN tb_processo_evento julgamento ON
            (ed.id_processo = julgamento.id_processo
                -- parte recursiva pra pegar o mov de julgamento seguinte
--                 AND julgamento.id_processo_evento > pj.id_julgamento
                AND NOT (julgamento.id_processo_evento::integer = ANY(julgamentos_efetuados))
                AND julgamento.dt_atualizacao > ed.dt_atualizacao
--                 AND julgamento.dt_atualizacao::date <= COALESCE(: DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
                AND (
                     (julgamento.ds_texto_final_interno ilike ANY (
                         ARRAY['%Embargos de Declaração%']
                         )
                         AND julgamento.id_evento IN
                             (
                                 SELECT id_evento_processual
                                 FROM movimentos_julgado_incidentes_execucao
                             )
                         )
                     OR
                     (julgamento.id_evento = 50088
                         AND julgamento.ds_texto_final_externo
                          ilike ANY (
                                 ARRAY['Alterado o tipo de peti__o de Embargos de Declaração%']
                                 )
                         )
                 )
--                 AND CASE
--                         WHEN ed.ds_texto_final_interno ilike '%Embargos à Execução%'
--                             THEN julgamento.ds_texto_final_externo ilike '%Embargos à Execução%'
--                         WHEN ed.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%'
--                             THEN julgamento.ds_texto_final_externo ilike '%Impugnação à Sentença de Liquidação%'
--                  END
            )
        WHERE ed.id_processo_evento > id_peticao
--           AND ed.dt_atualizacao::date <= COALESCE(: DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
          AND ed.id_processo = pj.id_processo
          AND (
                (ed.id_evento = 85
                    AND ed.ds_texto_final_externo
                     ilike ANY (
                            ARRAY['Juntada a peti__o de Embargos de Declaração%']
                            )
                    )
                OR
                (ed.id_evento = 50088
                    AND ed.ds_texto_final_externo
                     ilike ANY (
                            ARRAY['Alterado o tipo de peti__o de % para Embargos de Declaração%']
                            )
                    )
            )
        ORDER BY ed.id_processo, ed.dt_atualizacao, julgamento.id_processo_evento
    )
)
-- , incidentes_sem_alterada_peticao AS (
--     SELECT peticoes_incidentes_exec.*
--            , concluso.id_pessoa_magistrado
--            , concluso.pendente_desde
--            , concluso.movimento_concluso
--     FROM peticoes_incidentes_exec
--     INNER JOIN LATERAL (
-- --     explain
--         SELECT concluso.id_pessoa_magistrado
--              , mov_concluso.id_processo
--              , mov_concluso.dt_atualizacao AS pendente_desde
--              , mov_concluso.ds_texto_final_interno AS movimento_concluso
--         FROM
--             tb_conclusao_magistrado concluso
--                 INNER JOIN tb_processo_evento mov_concluso
--                            ON (mov_concluso.id_processo_evento = concluso.id_processo_evento
--                                AND mov_concluso.id_processo_evento_excludente IS NULL
--                                -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
--                                and mov_concluso.id_evento = 51
--                                -- Conclusão do tipo "Julgamento da ação incidental"
--                                AND
--                                CASE
--                                    WHEN peticoes_incidentes_exec.id_julgamento IS NOT NULL THEN TRUE
--                                    ELSE (
--                                        mov_concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da ação incidental na execu__o%'
--                                        OR mov_concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento dos Embargos _ Execu__o%'
--                                        OR mov_concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da Impugna__o _ Sentença de Liquida__o%'
--                                    )
--                                END
--                                )
--         WHERE
--             peticoes_incidentes_exec.id_processo = mov_concluso.id_processo
--             AND mov_concluso.dt_atualizacao <= (coalesce(peticoes_incidentes_exec.dt_j, current_timestamp))::timestamp
--         ORDER BY mov_concluso.dt_atualizacao DESC
--         LIMIT 1
--         ) concluso ON TRUE
--     WHERE peticoes_incidentes_exec.mov_julgamento IS DISTINCT FROM 50088
-- )
-- abaixo da pra ver cada ED julgado por processo
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " "
     , p.nr_processo AS "Número do Processo"
     , incidentes_sem_alterada_peticao.data_ed AS "Data Petição"
     , incidentes_sem_alterada_peticao.tx_ed AS "Movimento Juntada Petição"
--      , incidentes_sem_alterada_peticao.pendente_desde AS "Data Concluso"
--      , incidentes_sem_alterada_peticao.movimento_concluso AS "Movimento Concluso"
     , incidentes_sem_alterada_peticao.dt_j AS "Data Movimento julgamento/tira pendência ED"
     , incidentes_sem_alterada_peticao.tx_j AS "Movimento que tirou pendência"
--        , incidentes_sem_alterada_peticao.mov_julgamento
--        , incidentes_sem_alterada_peticao.mov_julgamento IS DISTINCT FROM 50088 AS diferente_alterado
FROM peticoes_incidentes_exec incidentes_sem_alterada_peticao
    INNER JOIN tb_processo p ON (p.id_processo = incidentes_sem_alterada_peticao.id_processo)
--     INNER JOIN tb_usuario_login mag_concluso ON (mag_concluso.id_usuario = incidentes_sem_alterada_peticao.id_pessoa_magistrado)
-- WHERE
--     CASE
--       WHEN incidentes_sem_alterada_peticao.dt_j::date IS NULL THEN TRUE
--       ELSE
--         incidentes_sem_alterada_peticao.dt_j::date BETWEEN
--           COALESCE(: DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date
--           AND
--           COALESCE(: DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
--     END
ORDER BY 2, incidentes_sem_alterada_peticao.dt_j
