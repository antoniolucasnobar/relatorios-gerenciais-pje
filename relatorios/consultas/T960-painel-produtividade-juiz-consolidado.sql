-- [T960] Painel de Produtividade e Pendências
-- explain analyze
-- EXPLAIN
WITH RECURSIVE
-- T950
     sentencas_conhecimento_pendente AS (
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

-- T952
, sentencas_conhecimento_proferidas AS (
    select
        assin.id_pessoa,
        doc.dt_juntada,
        doc.id_processo,
        doc.id_tipo_processo_documento
    from tb_processo_documento doc
             inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
    where doc.in_ativo = 'S'
      -- 93	Ata da Audiência	S			7298
      -- 62	Sentença	S			7007
      -- 64	Decisão	S			7001
      AND doc.id_tipo_processo_documento IN (62, 64, 93)
      AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
      -- and tipo.cd_documento = '7007'
      and doc.dt_juntada :: date between coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
      --  nao pode ter "Extinta a execução ou o cumprimento da sentença por ..." lancado junto com a sentenca
      and not exists
        (
            select 1 from tb_processo_evento extinta_execucao
                              INNER JOIN tb_evento_processual ev ON
                (extinta_execucao.id_evento = ev.id_evento_processual)
            WHERE
                    extinta_execucao.id_processo = doc.id_processo
              AND extinta_execucao.dt_atualizacao BETWEEN
                    doc.dt_juntada - ('5 minutes')::interval
                AND doc.dt_juntada + ('5 minutes')::interval
              -- 473 - Arquivado o processo por ausência do reclamante
              -- 472 - Arquivado o processo (Sumaríssimo - art. 852-B, § 1º, CLT)
              -- 463 - Extinto o processo por homologação de desistência
              -- 941 - Declarada Incompetência -
              -- 196 - Extinta a execução ou o cumprimento da sentença por #{motivo da extinção}
              AND ev.cd_evento IN
                  (
                   '196', '473', '472', '463', '941'
                      )


        )
)
   , sentencas_acordos_conhecimento_por_magistrado AS (
    SELECT  sentencas_conhecimento_proferidas.id_pessoa,
            COUNT(sentencas_conhecimento_proferidas.id_pessoa)
            FILTER
                (
                WHERE
                EXISTS (
                        SELECT 1 FROM tb_processo_evento julgamento
                                          INNER JOIN tb_evento_processual ev ON
                            (julgamento.id_evento = ev.id_evento_processual)
                                          INNER JOIN tb_processo_trf ptrf ON ptrf.id_processo_trf = julgamento.id_processo
                                          INNER JOIN tb_classe_judicial cj
                                                     ON (cj.id_classe_judicial = ptrf.id_classe_judicial
                                                         -- 116	Execução Fiscal
                                                         -- 991	Execução de Termo de Ajuste de Conduta
                                                         -- 992	Execução de Termo de Conciliação de CCP
                                                         -- 990	Execução de Título Extrajudicial
                                                         -- 993	Execução de Certidão de Crédito Judicial
                                                         -- 994	Execução provisória em Autos Suplementares
                                                         -- 156	Cumprimento de Sentença
                                                         AND cj.cd_classe_judicial NOT IN
                                                             ('116', '991', '992', '990', '993', '994', '156')
                                                         )
                        WHERE
                                julgamento.id_processo = sentencas_conhecimento_proferidas.id_processo
                          AND julgamento.dt_atualizacao BETWEEN
                                sentencas_conhecimento_proferidas.dt_juntada - ('5 minutes')::interval
                            AND sentencas_conhecimento_proferidas.dt_juntada + ('5 minutes')::interval
                          AND ev.cd_evento IN
                            -- 442 - Concedida a segurança a "nome da parte"
                            -- 450 - Concedida em parte a segurança a "nome da parte"
                            -- 452 - Concedido em parte o Habeas Data a "nome da parte"
                            -- 444 - Concedido o Habeas Data a "nome da parte"
                            -- 471 - Declarada a decadência ou prescrição
                            -- 446 - Denegada a segurança a "nome da parte"
                            -- 448 - Denegado o Habeas Data a "nome da parte"
                            -- 455 - Homologada a renúncia pelo autor
                            -- 11795 - Homologado o reconhecimento da procedência do(s) pedido(s) de "nome da parte"
                            -- 220 - Julgado(s) improcedente(s) o(s) pedido(s) ("classe processual" / "nome do incidente") de "nome da parte"
                            -- 50103 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) ("classe processual" / "nome do incidente") de "nome da parte"
                            -- 221 - Julgado(s) procedente(s) em parte o(s) pedido(s) ("classe processual" / "nome do incidente") de "nome da parte"
                            -- 219 - Julgado(s) procedente(s) o(s) pedido(s) ("classe processual" / "nome do incidente") de "nome da parte"
                            -- 458 -  Extinto o processo por abandono da causa pelo autor
                            -- 461 -  Extinto o processo por ausência de legitimidade ou de interesse processual
                            -- 459 -  Extinto o processo por ausência de pressupostos processuais
                            -- 465 -  Extinto o processo por confusão entre autor e o réu
                            -- 462 -  Extinto o processo por convenção de arbitragem
                            -- 457 -  Extinto o processo por negligência das partes
                            -- 460 -  Extinto o processo por perempção, litispendência ou coisa julgada
                            -- 464 -  Extinto o processo por ser a ação intransmissível
                            -- 454 - Indeferida a petição inicial                        (
                              (
                               '442', '450', '452', '444',
                               '471', '446', '448', '455',
                               '11795', '220', '50103', '221', '219',
                               '458', '461', '459', '465',
                               '462', '457', '460', '464', '454'
                                  )
                    )
                ) AS sentencas_conhecimento,
            COUNT(sentencas_conhecimento_proferidas.id_pessoa)
            FILTER
                (
                WHERE EXISTS (
                    SELECT 1 FROM tb_processo_evento acordo
                    WHERE acordo.id_processo = sentencas_conhecimento_proferidas.id_processo
                      AND acordo.dt_atualizacao BETWEEN
                            sentencas_conhecimento_proferidas.dt_juntada - ('5 minutes')::interval
                        AND sentencas_conhecimento_proferidas.dt_juntada + ('5 minutes')::interval
                      -- 377, Homologado o acordo em execução ou em cumprimento de sentença (valor do acordo: 1000,00)
                      -- 466, Homologada a transação
                      AND acordo.id_evento IN (377, 466)
                )
                ) AS acordos_conhecimento
    FROM sentencas_conhecimento_proferidas
    GROUP BY sentencas_conhecimento_proferidas.id_pessoa
)
-- ,
-- -- T954
   , movimentos_retiram_pendencia_incidentes_execucao AS (
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
   , peticoes_pendentes_incidentes_exec (id_processo, id_peticao, id_julgamento, julgamentos_efetuados) AS (
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
                                 FROM movimentos_retiram_pendencia_incidentes_execucao
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
        FROM peticoes_pendentes_incidentes_exec pj
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
                                 FROM movimentos_retiram_pendencia_incidentes_execucao
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
   , peticoes_execucao_pendentes AS (
    SELECT peticoes_pendentes_incidentes_exec.* FROM peticoes_pendentes_incidentes_exec
    WHERE peticoes_pendentes_incidentes_exec.mov_julgamento IS NULL
)
   , incidentes_exec_pendentes_por_magistrado AS (
    SELECT  edj.id_pessoa_magistrado,
            COUNT(edj.id_pessoa_magistrado) AS quantidade,
            MIN(edj.pendente_desde) AS pendente_mais_antigo
    FROM conclusos_incidentes_exec edj
    WHERE edj.id_processo IN (SELECT pe.id_processo FROM peticoes_execucao_pendentes pe)
    GROUP BY edj.id_pessoa_magistrado
)


-- -- T956
   , movimentos_julgado_incidentes_execucao AS (
    SELECT ev.id_evento_processual
    FROM tb_evento_processual ev
    WHERE
        -- eh movimento de julgamento
        -- 219   - Julgado(s) procedente(s) o(s) pedido(s) (#{classe processual}/ #{nome do incidente}) de #{nome da parte}
        -- 221   - Julgado(s) procedente(s) em parte o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
        -- 220   - Julgado(s) improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
        -- 50013 - Julgado(s) liminarmente improcedente(s) o(s) pedido(s) (#{classe processual} / #{nome do incidente}) de #{nome da parte}
        -- 50050 - Extinto com resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
        -- 50048 - Extinto sem resolução do mérito o incidente #{nome do incidente} de #{nome da parte}
        ev.cd_evento IN
        ('219', '221', '220', '50013', '50050', '50048')
)
   , incidentes_execucao_julgados AS (
        select
            assin.id_pessoa,
            doc.dt_juntada,
            doc.id_processo
        from tb_processo_documento doc
                 inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
-- retirando o concluso a pedido de Jeferson, pois o Qliq so considera a peticao e o movimento de julgamento
--           inner join lateral (
--             select pen.ds_texto_final_interno, pen.dt_atualizacao FROM
--              tb_conclusao_magistrado concluso
--                  INNER JOIN tb_processo_evento pen
--                         ON (pen.id_processo_evento = concluso.id_processo_evento
--                             and pen.id_processo = doc.id_processo
--                             AND pen.id_processo_evento_excludente IS NULL
--                             and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
--                             )
--              where pen.dt_atualizacao < doc.dt_juntada
--              order by pen.dt_atualizacao desc
--              limit 1
--           ) concluso ON TRUE
--         INNER JOIN tb_processo_evento iniciada_execucao
--             ON (iniciada_execucao.id_processo = doc.id_processo
--             AND iniciada_execucao.id_evento = 11385)
--             -- TODO: ver quais outros movimentos que deixam o processo na
--             -- execução, como por exemplo desarquivar
--             -- TODO: ver tb que pode ter mais de um mov. de iniciada a execução
        where doc.in_ativo = 'S'
          -- 62 -- sentenca
          AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_sentenca)

          AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
          -- so pega documentos juntados depois do inicio da execucao
--       and doc.dt_juntada :: date between GREATEST(iniciada_execucao.dt_atualizacao, coalesce(: DATA_INICIAL_OPCIONAL,
--              date_trunc('month', current_date))::date)::date and (coalesce(: DATA_OPCIONAL_FINAL, current_date))
--              ::date
          and doc.dt_juntada :: date between
            coalesce(:DATA_INICIAL_OPCIONAL,date_trunc('month', current_date))::date
            and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
-- ver inner join do concluso
--       and concluso.ds_texto_final_interno ilike ANY (
--         ARRAY['Conclusos os autos para julgamento da ação incidental na execu__o%'
--              ,'Conclusos os autos para julgamento dos Embargos _ Execu__o%'
--              ,'Conclusos os autos para julgamento da Impugna__o _ Sentença de Liquida__o%']
--         )
        -- TODO: pensar sobre se é necessário já testar os movimentos aqui
--     AND EXISTS (
--         SELECT 1 FROM
--             tb_processo_evento pen
--         WHERE
--             pen.id_processo = doc.id_processo
--             AND pen.id_processo_evento_excludente IS NULL
--             and pen.id_evento IN (
--                 SELECT id_evento_processual FROM movimentos_julgado_incidentes_execucao
--             )
--             AND date(doc.dt_juntada) = date(pen.dt_atualizacao)
--             AND  pen.ds_texto_final_interno ilike ANY (
--                             ARRAY['%Impugnação à Sentença de Liquidação%',
-- 		                           '%Embargos à Execução%']
--             )
--     )

    )
   , processos_com_incidentes_assinados AS (
    SELECT edj.id_processo, edj.id_pessoa
    FROM incidentes_execucao_julgados edj
    GROUP BY edj.id_processo, edj.id_pessoa
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
            SELECT id_processo FROM processos_com_incidentes_assinados
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
   , incidentes_sem_alterada_peticao AS (
    SELECT peticoes_incidentes_exec.* FROM peticoes_incidentes_exec
    WHERE peticoes_incidentes_exec.mov_julgamento IS DISTINCT FROM 50088
)
   , incidentes_execucao_julgados_no_periodo AS (
    SELECT incidentes_sem_alterada_peticao.id_processo,
           count(incidentes_sem_alterada_peticao.id_processo) AS numero_julgados,
           incidentes_sem_alterada_peticao.dt_j AS data_ultimo_julgado
    FROM incidentes_sem_alterada_peticao
    WHERE incidentes_sem_alterada_peticao.dt_j::date BETWEEN
              COALESCE(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date
              AND
              COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
    GROUP BY incidentes_sem_alterada_peticao.id_processo, incidentes_sem_alterada_peticao.dt_j
)
   , incidentes_execucao_julgados_por_magistrado AS (
    SELECT edj.id_pessoa,
           SUM(incidentes_execucao_julgados_no_periodo.numero_julgados) AS quantidade_julgado
    FROM processos_com_incidentes_assinados edj
             INNER JOIN incidentes_execucao_julgados_no_periodo ON (incidentes_execucao_julgados_no_periodo.id_processo = edj.id_processo)
    GROUP BY edj.id_pessoa
)

-- -- T958
,tipo_documento_embargo_declaracao AS (
    --23	Embargos de Declaração	S			49
    select id_tipo_processo_documento
    from tb_tipo_processo_documento
    where cd_documento = '49'
      and in_ativo = 'S'
),
    pendentes_embargos_declaratorio AS (
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
                               -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                               and pen.id_evento = 51
                               -- Conclusão do tipo "Julgamento dos Embargos de Declara__o"
                               AND
                               pen.ds_texto_final_interno ilike
                               'Conclusos os autos para%dos Embargos de Declara__o%'
                               AND pen.dt_atualizacao::date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
                               )
                INNER JOIN tb_processo p on (p.id_processo = pen.id_processo)
                INNER JOIN LATERAL (
                SELECT doc.dt_juntada FROM tb_processo_documento doc WHERE
                        doc.id_processo = pen.id_processo
                                                                       AND doc.dt_juntada < pen.dt_atualizacao
                                                                       AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_embargo_declaracao)
                                                                       -- nao existe movimento de julgamento entre a peticao e a conclusao
                                                                       AND NOT EXISTS(
                            SELECT 1 FROM tb_processo_evento pe
                                              INNER JOIN tb_evento_processual ev ON
                                (pe.id_evento = ev.id_evento_processual)
                            WHERE pen.id_processo = pe.id_processo
                              AND pe.id_processo_evento_excludente IS NULL
                              AND pe.dt_atualizacao BETWEEN
                                doc.dt_juntada AND pen.dt_atualizacao
                              AND
                                (
                                    -- NÃO Existir um movimento dentre os seguintes,
                                    --  entre a data de juntada da peticao e o concluso
                                    -- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}
                                    -- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}
                                    -- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}
                                    -- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa}
                                    -- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}
                                    (
                                        --nome do complemento bate com Embargos de Declara__o%
                                                ev.cd_evento IN ('198', '871', '200', '235', '230') AND
                                                pe.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                                        )
                                    )
                        )
                ORDER BY doc.dt_juntada DESC LIMIT 1
                ) peticao ON TRUE -- //ver comentario na definicao do tipo_documento_embargo_declaracao
        WHERE
                p.id_agrupamento_fase <> 5
          AND concluso.id_pessoa_magistrado  = coalesce(:MAGISTRADO, concluso.id_pessoa_magistrado)
          AND NOT EXISTS(
                SELECT 1 FROM tb_processo_evento pe
                                  INNER JOIN tb_evento_processual ev ON
                    (pe.id_evento = ev.id_evento_processual)
                WHERE pen.id_processo = pe.id_processo
                  AND pe.id_processo_evento_excludente IS NULL
                  AND pe.dt_atualizacao:: date <= (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
                  AND pe.dt_atualizacao > pen.dt_atualizacao
                  AND
                    (
                        -- NÃO Existir um movimento dentre os seguintes, após o concluso
                        -- 50086 - Encerrada a conclusão
                        -- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}
                        -- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}
                        -- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}
                        -- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa}
                        -- 230 - Prejudicado(s) o(s) #{nome do recurso} de #{nome da parte}
                                ev.cd_evento = '50086'
                            OR
                                (
                                    --nome do complemento bate com Embargos de Declara__o%
                                            ev.cd_evento IN ('198', '871', '200', '235', '230') AND
                                            pe.ds_texto_final_interno ilike '%Embargos de Declara__o%'
                                    )
                            OR
                                (
                                            ev.cd_evento = '51'AND
                                            pe.ds_texto_final_interno ilike
                                            'Conclusos os autos para%dos Embargos de Declara__o%'
                                    )
                            OR
                                ( -- houve alteração do tipo de petição
                                            ev.cd_evento = '50088'AND
                                            pe.ds_texto_final_interno ilike
                                            'Alterado o tipo de petição de Embargos de Declara__o%'
                                    )
                        )
            )
    )
   , eds_pendentes_por_magistrado AS (
    SELECT  pendentes_embargos_declaratorio.id_pessoa_magistrado,
            COUNT(pendentes_embargos_declaratorio.id_pessoa_magistrado) AS pendentes_embargo,
            MIN(pendentes_embargos_declaratorio.pendente_desde) AS pendente_mais_antigo
    FROM pendentes_embargos_declaratorio
    GROUP BY pendentes_embargos_declaratorio.id_pessoa_magistrado
)

