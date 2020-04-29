-- Conclusos os autos para julgamento Proferir sentença a MARCELE CRUZ LANOT ANTONIAZZI
-- codigo 51

-- SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
-- ul.ds_nome, 
-- -- tipo_conclusao.*, 
-- pe.*  
WITH conclusos AS (
SELECT  concluso.id_pessoa_magistrado, 
        pe.id_processo_evento,
        pe.dt_atualizacao,
        pe.id_processo
        -- COUNT(concluso.id_pessoa_magistrado) AS total
    FROM 
    tb_conclusao_magistrado concluso
    -- INNER JOIN tb_tipo_conclusao_magistrado tipo_conclusao 
    --     ON (tipo_conclusao.id_tipo_conclusao_magistrado = concluso.id_tipo_conclusao_magistrado
    --         AND tipo_conclusao.in_ativo = 'S')
    INNER JOIN tb_processo_evento pe 
    ON (pe.id_processo_evento = concluso.id_processo_evento 
        AND pe.id_processo_evento_excludente IS NULL
        AND pe.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
    -- inner join tb_processo p on (p.id_processo = pe.id_processo)

)
SELECT ul.ds_nome, conclusos_por_magistrado.total,
conclusos_por_magistrado.pendentes_sentenca, 
conclusos_por_magistrado.total - conclusos_por_magistrado.pendentes_sentenca AS proferidas,
FROM  (
    SELECT  conclusos.id_pessoa_magistrado, 
        COUNT(conclusos.id_pessoa_magistrado) AS total,
        COUNT(conclusos.id_pessoa_magistrado) FILTER
        (WHERE  NOT EXISTS(
                SELECT pe.id_processo FROM tb_processo_evento pe 
                INNER JOIN tb_evento_processual ev ON 
                    (pe.id_evento = ev.id_evento_processual)
                WHERE conclusos.id_processo = pe.id_processo
                AND pe.dt_atualizacao > conclusos.dt_atualizacao
                AND ev.cd_evento IN 
                    ('941', '442', '450', '452', '444', 
                    '471', '446', '448', '455', '466', 
                    '11795', '220', '50103', '221', '219', 
                    '472', '473', '458', '461', '459', '465', 
                    '462', '463', '457', '460', '464', '454')    
            )
        ) AS pendentes_sentenca
    FROM conclusos
    GROUP BY conclusos.id_pessoa_magistrado
) conclusos_por_magistrado  
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = conclusos_por_magistrado.id_pessoa_magistrado)


-- FIM

SELECT ul.ds_nome, conclusos_por_magistrado.total
FROM
(
SELECT  concluso.id_pessoa_magistrado, 
        COUNT(concluso.id_pessoa_magistrado) AS total
    FROM 
    tb_conclusao_magistrado concluso
    -- INNER JOIN tb_tipo_conclusao_magistrado tipo_conclusao 
    --     ON (tipo_conclusao.id_tipo_conclusao_magistrado = concluso.id_tipo_conclusao_magistrado
    --         AND tipo_conclusao.in_ativo = 'S')
    INNER JOIN tb_processo_evento pe 
    ON (pe.id_processo_evento = concluso.id_processo_evento 
        AND pe.id_processo_evento_excludente IS NULL)
    inner join tb_processo p on (p.id_processo = pe.id_processo)

    GROUP BY concluso.id_pessoa_magistrado
) conclusos_por_magistrado  
    INNER JOIN tb_usuario_login ul ON (ul.id_usuario = conclusos_por_magistrado.id_pessoa_magistrado)



-- SELECT simples
SELECT concluso.*
FROM 
tb_tipo_conclusao_magistrado concluso
INNER JOIN tb_tipo_conclusao_magistrado tipo_conclusao 
    ON (tipo_conclusao.id_tipo_conclusao_magistrado = concluso.id_tipo_conclusao_magistrado
        AND tipo_conclusao.in_ativo = 'S')


