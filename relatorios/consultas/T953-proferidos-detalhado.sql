-- R136873 - Relatório SAO - SENTENÇAS DE CONHECIMENTO proferidas.
WITH proferidos AS (
SELECT  concluso.id_pessoa_magistrado AS id_usuario, 
        data_proferimento.data_proferida,
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
    INNER JOIN LATERAL (
        SELECT pe.dt_atualizacao AS data_proferida, ev.cd_evento FROM tb_processo_evento pe 
        INNER JOIN tb_evento_processual ev ON 
            (pe.id_evento = ev.id_evento_processual)
        WHERE pen.id_processo = pe.id_processo
        AND   pe.dt_atualizacao > pen.dt_atualizacao
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
                        pe.id_processo = reforma_anulacao.id_processo
                        AND reforma_anulacao.id_processo_evento_excludente IS NULL
                        AND reforma_anulacao.dt_atualizacao :: date BETWEEN 
                            (pe.dt_atualizacao)::date AND (:DATA_FINAL)::date
                        AND ev.cd_evento = '132' 
                        AND cs.ds_texto IN ('7098', '7131', '7132', '7467', '7585')
                )
            )
            -- nao existe um outro concluso mais recente, porem anterior ao movimento de julgamento
            OR
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
    ORDER BY pe.dt_atualizacao ASC LIMIT 1) data_proferimento ON TRUE

    WHERE
        concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
        AND data_proferimento.cd_evento NOT IN ('11022', '51')
        AND data_proferimento.data_proferida :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
        -- concluso.in_diligencia != 'S'
)
-- SELECT * FROM proferidos
 SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
         'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
        --  ||cj.ds_classe_judicial_sigla||' '
         ||p.nr_processo as "Processo",
ul.ds_nome AS "Magistrado",
prof.data_proferida AS "Proferida em"
FROM proferidos prof
INNER JOIN tb_processo p ON (prof.id_processo = p.id_processo)
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = prof.id_usuario)
ORDER BY ul.ds_nome, prof.data_proferida