-- -- T963
, tipo_documento_sentenca AS (
    --62	Sentença	S			7007
    select id_tipo_processo_documento
    from tb_tipo_processo_documento
    where cd_documento = '7007'
      and in_ativo = 'S'
),
    movimentos_embargos_declaracao_julgados AS (
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
   ,
    embargos_declaracao_julgados AS (
        select
            assin.id_pessoa,
            doc.dt_juntada,
            doc.id_processo
        from tb_processo_documento doc
                 inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
                 inner join lateral (
            select pen.ds_texto_final_interno, pen.dt_atualizacao FROM
                tb_conclusao_magistrado concluso
                    INNER JOIN tb_processo_evento pen
                               ON (pen.id_processo_evento = concluso.id_processo_evento
                                   and pen.id_processo = doc.id_processo
                                   AND pen.id_processo_evento_excludente IS NULL
                                   and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                                   )
            where pen.dt_atualizacao < doc.dt_juntada
            order by pen.dt_atualizacao desc
            limit 1
            ) concluso ON TRUE

        where doc.in_ativo = 'S'
          AND doc.id_tipo_processo_documento IN (SELECT id_tipo_processo_documento FROM tipo_documento_sentenca)
          AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
          and doc.dt_juntada :: date between coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
          and concluso.ds_texto_final_interno ilike 'Conclusos os autos para % dos Embargos de Declara__o%'
    )
   , processos_com_eds_assinados AS (
    SELECT edj.id_processo, edj.id_pessoa
    FROM embargos_declaracao_julgados edj
    GROUP BY edj.id_processo, edj.id_pessoa
)
   , peticoes_eds (id_processo, id_peticao, id_julgamento) AS (
    (
        SELECT DISTINCT ON (ed.id_processo) ed.id_processo
                                          , ed.id_processo_evento             AS id_peticao
                                          , julgamento.id_processo_evento     AS id_julgamento
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
                          ilike
                             'Alterado o tipo de peti__o de Embargos de Declara__o%'
                         )
                 )
                )
        WHERE ed.id_processo IN (
            SELECT id_processo FROM processos_com_eds_assinados
        )
          AND ed.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date

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
        ORDER BY ed.id_processo, ed.dt_atualizacao, julgamento.id_processo_evento
    )
    UNION
    (
        SELECT DISTINCT ON (ed.id_processo) ed.id_processo
                                          , ed.id_processo_evento             AS id_peticao
                                          , julgamento.id_processo_evento     AS id_j
                                          , ed.dt_atualizacao                 AS data_ed
                                          , ed.ds_texto_final_externo         AS tx_ed
                                          , julgamento.dt_atualizacao         AS dt_j
                                          , julgamento.ds_texto_final_externo AS tx_j
                                          , julgamento.id_evento              AS mov_julgamento
        FROM peticoes_eds pj
                 INNER JOIN tb_processo_evento ed ON (ed.id_processo = pj.id_processo)
                 LEFT JOIN tb_processo_evento julgamento ON
            (ed.id_processo = julgamento.id_processo
                AND julgamento.id_processo_evento > pj.id_julgamento
                AND julgamento.dt_atualizacao > ed.dt_atualizacao
                AND julgamento.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
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
                          ilike
                             'Alterado o tipo de peti__o de Embargos de Declara__o%'
                         )
                 )
                )
        WHERE ed.id_processo_evento > id_peticao
          AND ed.dt_atualizacao::date <= COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
          AND ed.id_processo = pj.id_processo
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
        ORDER BY ed.id_processo, ed.dt_atualizacao, julgamento.id_processo_evento
    )
)
   , eds_sem_alterada_peticao AS (
    SELECT peticoes_eds.* FROM peticoes_eds
    WHERE peticoes_eds.mov_julgamento IS DISTINCT FROM 50088
)
   , eds_julgados AS (
    SELECT eds_sem_alterada_peticao.id_processo,
           count(eds_sem_alterada_peticao.id_processo) AS numero_julgados,
           eds_sem_alterada_peticao.dt_j AS data_ultimo_julgado
    FROM eds_sem_alterada_peticao
    WHERE eds_sem_alterada_peticao.dt_j::date BETWEEN
              COALESCE(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date
              AND
              COALESCE(:DATA_OPCIONAL_FINAL, CURRENT_DATE)::date
    GROUP BY eds_sem_alterada_peticao.id_processo, eds_sem_alterada_peticao.dt_j
)
   , eds_julgados_por_magistrado AS (
    SELECT edj.id_pessoa,
           SUM(eds_julgados.numero_julgados) AS quantidade_julgado
    FROM processos_com_eds_assinados edj
             INNER JOIN eds_julgados ON (eds_julgados.id_processo = edj.id_processo)
    GROUP BY edj.id_pessoa
)

-- TOTAIS
SELECT
    'TOTAL' AS "Magistrado"
    ,SUM(sentencas_acordos_conhecimento_por_magistrado.acordos_conhecimento)
        AS "Conciliações"
    ,SUM(sentencas_acordos_conhecimento_por_magistrado.sentencas_conhecimento)
        AS "Sentenças de conhecimento proferidas"
    , SUM(sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca)
        AS "Sentenças de conhecimento pendentes"
    , MIN(sentencas_conhecimento_pendentes_por_magistrado.pendente_mais_antigo) - interval '1 milliseconds'
        AS "Sentenças - conclusão mais antiga"
    , SUM(eds_julgados_por_magistrado.quantidade_julgado)
        AS "Embargos Declaratórios Julgados"
    , SUM(eds_pendentes_por_magistrado.pendentes_embargo)
        AS "Embargos Declaratórios Pendentes"
    , MIN(eds_pendentes_por_magistrado.pendente_mais_antigo) - interval '1 milliseconds'
        AS "EDs - conclusão mais antiga"
    , SUM(incidentes_execucao_julgados_por_magistrado.quantidade_julgado)
        AS "Incidentes de Execução julgados"
    , SUM(incidentes_exec_pendentes_por_magistrado.quantidade)
        AS "Incidentes de execução pendentes"
    , MIN(incidentes_exec_pendentes_por_magistrado.pendente_mais_antigo) - interval '1 milliseconds'
        AS "Execução - conclusão mais antiga"
    , '-' AS "Detalhes"
FROM tb_pessoa_magistrado mag
         LEFT JOIN sentencas_conhecimento_pendentes_por_magistrado
                   ON (mag.id =
                       sentencas_conhecimento_pendentes_por_magistrado.id_pessoa_magistrado)
         LEFT JOIN sentencas_acordos_conhecimento_por_magistrado
                   ON (sentencas_acordos_conhecimento_por_magistrado.id_pessoa =
                       mag.id)
         LEFT JOIN incidentes_exec_pendentes_por_magistrado
                   ON (incidentes_exec_pendentes_por_magistrado.id_pessoa_magistrado =
                       mag.id)
         LEFT JOIN incidentes_execucao_julgados_por_magistrado
                   ON (incidentes_execucao_julgados_por_magistrado.id_pessoa =
                       mag.id)
         LEFT JOIN eds_pendentes_por_magistrado
                   ON (eds_pendentes_por_magistrado.id_pessoa_magistrado =
                       mag.id)
         LEFT JOIN eds_julgados_por_magistrado
                   ON (eds_julgados_por_magistrado.id_pessoa = mag.id)
--          INNER JOIN tb_usuario_login ul
--                     ON (ul.id_usuario = mag.id)
UNION ALL
(
    SELECT ul.ds_nome                                                      AS "Magistrado"
         -- T952
         , COALESCE(sentencas_acordos_conhecimento_por_magistrado.acordos_conhecimento, 0)
            AS "Conciliações"
         , COALESCE(sentencas_acordos_conhecimento_por_magistrado.sentencas_conhecimento, 0)
            AS "Sentenças de Conhecimento Proferidas"
         -- T950
        , COALESCE(sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca, 0)
            AS "Sentenças de conhecimento pendentes"
        , sentencas_conhecimento_pendentes_por_magistrado.pendente_mais_antigo
            AS "Sentenças - conclusão mais antiga"
         --T963
        , COALESCE(eds_julgados_por_magistrado.quantidade_julgado, 0)
            AS "Embargos Declaratórios Julgados"
         -- T958
        , COALESCE(eds_pendentes_por_magistrado.pendentes_embargo, 0)
            AS "Embargos Declaratórios Pendentes"
        , eds_pendentes_por_magistrado.pendente_mais_antigo
            AS "EDs - conclusão mais antiga"
        -- T956
        , COALESCE(incidentes_execucao_julgados_por_magistrado.quantidade_julgado, 0)
            AS "Incidentes de Execução julgados"
        -- T954
        , COALESCE(incidentes_exec_pendentes_por_magistrado.quantidade, 0)
        AS "Incidentes de execução pendentes"
        , incidentes_exec_pendentes_por_magistrado.pendente_mais_antigo
        AS "Execução - conclusão mais antiga"
         , '$URL/execucao/T966?MAGISTRADO=' || mag.id
                     || '&DATA_INICIAL_OPCIONAL=' ||
                 to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date, 'mm/dd/yyyy')
                     || '&DATA_OPCIONAL_FINAL=' || to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date, 'mm/dd/yyyy')
        AS "Detalhes"
    FROM tb_pessoa_magistrado mag
             LEFT JOIN sentencas_conhecimento_pendentes_por_magistrado
                       ON (mag.id =
                           sentencas_conhecimento_pendentes_por_magistrado.id_pessoa_magistrado)
             LEFT JOIN sentencas_acordos_conhecimento_por_magistrado
                       ON (sentencas_acordos_conhecimento_por_magistrado.id_pessoa =
                           mag.id)
             LEFT JOIN incidentes_exec_pendentes_por_magistrado
                       ON (incidentes_exec_pendentes_por_magistrado.id_pessoa_magistrado =
                           mag.id)
             LEFT JOIN incidentes_execucao_julgados_por_magistrado
                       ON (incidentes_execucao_julgados_por_magistrado.id_pessoa =
                           mag.id)
             LEFT JOIN eds_pendentes_por_magistrado
                       ON (eds_pendentes_por_magistrado.id_pessoa_magistrado =
                           mag.id)
             LEFT JOIN eds_julgados_por_magistrado
                       ON (eds_julgados_por_magistrado.id_pessoa = mag.id)
             INNER JOIN tb_usuario_login ul
                        ON (ul.id_usuario = mag.id)
    WHERE mag.id = coalesce(:MAGISTRADO, mag.id)
      AND (coalesce(sentencas_conhecimento_pendentes_por_magistrado.pendentes_sentenca, 0)
        + coalesce(sentencas_acordos_conhecimento_por_magistrado.sentencas_conhecimento, 0)
        + coalesce(sentencas_acordos_conhecimento_por_magistrado.acordos_conhecimento, 0)
        + coalesce(incidentes_exec_pendentes_por_magistrado.quantidade, 0)
        + coalesce(incidentes_execucao_julgados_por_magistrado.quantidade_julgado, 0)
        + coalesce(eds_pendentes_por_magistrado.pendentes_embargo, 0)
        + coalesce(eds_julgados_por_magistrado.quantidade_julgado, 0)
              ) > 0
    ORDER BY ul.ds_nome
)