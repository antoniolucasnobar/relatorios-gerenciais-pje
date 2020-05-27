-- [R136878][T956] - Relatório SAO - INCIDENTES DE EXECUCAO Julgados

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
,
 incidentes_execucao_julgados AS (
     select
         assin.id_pessoa,
         doc.dt_juntada,
         doc.id_processo
     from tb_processo_documento doc
          inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
-- retirando o concluso a pedido de Jeferson, pois o Qliq so considera a peticao e o movimento de julgamento
--           inner join lateral (
--             select pen.ds_texto_final_interno, pen.dt_atualizacao FROM
--              tb_conclusao_magistrado concluso
--                  INNER JOIN tb_processo_evento pen
--                         ON (pen.id_processo_evento = concluso.id_processo_evento
--                             and pen.id_processo = doc.id_processo
--                             AND pen.id_processo_evento_excludente IS NULL
--                             and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
--                             )
--              where pen.dt_atualizacao < doc.dt_juntada
--              order by pen.dt_atualizacao desc
--              limit 1
--           ) concluso ON TRUE
--         INNER JOIN tb_processo_evento iniciada_execucao
--             ON (iniciada_execucao.id_processo = doc.id_processo
--             AND iniciada_execucao.id_evento = 11385)
--             -- TODO: ver quais outros movimentos que deixam o processo na
--             -- execução, como por exemplo desarquivar
--             -- TODO: ver tb que pode ter mais de um mov. de iniciada a execução
    where doc.in_ativo = 'S'
    -- 62 -- sentenca
      AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_sentenca)

    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    -- so pega documentos juntados depois do inicio da execucao
--       and doc.dt_juntada :: date between GREATEST(iniciada_execucao.dt_atualizacao, coalesce(: DATA_INICIAL_OPCIONAL,
--              date_trunc('month', current_date))::date)::date and (coalesce(: DATA_OPCIONAL_FINAL, current_date))
--              ::date
      and doc.dt_juntada :: date between
          coalesce(:DATA_INICIAL_OPCIONAL,date_trunc('month', current_date))::date
          and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
-- ver inner join do concluso
--       and concluso.ds_texto_final_interno ilike ANY (
--         ARRAY['Conclusos os autos para julgamento da ação incidental na execu__o%'
--              ,'Conclusos os autos para julgamento dos Embargos _ Execu__o%'
--              ,'Conclusos os autos para julgamento da Impugna__o _ Sentença de Liquida__o%']
--         )
     -- TODO: pensar sobre se é necessário já testar os movimentos aqui
--     AND EXISTS (
--         SELECT 1 FROM
--             tb_processo_evento pen
--         WHERE
--             pen.id_processo = doc.id_processo
--             AND pen.id_processo_evento_excludente IS NULL
--             and pen.id_evento IN (
--                 SELECT id_evento_processual FROM movimentos_julgado_incidentes_execucao
--             )
--             AND date(doc.dt_juntada) = date(pen.dt_atualizacao)
--             AND  pen.ds_texto_final_interno ilike ANY (
--                             ARRAY['%Impugnação à Sentença de Liquidação%',
-- 		                           '%Embargos à Execução%']
--             )
--     )

)
, processos_com_incidentes_assinados AS (
    SELECT edj.id_processo, edj.id_pessoa
    FROM incidentes_execucao_julgados edj
    GROUP BY edj.id_processo, edj.id_pessoa
)
, peticoes_incidentes_exec (id_processo, id_peticao, id_julgamento) AS (
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
                AND julgamento.id_processo_evento > pj.id_julgamento
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
, incidentes_julgados AS (
    SELECT incidentes_sem_alterada_peticao.id_processo,
           count(incidentes_sem_alterada_peticao.id_processo) AS numero_julgados,
           MAX(incidentes_sem_alterada_peticao.dt_j) AS data_ultimo_julgado
    FROM incidentes_sem_alterada_peticao
    WHERE incidentes_sem_alterada_peticao.dt_j::date BETWEEN
              COALESCE(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date
              AND
              COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
    GROUP BY incidentes_sem_alterada_peticao.id_processo, incidentes_sem_alterada_peticao.dt_j
)
, incidentes_por_magistrado AS (
    SELECT edj.id_pessoa,
           SUM(incidentes_julgados.numero_julgados) AS quantidade_julgado
    FROM processos_com_incidentes_assinados edj
             INNER JOIN incidentes_julgados ON (incidentes_julgados.id_processo = edj.id_processo)
    GROUP BY edj.id_pessoa
)
SELECT
    'TOTAL' AS "Magistrado",
    SUM(incidentes_julgados.numero_julgados) AS "Incidentes Julgados",
    '-' as "Ver Incidentes Julgados"
FROM incidentes_julgados
UNION ALL
(

    SELECT ul.ds_nome_consulta AS "Magistrado",
           incidentes_por_magistrado.quantidade_julgado AS "Incidentes Julgados"
            ,
           '$URL/execucao/T957?MAGISTRADO='||incidentes_por_magistrado.id_pessoa
               ||'&DATA_INICIAL_OPCIONAL='||to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date,'mm/dd/yyyy')
               ||'&DATA_OPCIONAL_FINAL='||to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date,'mm/dd/yyyy')
               ||'&texto='||incidentes_por_magistrado.quantidade_julgado as "Ver EDs Julgados"
    FROM incidentes_por_magistrado
             INNER JOIN tb_usuario_login ul ON (ul.id_usuario = incidentes_por_magistrado.id_pessoa)
    ORDER BY ul.ds_nome_consulta
)
