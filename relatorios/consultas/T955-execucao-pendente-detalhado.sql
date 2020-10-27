-- [R136877][T955] - Relatório SAO - INCIDENTES DE EXECUÇÃO PENDENTES
-- REGRAS NO T954

-- explain
WITH RECURSIVE
-- comentado pois jeferson falou que acontece da peticao estar classificada incorretamente.
-- tipos_documento AS (
--     --16	Embargos à Execução	S			7143
--     --32	Impugnação à Sentença de Liquidação	S			53
--     select id_tipo_processo_documento
--         from tb_tipo_processo_documento
--     where cd_documento IN ('53', '7143')
--         and in_ativo = 'S'
-- ) ,
    movimentos_julgado_incidentes_execucao AS (
        SELECT ev.id_evento_processual
        FROM tb_evento_processual ev
        WHERE
            -- eh movimento de julgamento
            -- 50086 - Encerrada a conclusão
            -- 219   - Julgado(s) procedente(s) o(s) pedido(s) (#{classe processual}/ #{nome do incidente}) de #{nome da parte}
            -- 221   - Julgado(s) procedente(s) em parte o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
            -- 220   - Julgado(s) improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
            -- 50013 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
            -- 50050 - Extinto com resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
            -- 50048 - Extinto sem resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
            -- 50087 - Baixado o incidente/ recurso (#{nome do incidente} / #{nome do recurso}) sem decisão, onde nome do recurso deve corresponder a Embargos à Execução ou Impugnação à Sentença de Liquidação
            -- 50049 - Prejudicado o incidente #{nome do incidente} de #{nome da parte}
            ev.cd_evento IN
            ('50086', '219', '221', '220', '50013', '50050', '50048', '50087', '50049')
    )
   , conclusos_incidentes_exec AS(
--     explain
    SELECT DISTINCT ON (mov_concluso.id_processo)
        concluso.id_pessoa_magistrado
                                                , mov_concluso.id_processo
                                                , mov_concluso.dt_atualizacao AS pendente_desde
    FROM
        tb_conclusao_magistrado concluso
            INNER JOIN tb_processo_evento mov_concluso
                       ON (mov_concluso.id_processo_evento = concluso.id_processo_evento
                           AND mov_concluso.id_processo_evento_excludente IS NULL
                           -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                           and mov_concluso.id_evento = 51
                           -- Conclusão do tipo "Julgamento da ação incidental"
                           AND (
                                       mov_concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da ação incidental na execu__o%'
                                   OR mov_concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento dos Embargos _ Execu__o%'
                                   OR mov_concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da Impugna__o _ Sentença de Liquida__o%'
                               )
                           )
    WHERE
            concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
      AND mov_concluso.dt_atualizacao::date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
      AND NOT EXISTS(
            select ev.cd_evento
            from
                tb_processo_evento arquivamento
                    join
                tb_evento_processual ev on (arquivamento.id_evento = ev.id_evento_processual)
            where
                    arquivamento.dt_atualizacao > mov_concluso.dt_atualizacao
              AND arquivamento.dt_atualizacao::date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
              -- 246 - definitvamente, 245 -- provisoriamente
              AND  ev.cd_evento IN ('246', '245')
              and arquivamento.id_processo_evento_excludente is null
              and arquivamento.id_processo = mov_concluso.id_processo
        )
      AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe
                              INNER JOIN tb_evento_processual ev ON
                (pe.id_evento = ev.id_evento_processual)
            WHERE mov_concluso.id_processo = pe.id_processo
              AND pe.id_processo_evento_excludente IS NULL
              AND (pe.dt_atualizacao > mov_concluso.dt_atualizacao
                -- OR
                -- pe.dt_atualizacao BETWEEN peticao.dt_juntada AND mov_concluso.dt_atualizacao
                )
              AND (
                (
                    -- eh movimento de julgamento
                    -- 50086 - Encerrada a conclusão
                    -- 219   - Julgado(s) procedente(s) o(s) pedido(s) (#{classe processual}/ #{nome do incidente}) de #{nome da parte}
                    -- 221   - Julgado(s) procedente(s) em parte o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
                    -- 220   - Julgado(s) improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
                    -- 50013 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
                    -- 50050 - Extinto com resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
                    -- 50048 - Extinto sem resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
                    -- 50087 - Baixado o incidente/ recurso (#{nome do incidente} / #{nome do recurso}) sem decisão, onde nome do recurso deve corresponder a Embargos à Execução ou Impugnação à Sentença de Liquidação
                    -- 50049 - Prejudicado o incidente #{nome do incidente} de #{nome da parte}
                            ev.cd_evento IN
                            ('50086', '219', '221', '220', '50013', '50050', '50048')
                        OR
                            (
                                --nome do complemento bate com o da conclusao
                                            ev.cd_evento = '50087' AND
                                            (mov_concluso.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%' and pe.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%')
                                    OR (mov_concluso.ds_texto_final_interno ilike '%Embargos à Execução%' and pe.ds_texto_final_interno ilike '%Embargos à Execução%')
                                    OR (mov_concluso.ds_texto_final_interno ilike 'Conclusos os autos para julgamento da ação incidental na execu__o%'
                                    and (pe.ds_texto_final_interno ilike '%Embargos à Execução%'
                                        OR pe.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%'
                                            )
                                                )
                                )
                        -- 50049 - Prejudicado o incidente #{nome do incidente} de #{nome da parte}
                        OR
                            (
                                --nome do complemento bate com o da conclusao
                                        ev.cd_evento = '50049' AND
                                        pe.ds_texto_final_interno ilike ANY
                                        (ARRAY['Prejudicado o incidente Impugnação à Sentença de Liquidação%',
                                            'Prejudicado o incidente Embargos à Execução%']
                                            )
                                )
                    )
                )
        )
    ORDER BY mov_concluso.id_processo, mov_concluso.dt_atualizacao DESC
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
            SELECT id_processo FROM conclusos_incidentes_exec
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
   , peticoes_pendentes AS (
    SELECT peticoes_incidentes_exec.* FROM peticoes_incidentes_exec
    WHERE peticoes_incidentes_exec.mov_julgamento IS NULL
)
   , incidentes_com_peticao AS (
    SELECT  edj.*
    FROM conclusos_incidentes_exec edj
    WHERE edj.id_processo IN (SELECT pe.id_processo FROM peticoes_pendentes pe)
)
 SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
        ||cj.ds_classe_judicial_sigla||' '
        ||p.nr_processo as "Processo",
        REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade",
ul.ds_nome AS "Magistrado",
-- incidentes.tipo_peticao
-- --||' - '|| incidentes.juntada_peticao
-- AS "Tipo Petição",
-- incidentes.juntada_peticao AS "Data Petição",
-- REGEXP_REPLACE(incidentes.nome_concluso,
-- 'Conclusos os autos para julgamento (da|dos) (.*) a (.*)'
-- ,'\2') AS "Conclusos os autos para julgamento",
incidentes.pendente_desde AS "Pendente Desde",
pt.nm_tarefa as "Tarefa Atual",
(select COALESCE(string_agg(prioridade.ds_prioridade::character varying, ', '), '-')
    from 
    tb_proc_prioridde_processo tabela_ligacao 
    inner join tb_prioridade_processo prioridade 
        on (tabela_ligacao.id_prioridade_processo = prioridade.id_prioridade_processo)
    where 
    tabela_ligacao.id_processo_trf = incidentes.id_processo
) AS "Prioridades"
,'$URL/execucao/T965?NUM_PROCESSO=' || p.nr_processo
               -- MAGISTRADO='||incidentes_julgados.id_pessoa
               || '&DATA_INICIAL_OPCIONAL=01/01/2011'
--                || to_char( date_trunc('year', current_date)::date, 'mm/dd/yyyy')
               || '&DATA_OPCIONAL_FINAL=' || to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date, 'mm/dd/yyyy')
    as "Ver Incidentes de Execução por Processo"
FROM incidentes_com_peticao incidentes
inner join tb_processo p on p.id_processo = incidentes.id_processo
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = incidentes.id_pessoa_magistrado)
inner join tb_processo_trf ptrf on ptrf.id_processo_trf = incidentes.id_processo
inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
inner join tb_processo_tarefa pt on pt.id_processo_trf = incidentes.id_processo
ORDER BY ul.ds_nome, incidentes.pendente_desde


