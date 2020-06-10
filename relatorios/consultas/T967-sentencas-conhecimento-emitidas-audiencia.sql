-- [R138790][T967] - Relatório SAO - SENTENÇAS DE CONHECIMENTO PROFERIDAS em audiencia.
-- baseado no T952
-- EXPLAIN
WITH sentencas_conhecimento_proferidas AS (
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
    AND doc.id_tipo_processo_documento IN (
--     62, 64,
    93)
      -- nao tem no T952! especifico desse, pois nao deve contar as audiencia de julgamento e conciliacao
    AND NOT EXISTS
        (
            SELECT 1 FROM tb_processo_audiencia pa
                INNER JOIN tb_tipo_audiencia tta on pa.id_tipo_audiencia = tta.id_tipo_audiencia
            WHERE pa.id_processo_documento = doc.id_processo_documento
            AND tta.cd_sigla_tipo_audiencia IN ('24')
            -- 4,Julgamento,S,24
            -- jeferson falou para contar so Julgamento
            -- 1,Conciliação em Conhecimento,S,17
            -- 2,Conciliação em Execução,S,20
            -- 13,Mediação (fase de conhecimento),N,7524
            -- 14,Mediação (fase de execução),N,7525
        )
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    and doc.dt_juntada :: date between coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
    --  nao pode ter "Extinta a execução ou o cumprimento da sentença por ..." lancado junto com a sentenca
      AND NOT EXISTS
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
            ) AS sentencas_conhecimento
    FROM sentencas_conhecimento_proferidas
    GROUP BY sentencas_conhecimento_proferidas.id_pessoa
)
SELECT 
    'TOTAL' AS "Magistrado"
    ,SUM(sentencas_acordos_conhecimento_por_magistrado.sentencas_conhecimento) AS "Sentenças de conhecimento proferidas em audiência"
    ,'-' as "Ver Sentenças de conhecimento proferidas em audiência"
FROM sentencas_acordos_conhecimento_por_magistrado
UNION ALL
(
    SELECT ul.ds_nome AS "Magistrado"
        , sentencas_acordos_conhecimento_por_magistrado.sentencas_conhecimento  AS "Sentenças"
        , '$URL/execucao/T953?MAGISTRADO='||sentencas_acordos_conhecimento_por_magistrado.id_pessoa
        ||'&SENTENCA_OU_ACORDO=1'
        ||'&DATA_INICIAL_OPCIONAL='||to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date,'mm/dd/yyyy')
        ||'&DATA_OPCIONAL_FINAL='||to_char(coalesce(:DATA_OPCIONAL_FINAL, current_date)::date,'mm/dd/yyyy')
        ||'&SOMENTE_AUDIENCIA=93'
        ||'&texto='||sentencas_acordos_conhecimento_por_magistrado.sentencas_conhecimento as "Ver Sentenças"
    FROM sentencas_acordos_conhecimento_por_magistrado
        INNER JOIN tb_usuario_login ul ON (ul.id_usuario = sentencas_acordos_conhecimento_por_magistrado.id_pessoa)
    WHERE sentencas_acordos_conhecimento_por_magistrado.sentencas_conhecimento > 0
    ORDER BY ul.ds_nome
)





