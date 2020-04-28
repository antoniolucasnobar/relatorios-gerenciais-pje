
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cj.ds_classe_judicial_sigla||' '||p.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) AS "Unidade",
    fase.nm_agrupamento_fase as "Fase",
    pt.nm_tarefa as "Tarefa",
    pe.dt_atualizacao as "Data Protocolo"

FROM
    tb_processo_evento pe 
    INNER JOIN tb_evento_processual ev ON 
    -- codigo 26 - distribuido
        (pe.id_evento = ev.id_evento_processual AND ev.cd_evento = '26')
    inner join tb_processo p on p.id_processo = pe.id_processo
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo   
    join tb_orgao_julgador oj on (oj.id_orgao_julgador = ptrf.id_orgao_julgador)
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
    
WHERE 
    oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
    -- regra 1.a - antes de 2019
    AND pe.dt_atualizacao < '01/01/2019'::date
    AND (CASE
        -- regra 1.b - sem movimento de julgamento
        WHEN 
            NOT EXISTS(
                SELECT pe.id_processo FROM tb_processo_evento pe 
                INNER JOIN tb_evento_processual ev ON 
                    (pe.id_evento = ev.id_evento_processual)
                WHERE p.id_processo = pe.id_processo
                AND ev.cd_evento IN 
                    ('941', '442', '450', '452', '444', 
                    '471', '446', '448', '455', '466', 
                    '11795', '220', '50103', '221', '219', 
                    '472', '473', '458', '461', '459', '465', 
                    '462', '463', '457', '460', '464', '454')    
            ) 
            THEN TRUE
            -- regra 1.b EXCECAO: existe mov. julgamento, mas foi reformada ou anulada posteriormente
            ELSE 
                EXISTS (
                    SELECT pe2.id_processo FROM tb_processo_evento pe2
                    INNER JOIN tb_evento_processual ev ON 
                        (pe2.id_evento = ev.id_evento_processual)
                    WHERE p.id_processo = pe2.id_processo
                    AND ev.cd_evento IN ('132')
                    AND (pe2.ds_texto_final_interno ilike '%para novo julgamento (por reforma da decisão pela instância superior)'
                        OR pe2.ds_texto_final_interno ilike '%para novo julgamento (por anulação da decisão pela instância superior)'
                    ) 
                    AND pe2.dt_atualizacao > 
                        (
                            SELECT MAX(pe.dt_atualizacao) FROM tb_processo_evento pe 
                            INNER JOIN tb_evento_processual ev ON 
                                (pe.id_evento = ev.id_evento_processual)
                            WHERE p.id_processo = pe.id_processo
                            AND ev.cd_evento IN 
                                ('941', '442', '450', '452', '444', 
                                '471', '446', '448', '455', '466', 
                                '11795', '220', '50103', '221', '219', 
                                '472', '473', '458', '461', '459', '465', 
                                '462', '463', '457', '460', '464', '454')    
                        ) 
                )
            END
    )
    AND (CASE 
         WHEN
            -- regra 1.c - Não tem movimento de sobrestamento/suspensao,
            NOT EXISTS 
            (
                SELECT pe.id_processo FROM tb_processo_evento pe 
                INNER JOIN tb_evento_processual ev ON 
                    (pe.id_evento = ev.id_evento_processual)
                WHERE p.id_processo = pe.id_processo
                AND ev.cd_evento IN 
                    ('272', '275', '268', '12100', '50100', '898', 
                    '50092', '50135', '50136', '11975', '265', 
                    '50107', '11012', '11013', '11014', '11015')    
            )
        THEN TRUE
        ELSE
        -- regra 1.c - ou, se tiver, tem tambem o de encerramento posteriormente
         ( EXISTS 
            (
                SELECT pe2.id_processo FROM tb_processo_evento pe2
                INNER JOIN tb_evento_processual ev ON 
                    (pe2.id_evento = ev.id_evento_processual)
                WHERE p.id_processo = pe2.id_processo
                AND ev.cd_evento IN ('50054')
                AND pe2.dt_atualizacao >
                (
                    SELECT MAX(pe.dt_atualizacao) FROM tb_processo_evento pe 
                    INNER JOIN tb_evento_processual ev ON 
                        (pe.id_evento = ev.id_evento_processual)
                    WHERE p.id_processo = pe.id_processo
                    AND ev.cd_evento IN 
                        ('272', '275', '268', '12100', '50100', '898', 
                        '50092', '50135', '50136', '11975', '265', 
                        '50107', '11012', '11013', '11014', '11015') 
                )
            )
        )
        END
    )
        

