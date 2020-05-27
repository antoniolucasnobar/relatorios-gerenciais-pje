-- [R136878][T965] - Relatório SAO - INCIDENTES DE EXECUCAO Julgados

-- explain analyze
-- explain
WITH RECURSIVE
    tipo_documento_sentenca AS (
        --62	Sentença	S			7007
        select id_tipo_processo_documento
        from tb_tipo_processo_documento
        where cd_documento = '7007'
          and in_ativo = 'S'
    ),
    movimentos_julgado_incidentes_execucao AS (
        SELECT ev.id_evento_processual
        FROM tb_evento_processual ev
        WHERE
            -- eh movimento de julgamento
            -- 219   - Julgado(s) procedente(s) o(s) pedido(s) (#{classe processual}/ #{nome do incidente}) de #{nome da parte}
            -- 221   - Julgado(s) procedente(s) em parte o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
            -- 220   - Julgado(s) improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
            -- 50013 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
            -- 50050 - Extinto com resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
            -- 50048 - Extinto sem resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
            ev.cd_evento IN
            ('219', '221', '220', '50013', '50050', '50048')
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
                AND julgamento.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
                AND (
                     (julgamento.ds_texto_final_interno ilike ANY (
                         ARRAY['%Impugnação à Sentença de Liquidação%',
                             '%Embargos à Execução%']
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
                                 ARRAY['Alterado o tipo de peti__o de Impugnação à Sentença de Liquidação%',
                                     'Alterado o tipo de peti__o de Embargos à Execução%']
                                 )
                         )
                 )
                 AND CASE
                     WHEN ed.ds_texto_final_interno ilike '%Embargos à Execução%'
                         THEN julgamento.ds_texto_final_externo ilike '%Embargos à Execução%'
                     WHEN ed.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%'
                         THEN julgamento.ds_texto_final_externo ilike '%Impugnação à Sentença de Liquidação%'
                     END
                )
        WHERE ed.id_processo IN (
            SELECT id_processo FROM processos_com_incidentes_assinados
        )
          AND ed.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date

          AND (
                (ed.id_evento = 85
                    AND ed.ds_texto_final_externo
                     ilike ANY (
                            ARRAY['Juntada a peti__o de Impugnação à Sentença de Liquidação%',
                                'Juntada a peti__o de Embargos à Execução%']
                            )
                    )
                OR
                (ed.id_evento = 50088
                    AND ed.ds_texto_final_externo
                     ilike ANY (
                            ARRAY['Alterado o tipo de peti__o de % para Impugnação à Sentença de Liquidação%',
                                'Alterado o tipo de peti__o de % para Embargos à Execução%']
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
                AND julgamento.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
                AND (
                     (julgamento.ds_texto_final_interno ilike ANY (
                         ARRAY['%Impugnação à Sentença de Liquidação%',
                             '%Embargos à Execução%']
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
                                 ARRAY['Alterado o tipo de peti__o de Impugnação à Sentença de Liquidação%',
                                     'Alterado o tipo de peti__o de Embargos à Execução%']
                                 )
                         )
                 )
                AND CASE
                        WHEN ed.ds_texto_final_interno ilike '%Embargos à Execução%'
                            THEN julgamento.ds_texto_final_externo ilike '%Embargos à Execução%'
                        WHEN ed.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%'
                            THEN julgamento.ds_texto_final_externo ilike '%Impugnação à Sentença de Liquidação%'
                 END
            )
        WHERE ed.id_processo_evento > id_peticao
          AND ed.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
          AND ed.id_processo = pj.id_processo
          AND (
                (ed.id_evento = 85
                    AND ed.ds_texto_final_externo
                     ilike ANY (
                            ARRAY['Juntada a peti__o de Impugnação à Sentença de Liquidação%',
                                'Juntada a peti__o de Embargos à Execução%']
                            )
                    )
                OR
                (ed.id_evento = 50088
                    AND ed.ds_texto_final_externo
                     ilike ANY (
                            ARRAY['Alterado o tipo de peti__o de % para Impugnação à Sentença de Liquidação%',
                                'Alterado o tipo de peti__o de % para Embargos à Execução%']
                            )
                    )
            )
        ORDER BY ed.id_processo, ed.dt_atualizacao, julgamento.id_processo_evento
    )
)
   , incidentes_sem_alterada_peticao AS (
    SELECT peticoes_incidentes_exec.* FROM peticoes_incidentes_exec
    WHERE peticoes_incidentes_exec.mov_julgamento IS DISTINCT FROM 50088
)
-- abaixo da pra ver cada ED julgado por processo
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " "
     , p.nr_processo AS "Número do Processo"
     , incidentes_sem_alterada_peticao.data_ed AS "Data Petição"
     , incidentes_sem_alterada_peticao.tx_ed AS "Movimento Juntada Petição"
     , incidentes_sem_alterada_peticao.dt_j AS "Data Julgamento Incidente Execução"
     , incidentes_sem_alterada_peticao.tx_j AS "Movimento Julgamento Incidente Execução"
--        , incidentes_sem_alterada_peticao.mov_julgamento
--        , incidentes_sem_alterada_peticao.mov_julgamento IS DISTINCT FROM 50088 AS diferente_alterado
FROM incidentes_sem_alterada_peticao
         INNER JOIN tb_processo p ON (p.id_processo = incidentes_sem_alterada_peticao.id_processo)
WHERE incidentes_sem_alterada_peticao.dt_j::date BETWEEN
          COALESCE(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date
          AND
          COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
ORDER BY 2, incidentes_sem_alterada_peticao.dt_j
