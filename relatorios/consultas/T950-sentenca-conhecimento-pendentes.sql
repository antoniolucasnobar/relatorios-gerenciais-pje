-- [R136872][T950] - Relatório SAO - SENTENÇAS DE CONHECIMENTO PENDENTES.

-- EXPLAIN ANALYZE
WITH sentencas_conhecimento_pendente AS (
SELECT  concluso.id_pessoa_magistrado,
        pen.id_processo_evento,
        pen.dt_atualizacao AS pendente_desde,
        p.id_processo,
        p.id_agrupamento_fase,
        p.nr_processo
    FROM
    tb_conclusao_magistrado concluso
    INNER JOIN tb_processo_evento pen
    ON (pen.id_processo_evento = concluso.id_processo_evento
        AND pen.id_processo_evento_excludente IS NULL
    	and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
        AND pen.ds_texto_final_interno ilike 'Concluso%julgamento%proferir senten_a%')
    INNER JOIN tb_processo p ON (p.id_processo = pen.id_processo)
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
    INNER JOIN tb_classe_judicial cj
        ON (cj.id_classe_judicial = ptrf.id_classe_judicial
            -- Segundo o e-Gestão, as classes da fase de CONHECIMENTO são essas:
            -- 45	Ação de Exigir Contas
            -- 32	Consignação em Pagamento
            -- 37	Embargos de Terceiro Cível
            -- 1709	Interdito Proibitório
            -- 40	Monitória
            -- 1707	Reintegração / Manutenção de Posse
            -- 46	Restauração de Autos
            -- 12374	Homologação da Transação Extrajudicial
            -- 12227	Interpelação
            -- 12226	Notificação
            -- 12228	Protesto
            -- 63	Ação Civil Coletiva
            -- 65	Ação Civil Pública Cível
            -- 74	Alvará Judicial - Lei 6858/80
            -- 1269	Habeas Corpus Cível
            -- 110	Habeas Data
            -- 120	Mandado de Segurança Cível
            -- 119	Mandado de Segurança Coletivo
            -- 980	Ação de Cumprimento
            -- 985	Ação Trabalhista - Rito Ordinário
            -- 1126	Ação Trabalhista - Rito Sumário (Alçada)
            -- 1125	Ação Trabalhista - Rito Sumaríssimo
            -- 986	Inquérito para apuração de falta grave
            -- 193	Produção Antecipada da Prova
            -- 241	Petição Cível
            -- 12135	Tutela Antecipada Antecedente
            -- 12134	Tutela Cautelar Antecedente
            -- 44	Prestação de Contas Oferecidas
            -- 1295	Alvará Judicial
            -- 178	Arresto
            -- 180	Atentado
            -- 181	Busca e Apreensão
            -- 182	Caução
            -- 183	Cautelar Inominada
            -- 186	Exibição
            -- 190	Justificação
            -- 196	Sequestro
            AND cj.cd_classe_judicial IN
                    ('45', '32', '37', '1709', '40', '1707',
                    '46', '12374', '12227', '12226', '12228',
                    '63', '65', '74', '1269', '110', '120', '119',
                    '980', '985', '1126', '1125', '986', '193',
                    '241', '12135', '12134', '44', '1295', '178',
                    '180', '181', '182', '183', '186', '190', '196')
        )
    WHERE
        concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
        AND
      pen.dt_atualizacao::date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
)
, sentencas_nao_solucionadas AS (
    SELECT p.*
    FROM sentencas_conhecimento_pendente p
    WHERE
        -- AND
        NOT EXISTS(
                SELECT 1
                FROM tb_processo_evento pe
                         INNER JOIN tb_evento_processual ev ON
                    (pe.id_evento = ev.id_evento_processual)
                WHERE p.id_processo = pe.id_processo
                  AND pe.dt_atualizacao:: date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
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
                                    NOT EXISTS(
                                            SELECT 1
                                            FROM tb_processo_evento reforma_anulacao
                                                     INNER JOIN tb_evento_processual ev
                                                                ON reforma_anulacao.id_evento = ev.id_evento_processual
                                                     INNER JOIN tb_complemento_segmentado cs
                                                                ON (cs.id_movimento_processo = reforma_anulacao.id_evento)
                                            WHERE p.id_processo = reforma_anulacao.id_processo
                                              AND reforma_anulacao.id_processo_evento_excludente IS NULL
                                              AND pe.dt_atualizacao <= reforma_anulacao.dt_atualizacao
                                              AND (
--                                                 - Recebidos os autos para novo julgamento (por reforma da decisão pela instância superior)
--                                                 - Recebidos os autos para novo julgamento (por necessidade de adequação ao sistema de precedente de recurso repetitivo)
--                                                 - Recebidos os autos para novo julgamento (por reforma da decisão da
--                                                     instância inferior)
--                                                 - Recebidos os autos para novo julgamento (por determinação superior para uniformização de jurisprudência)
                                                    (ev.cd_evento = '132'
                                                        AND cs.ds_texto IN ('7098', '7131', '7132', '7467', '7585')
                                                        )
                                                    OR
                                                    (
                                                        -- 157 -> 945 - Revogada a decisão anterior (#{tipo de decisão}))
                                                        -- 3   -> 190 - Reformada a decisão anterior (#{tipo de decisão})
                                                            ev.cd_evento IN ('945', '190')
                                                            AND reforma_anulacao.ds_texto_final_interno ilike
                                                                'Re%ada a decisão anterior%senten_a%'
                                                        )
                                                )
                                        )
                            )
                        OR
                        (
                                pe.dt_atualizacao > p.pendente_desde AND
                                (
                                    -- 941 - Declarada Incompetência
                                    -- 11022 - Convertido o julgamento em dilig_ncia
                                    -- TRANSITADO_EM_JULGADO ("848", "Transitado em julgado em #{data do trânsito}"),
                                    -- REDISTRIBUIDO ("36", "Redistribuído por #{tipo de redistribuição}  #{motivo da redistribuição}"),
                                    -- esses movimentos nao devem ser considerado para proferidas
                                        ev.cd_evento IN ('941', '11022', '848', '36')
                                        OR
                                        (
                                            -- teve um novo concluso pra sentenca
                                                ev.cd_evento = '51' AND
                                                pe.ds_texto_final_interno ilike 'Concluso%julgamento%proferir senten_a%'
                                            )
                                        OR
                                        (
                                            -- foi remetido ao 2 grau
                                                ev.cd_evento = '123' AND
                                                pe.ds_texto_final_interno ilike
                                                'Remetidos os autos para Órgão jurisdicional competente%para processar recurso'
                                            )
                                    )
                            )
                    )
            )
)
   , sentencas_no_conhecimento AS (
    SELECT p.* FROM
        sentencas_nao_solucionadas p
    WHERE
        -- AND

        (CASE
             WHEN :DATA_OPCIONAL_FINAL::date IS NULL
                 THEN p.id_agrupamento_fase = 2
             ELSE
                 (
                     SELECT (
                                (CASE
                                    -- CLE - Convertida a tramitação do processo do meio físico para o eletrônico
                                     WHEN ev.cd_evento = '50081'
                                         THEN
                                         EXISTS (
                                             -- So CLE criada no Conhecimento
                                                 select 1 from tb_processo_clet
                                                 where id_fase_processual_inicio_clet = 2
                                                   AND in_solucionado IS DISTINCT FROM 'S'
                                                   AND dt_sentenca IS NULL
                                                   AND id_processo_trf = pe.id_processo
                                             )
                                     ELSE ev.cd_evento IN ('50129', '26', '50128')
                                    END)
                                ) FROM tb_processo_evento pe
                                           INNER JOIN tb_evento_processual ev ON
                         (pe.id_evento = ev.id_evento_processual)
                     WHERE p.id_processo = pe.id_processo
                       AND pe.dt_atualizacao::date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
                       AND pe.id_processo_evento_excludente IS NULL
                       AND
                         (   ev.cd_evento IN
                             (
                                 -- DISTRIBUIDO_POR("26", "Distribuído por #{tipo de distribuição}"),
                                 -- ARQUIVADOS_OS_AUTOS_DEFINITIVAMENTE ("246", "Arquivados os autos definitivamente"),
                                 -- ARQUIVADOS_OS_AUTOS_PROVISORIAMENTE ("245", "Arquivados os autos provisoriamente"),
                                 -- CANCELADA_A_LIQUIDACAO("50129", "Cancelada a liquidação"),
                                 -- INICIADA_A_EXECUCAO ("11385", "Iniciada a execução #{tipo de execução}"),
                                 -- INICIADA_A_LIQUIDACAO ("11384", "Iniciada a liquidação #{tipo de liquidação}"),
                                 -- 50081 - CLE - Convertida a tramitação do processo do meio físico para o eletrônico
                              '50129', '11384', '11385', '246', '245', '26', '50081'
                                 )
                             OR
                             (
                                 -- foi cancelada a execucao e nao passou pela liq (se tem sentenca liquida).
                                 -- Nesse caso, volta direto para o Conhecimento
                                 -- CANCELADA_A_EXECUCAO("50128", "Cancelada a execução"),
                                         ev.cd_evento = '50128'
                                     AND NOT EXISTS(
                                         SELECT 1 FROM tb_processo_evento iniciada_liq
                                                           INNER JOIN tb_evento_processual ev
                                                                      ON (iniciada_liq.id_evento = ev.id_evento_processual)
                                         WHERE   iniciada_liq.id_processo = pe.id_processo
                                           AND iniciada_liq.dt_atualizacao < pe.dt_atualizacao
                                           AND ev.cd_evento = '11384'
                                     )
                                 )
                             )
                     ORDER BY pe.dt_atualizacao DESC
                     LIMIT 1
                 )
            END)
)
, sentencas_conhecimento_pendentes_por_magistrado AS (
    SELECT
        s.id_pessoa_magistrado,
        COUNT(s.id_pessoa_magistrado) AS pendentes_sentenca,
        MIN(s.pendente_desde) AS pendente_mais_antigo
    FROM sentencas_no_conhecimento s
    GROUP BY s.id_pessoa_magistrado
)
SELECT
    'TOTAL' AS "Magistrado"
    , SUM(sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca) AS "Sentenças de conhecimento pendentes"
    , MIN(pendente_mais_antigo) - interval '1 milliseconds' AS "Sentenças - conclusão mais antiga"
    , '-' as "Ver Pendentes"
FROM sentencas_conhecimento_pendentes_por_magistrado
UNION ALL
(
SELECT
-- sentencas_conhecimento_pendentes_por_magistrado.total,
ul.ds_nome AS "Magistrado"
,sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca AS "Pendentes"
, sentencas_conhecimento_pendentes_por_magistrado.pendente_mais_antigo AS "Sentença pendente mais antiga"
,'$URL/execucao/T951?MAGISTRADO='
||sentencas_conhecimento_pendentes_por_magistrado.id_pessoa_magistrado
||
CASE
    WHEN :DATA_OPCIONAL_FINAL::date IS NULL
    THEN ''
    ELSE '&DATA_OPCIONAL_FINAL='||to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date,'mm/dd/yyyy')
END
||'&texto='||sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca as "Ver Pendentes"
FROM  sentencas_conhecimento_pendentes_por_magistrado
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = sentencas_conhecimento_pendentes_por_magistrado.id_pessoa_magistrado)
ORDER BY ul.ds_nome
)
