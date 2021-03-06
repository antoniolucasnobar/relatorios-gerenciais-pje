-- [R136875][T961] - EMBARGOS DECLARATÓRIOS JULGADOS
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
-- explain
WITH RECURSIVE
tipo_documento_sentenca AS (
    --62	Sentença	S			7007
    select id_tipo_processo_documento 
        from tb_tipo_processo_documento 
    where cd_documento = '7007' 
        and in_ativo = 'S'
),
movimentos_embargos_declaracao_julgados AS (
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
,
embargos_declaracao_julgados AS (
    select
        assin.id_pessoa,
        doc.dt_juntada,
        doc.id_processo
    from tb_processo_documento doc
             inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
             inner join lateral (
        select pen.ds_texto_final_interno, pen.dt_atualizacao FROM
            tb_conclusao_magistrado concluso
                INNER JOIN tb_processo_evento pen
                           ON (pen.id_processo_evento = concluso.id_processo_evento
                               and pen.id_processo = doc.id_processo
                               AND pen.id_processo_evento_excludente IS NULL
                               and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                               -- AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
                               )
        where pen.dt_atualizacao < doc.dt_juntada
        order by pen.dt_atualizacao desc
        limit 1
        ) concluso ON TRUE

    where doc.in_ativo = 'S'
      AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_sentenca)
      AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
      and doc.dt_juntada :: date between coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
      and concluso.ds_texto_final_interno ilike 'Conclusos os autos para % dos Embargos de Declara__o%'
)
, processos_com_eds_assinados AS (
    SELECT edj.id_processo, edj.id_pessoa
    FROM embargos_declaracao_julgados edj
    GROUP BY edj.id_processo, edj.id_pessoa
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
, eds_julgados AS (
    SELECT eds_sem_alterada_peticao.id_processo,
           count(eds_sem_alterada_peticao.id_processo) AS numero_julgados,
           eds_sem_alterada_peticao.dt_j AS data_ultimo_julgado
    FROM eds_sem_alterada_peticao
    WHERE eds_sem_alterada_peticao.dt_j::date BETWEEN
              COALESCE(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date
              AND
              COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
    GROUP BY eds_sem_alterada_peticao.id_processo, eds_sem_alterada_peticao.dt_j
)

SELECT
    'TOTAL' AS " ",
'-'  as "Processo",
'-'  AS "Unidade",
'-'  AS "Magistrado",
'-'  AS "Julgado em",
'-'  as "Tarefa Atual",
SUM(eds_julgados.numero_julgados)  AS "Quantidade",
'-'  as "Ver EDs Julgados do Processo"
FROM eds_julgados
UNION ALL
(
    SELECT 'http://processo=' || p.nr_processo || '&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
           'http://processo=' || p.nr_processo || '&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
--          ||cj.ds_classe_judicial_sigla||' '
            || p.nr_processo                                               as "Processo"
           , REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT')     AS "Unidade"
           , ul.ds_nome_consulta                                         AS "Magistrado"
           , to_char(eds_julgados.data_ultimo_julgado, 'dd/MM/yyyy')     AS "Julgado em"
           , pt.nm_tarefa                                                as "Tarefa Atual"
           , eds_julgados.numero_julgados                                AS "Quantidade"
            ,
           '$URL/execucao/T964?NUM_PROCESSO=' || p.nr_processo
               -- MAGISTRADO='||eds_julgados.id_pessoa
               || '&DATA_INICIAL_OPCIONAL=' ||
           to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date, 'mm/dd/yyyy')
               || '&DATA_OPCIONAL_FINAL=' || to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date, 'mm/dd/yyyy')
               || '&texto=' ||
           eds_julgados.numero_julgados                                 as "Ver EDs Julgados do Processo"
    FROM processos_com_eds_assinados
             INNER JOIN eds_julgados ON (eds_julgados.id_processo = processos_com_eds_assinados.id_processo)
             INNER JOIN tb_usuario_login ul on (ul.id_usuario = processos_com_eds_assinados.id_pessoa)
             INNER JOIN tb_processo p ON (p.id_processo = processos_com_eds_assinados.id_processo)
             inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
             inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
             INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
             inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    ORDER BY eds_julgados.data_ultimo_julgado::date, ul.ds_nome_consulta, p.nr_processo
)