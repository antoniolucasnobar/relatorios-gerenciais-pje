-- Conclusos os autos para julgamento Proferir sentença a MARCELE CRUZ LANOT ANTONIAZZI
-- codigo 51

WITH conclusos AS (
SELECT  concluso.id_pessoa_magistrado, 
        pe.id_processo_evento,
        pe.dt_atualizacao,
        pe.id_processo
        -- COUNT(concluso.id_pessoa_magistrado) AS total
    FROM 
    tb_conclusao_magistrado concluso
    INNER JOIN tb_processo_evento pe 
    INNER JOIN tb_processo p on (p.id_processo = pe.id_processo)
    ON (pe.id_processo_evento = concluso.id_processo_evento 
        AND pe.id_processo_evento_excludente IS NULL
    	and pe.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
        AND pe.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
    WHERE
        -- concluso.in_diligencia != 'S'
        -- AND 
        p.id_agrupamento_fase = 2 -- somente conhecimento

)
SELECT ul.ds_nome AS "Magistrado", 
-- conclusos_por_magistrado.total,

conclusos_por_magistrado.pendentes_sentenca AS "Pendentes",
'$URL/execucao/T951?MAGISTRADO='||conclusos_por_magistrado.id_pessoa_magistrado as "Ver Pendentes"
-- conclusos_por_magistrado.total - conclusos_por_magistrado.pendentes_sentenca AS proferidas
FROM  (
    SELECT  conclusos.id_pessoa_magistrado, 
        -- COUNT(conclusos.id_pessoa_magistrado) AS total,
        COUNT(conclusos.id_pessoa_magistrado) FILTER
        (WHERE  NOT EXISTS(
                SELECT pe.id_processo FROM tb_processo_evento pe 
                INNER JOIN tb_evento_processual ev ON 
                    (pe.id_evento = ev.id_evento_processual)
                WHERE conclusos.id_processo = pe.id_processo
                AND pe.dt_atualizacao > conclusos.dt_atualizacao
                AND (ev.cd_evento IN 
                    ('941', '442', '450', '452', '444', 
                    '471', '446', '448', '455', '466', 
                    '11795', '220', '50103', '221', '219', 
                    '472', '473', '458', '461', '459', '465', 
                    '462', '463', '457', '460', '464', '454')
                OR
                    (
                        ev.cd_evento = '51' AND
                        pe.ds_texto_final_interno ilike 'Concluso%proferir senten_a%'
                    )    
                )    
            )
        ) AS pendentes_sentenca
    FROM conclusos
    GROUP BY conclusos.id_pessoa_magistrado
) conclusos_por_magistrado  
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = conclusos_por_magistrado.id_pessoa_magistrado)
ORDER BY ul.ds_nome
