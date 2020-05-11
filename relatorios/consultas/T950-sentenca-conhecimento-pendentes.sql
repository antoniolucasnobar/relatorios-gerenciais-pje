-- R136872 - Relatório SAO - SENTENÇAS DE CONHECIMENTO PENDENTES.


WITH sentencas_conhecimento_pendente AS (
SELECT  concluso.id_pessoa_magistrado, 
        pen.id_processo_evento,
        pen.dt_atualizacao AS pendente_desde,
        p.id_processo,
        p.nr_processo
    FROM 
    tb_conclusao_magistrado concluso
    INNER JOIN tb_processo_evento pen 
    ON (pen.id_processo_evento = concluso.id_processo_evento 
        AND pen.id_processo_evento_excludente IS NULL
    	and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
        AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
    INNER JOIN tb_processo p ON (p.id_processo = pen.id_processo)
    WHERE
        concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
        -- AND p.id_agrupamento_fase = 2  -- nao da pra usar a faase, pq tem de ver a situacao do processo na data escolhida pelo usuario.
        -- somente conhecimento -sub-consulta abaixo
        AND (
        SELECT (ev.cd_evento IN ('50129', '26')) FROM tb_processo_evento pe 
            INNER JOIN tb_evento_processual ev ON 
                (pe.id_evento = ev.id_evento_processual)
            WHERE pen.id_processo = pe.id_processo
                AND pe.dt_atualizacao::date <= (:DATA_FINAL)::date
                AND pe.id_processo_evento_excludente IS NULL
                AND ev.cd_evento IN 
                    (
                        -- DISTRIBUIDO_POR("26", "Distribuído por #{tipo de distribuição}"),
                        -- ARQUIVADOS_OS_AUTOS_DEFINITIVAMENTE ("246", "Arquivados os autos definitivamente"),
                        -- CANCELADA_A_LIQUIDACAO("50129", "Cancelada a liquidação"),
                        -- INICIADA_A_EXECUCAO ("11385", "Iniciada a execução #{tipo de execução}"),
                        -- INICIADA_A_LIQUIDACAO ("11384", "Iniciada a liquidação #{tipo de liquidação}"),
                        '50129', '26', '11384', '11385', '246'
                    )
                ORDER BY pe.dt_atualizacao DESC
                LIMIT 1
        )
        AND pen.dt_atualizacao::date <= (:DATA_FINAL)::date
        AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe 
            INNER JOIN tb_evento_processual ev ON 
                (pe.id_evento = ev.id_evento_processual)
            WHERE pen.id_processo = pe.id_processo
            AND pe.dt_atualizacao:: date <= (:DATA_FINAL)::date
            AND pe.id_processo_evento_excludente IS NULL
            AND (
                (
            --         -- eh movimento de julgamento
                    ev.cd_evento IN 
                    (
                    '442', '450', '452', '444', 
                    '471', '446', '448', '455', '466', 
                    '11795', '220', '50103', '221', '219', 
                    '472', '473', '458', '461', '459', '465', 
                    '462', '463', '457', '460', '464', '454'
                    )
                    -- sem movimento de revogação/reforma/anulacao posterior
                    AND 
                    NOT EXISTS (
                        SELECT 1 FROM 
                        tb_processo_evento reforma_anulacao
                        INNER JOIN tb_evento_processual ev 
                            ON reforma_anulacao.id_evento = ev.id_evento_processual
                        INNER JOIN tb_complemento_segmentado cs 
                            ON (cs.id_movimento_processo = reforma_anulacao.id_evento)
                        WHERE
                            p.id_processo = reforma_anulacao.id_processo
                            AND reforma_anulacao.id_processo_evento_excludente IS NULL
                            AND pe.dt_atualizacao <= reforma_anulacao.dt_atualizacao
                            AND (
                                -- - Recebidos os autos para novo julgamento (por reforma da decisão pela instância superior)
                                -- - Recebidos os autos para novo julgamento (por necessidade de adequação ao sistema de precedente de recurso repetitivo)
                                -- - Recebidos os autospara novo julgamento (por reforma da decisão da instância inferior)
                                -- - Recebidos os autos para novo julgamento (por determinação superior para uniformização de jurisprudência)
                                (ev.cd_evento = '132' 
                                    AND cs.ds_texto IN ('7098', '7131', '7132', '7467', '7585')
                                )
                                OR
                                (
                                    -- 157 -> 945 - Revogada a decisão anterior (#{tipo de decisão}))
                                    -- 3   -> 190 - Reformada a decisão anterior (#{tipo de decisão})
                                   ev.cd_evento IN ('945', '190')
                                   AND reforma_anulacao.ds_texto_final_interno ilike 'Re%ada a decisão anterior%senten_a%'  
                                )
                                
                            )
                    )

                )
                OR
                (
                    pe.dt_atualizacao > pen.dt_atualizacao AND
                    (
                        -- 941 - Declarada Incompetência
                        -- 11022 - Convertido o julgamento em dilig_ncia 
                        -- esses movimentos nao devem ser considerado para proferidas
                        ev.cd_evento IN ('941', '11022')
                        OR
                            (
                                -- teve um novo concluso pra sentenca
                                ev.cd_evento = '51' AND
                                pe.ds_texto_final_interno ilike 'Concluso%proferir senten_a%'
                            )
                    )    
                )
            ) 
        )
)
SELECT ul.ds_nome AS "Magistrado", 
sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca AS "Pendentes",
'$URL/execucao/T951?MAGISTRADO='
||sentencas_conhecimento_pendentes_por_magistrado.id_pessoa_magistrado
||'&DATA_FINAL='||to_char(:DATA_FINAL::date,'mm/dd/yyyy')
||'&texto='||sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca as "Ver Pendentes"
FROM  (
    SELECT  sentencas_conhecimento_pendente.id_pessoa_magistrado, 
        COUNT(sentencas_conhecimento_pendente.id_pessoa_magistrado) AS pendentes_sentenca
    FROM sentencas_conhecimento_pendente
    GROUP BY sentencas_conhecimento_pendente.id_pessoa_magistrado
) sentencas_conhecimento_pendentes_por_magistrado  
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = sentencas_conhecimento_pendentes_por_magistrado.id_pessoa_magistrado)
ORDER BY ul.ds_nome
