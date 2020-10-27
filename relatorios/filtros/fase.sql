-- adicionar como coluna
    fase.nm_agrupamento_fase as "Fase",
    -- fase com tarefa
    substring(UPPER(TRIM(fase.nm_agrupamento_fase)) FROM 0 FOR 4) || ' / ' || -- as "Fase",
                pe.name_ as "Fase / Tarefa Atual"  
    
substring(UPPER(TRIM(fase.nm_agrupamento_fase)) FROM 0 FOR 4) || ' / ' || 
                ptar.nm_tarefa as "Fase / Tarefa Atual"  
-- JOIN
    -- tb_processo p
    inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
-- adicionar como filtro
    AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)


    select * from tb_agrupamento_fase;
        tb_processo where nr_processo= '0021353-19.2017.5.04.0405'







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
   , peticoes_julgamentos (id_peticao, id_julgamento) AS (
    (
        SELECT ed.id_processo_evento AS id_peticao
--                ,ed.dt_atualizacao AS data_ed
               ,julgamento.id_j AS id_julgamento
--                ,julgamento.dt_j
--                ,julgamento.tx_j
        FROM tb_processo_evento ed
                 LEFT JOIN LATERAL (
            SELECT julgamento.id_processo_evento AS id_j,
                   julgamento.dt_atualizacao     as dt_j,
                   julgamento
                       .ds_texto_final_externo   as tx_j
            FROM tb_processo_evento julgamento
            WHERE julgamento.dt_atualizacao > ed.dt_atualizacao
              AND julgamento.id_processo = ed.id_processo
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
                         ilike 'Alterado o tipo de peti__o de Embargos de Declara__o%'
                        )
                )

            ORDER BY julgamento.dt_atualizacao ASC
            LIMIT 1
            ) julgamento
                           ON TRUE
        WHERE ed.id_processo = 807712
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
        ORDER BY ed.dt_atualizacao ASC
        LIMIT 1
    )
    UNION
    (
        SELECT ed.id_processo_evento
--                ,ed.dt_atualizacao AS data_ed
             ,julgamento.id_j
--                ,julgamento.dt_j
--                ,julgamento.tx_j
        FROM tb_processo_evento ed
                 LEFT JOIN LATERAL (
            SELECT julgamento.id_processo_evento AS id_j,
                   julgamento.dt_atualizacao     as dt_j,
                   julgamento
                       .ds_texto_final_externo   as tx_j
            FROM tb_processo_evento julgamento
            WHERE julgamento.dt_atualizacao > ed.dt_atualizacao
              AND julgamento.id_processo_evento > id_julgamento
              AND julgamento.id_processo = ed.id_processo
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
                         ilike 'Alterado o tipo de peti__o de Embargos de Declara__o%'
                        )
                )

            ORDER BY julgamento.dt_atualizacao ASC
            LIMIT 1
            ) julgamento
                           ON TRUE
        WHERE ed.id_processo = 807712
          AND ed.id_processo_evento > id_peticao
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
        ORDER BY ed.dt_atualizacao ASC
        LIMIT 1
    )
)
SELECT *
FROM peticoes_julgamentos


