(CASE
        WHEN exists (
            SELECT 1 FROM tb_processo_evento pe 
                INNER JOIN tb_evento_processual ev ON 
                    (pe.id_evento = ev.id_evento_processual)
                WHERE p.id_processo = pe.id_processo
                AND pe.id_processo_evento_excludente IS NULL
                AND ev.cd_evento IN 
                    ('941', '442', '450', '452', '444', 
                    '471', '446', '448', '455', '466', 
                    '11795', '220', '50103', '221', '219', 
                    '472', '473', '458', '461', '459', '465', 
                    '462', '463', '457', '460', '464', '454') 
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
         THEN 'Sim'
        ELSE 'Não'
    end) AS "Solucionado"