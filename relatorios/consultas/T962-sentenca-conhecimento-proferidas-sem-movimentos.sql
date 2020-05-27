-- [R137698][T962] - Relatório SAO - SENTENÇAS DE CONHECIMENTO sem movimento.

-- explain -- analyze
WITH sentencas_sem_movimentos AS (
select 
    assin.id_pessoa, 
    doc.dt_juntada,
    doc.id_processo,
    concluso.ds_texto_final_interno AS texto_concluso,
    concluso.dt_atualizacao AS data_conclusao
    from tb_processo_documento doc 
    inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
    inner join lateral (
        select pen.dt_atualizacao, pen.ds_texto_final_interno FROM 
        tb_conclusao_magistrado concluso
        INNER JOIN tb_processo_evento pen 
            ON (pen.id_processo_evento = concluso.id_processo_evento 
                and pen.id_processo = doc.id_processo 
                AND pen.id_processo_evento_excludente IS NULL
                and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
                -- esse filtro tem de ser feito depois, pois precisamos verificar se o concluso que antecedeu o documento eh de fato para sentenca
                -- AND pen.ds_texto_final_interno ilike 'Concluso%julgamento%proferir senten_a%')
            )
        where pen.dt_atualizacao < doc.dt_juntada 
        order by pen.dt_atualizacao desc 
        limit 1
    ) concluso on TRUE
    INNER JOIN tb_processo p ON (p.id_processo = doc.id_processo)
    where doc.in_ativo = 'S'
    AND p.id_agrupamento_fase != 5
    AND concluso.ds_texto_final_interno 
    ilike ANY (ARRAY[
            'Concluso%julgamento%' -- proferir senten_a%'
            -- ,
            -- 'Conclusos os autos para decis_o (gen_rica) a%'
    ])
    -- 62	Sentença	S			7007
    AND doc.id_tipo_processo_documento = 62
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    AND
    -- data concluso
    (
        (:CONCLUSO_OU_JUNTADA = 2 
            and doc.dt_juntada :: date between 
                coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('year', current_date))::date
                and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date)
        OR
        (:CONCLUSO_OU_JUNTADA = 1
            AND concluso.dt_atualizacao :: date between 
                coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('year', current_date))::date
                and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date)
    )
    and not exists 
        (
            select 1 from tb_processo_evento mov_julgam
                INNER JOIN tb_evento_processual ev ON 
                    (mov_julgam.id_evento = ev.id_evento_processual)
            WHERE 
                mov_julgam.id_processo_documento = doc.id_processo_documento
                OR (
                    mov_julgam.id_processo = doc.id_processo
                    AND mov_julgam.dt_atualizacao BETWEEN 
                        doc.dt_juntada - ('5 minutes')::interval
                        AND doc.dt_juntada + ('5 minutes')::interval
                    -- 60 - intimacao?
                    AND ev.cd_evento != '60'
                )
        )
      AND NOT EXISTS(
            SELECT 1
            FROM tb_processo_evento pe
                     INNER JOIN tb_evento_processual ev ON
                (pe.id_evento = ev.id_evento_processual)
            WHERE doc.id_processo = pe.id_processo
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
                )
        )
)
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
         'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
         ||cj.ds_classe_judicial_sigla||' '
         ||p.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade",
    ul.ds_nome AS "Magistrado",
    REGEXP_REPLACE(sentencas_sem_movimentos.texto_concluso,
    'Conclusos os autos para julgamento (.*) a (.*)'
    ,'\1') AS "Conclusos os autos para julgamento",
    sentencas_sem_movimentos.data_conclusao AS "Data da Conclusão",
    sentencas_sem_movimentos.dt_juntada AS "Data da Juntada",
    pt.nm_tarefa as "Tarefa Atual",
    (select COALESCE(string_agg(prioridade.ds_prioridade::character varying, ', '), '-')
        from 
        tb_proc_prioridde_processo tabela_ligacao 
        inner join tb_prioridade_processo prioridade 
            on (tabela_ligacao.id_prioridade_processo = prioridade.id_prioridade_processo)
        where 
        tabela_ligacao.id_processo_trf = p.id_processo
    ) AS "Prioridades"
FROM sentencas_sem_movimentos 
    INNER JOIN tb_usuario_login ul on (ul.id_usuario = sentencas_sem_movimentos.id_pessoa)
    INNER JOIN tb_processo p ON (p.id_processo = sentencas_sem_movimentos.id_processo)
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
    inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo    
ORDER BY "Unidade", ul.ds_nome, sentencas_sem_movimentos.dt_juntada
