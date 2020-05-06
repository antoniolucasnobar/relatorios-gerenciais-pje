-- R136872 - Relatório SAO - SENTENÇAS DE CONHECIMENTO PENDENTES.
-- Conclusos os autos para julgamento Proferir sentença a MARCELE CRUZ LANOT ANTONIAZZI
-- codigo 51

WITH pendentes AS (
SELECT  concluso.id_pessoa_magistrado, 
        pen.id_processo_evento,
        pen.dt_atualizacao AS pendente_desde,
        p.id_processo,
        p.nr_processo
        -- COUNT(concluso.id_pessoa_magistrado) AS total
    FROM 
    tb_conclusao_magistrado concluso
    INNER JOIN tb_processo_evento pen 
    ON (pen.id_processo_evento = concluso.id_processo_evento 
        AND pen.id_processo_evento_excludente IS NULL
    	and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
        AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
    INNER JOIN tb_processo p on (p.id_processo = pen.id_processo)
    WHERE
        concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
        -- concluso.in_diligencia != 'S'
        AND p.id_agrupamento_fase = 2 -- somente conhecimento
        AND NOT EXISTS(
            SELECT 1 FROM tb_processo_evento pe 
            INNER JOIN tb_evento_processual ev ON 
                (pe.id_evento = ev.id_evento_processual)
            WHERE pen.id_processo = pe.id_processo
            AND pe.id_processo_evento_excludente IS NULL
            AND (
                (
                    -- eh movimento de julgamento
                    ev.cd_evento IN 
                    ('941', '442', '450', '452', '444', 
                    '471', '446', '448', '455', '466', 
                    '11795', '220', '50103', '221', '219', 
                    '472', '473', '458', '461', '459', '465', 
                    '462', '463', '457', '460', '464', '454'
                    )
                    -- sem movimento de reforma/anulacao posterior
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
                            AND ev.cd_evento = '132' 
                            AND cs.ds_texto IN ('7098', '7131', '7132', '7467', '7585')
                    )

                )
                OR
                (
                    pe.dt_atualizacao > pen.dt_atualizacao AND
                    (
                        -- Convertido o julgamento em dilig_ncia 
                        -- o movimento abaixo nao deve ser considerado para proferidas
                        ev.cd_evento = '11022'
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
-- conclusos_por_magistrado.total,

conclusos_por_magistrado.pendentes_sentenca AS "Pendentes",
'$URL/execucao/T951?MAGISTRADO='||conclusos_por_magistrado.id_pessoa_magistrado||'&texto='||conclusos_por_magistrado.pendentes_sentenca as "Ver Pendentes"
-- conclusos_por_magistrado.total - conclusos_por_magistrado.pendentes_sentenca AS proferidas
FROM  (
    SELECT  pendentes.id_pessoa_magistrado, 
        -- COUNT(pendentes.id_pessoa_magistrado) AS total,
        COUNT(pendentes.id_pessoa_magistrado) AS pendentes_sentenca
    FROM pendentes
    GROUP BY pendentes.id_pessoa_magistrado
) conclusos_por_magistrado  
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = conclusos_por_magistrado.id_pessoa_magistrado)
ORDER BY ul.ds_nome
