-- R136873 - Relatório SAO - SENTENÇAS DE CONHECIMENTO proferidas.

-- explain analyze
WITH sentencas_conhecimento_proferidas AS  (
select 
    assin.id_pessoa, 
    doc.dt_juntada,
    doc.id_processo,
    doc.id_tipo_processo_documento
    from tb_processo_documento doc 
    inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
    inner join lateral (
        select pen.ds_texto_final_interno FROM 
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
    where doc.in_ativo = 'S'
    -- 62 - sentenca,
    -- 64 - decisao
    AND doc.id_tipo_processo_documento IN (62, 64)
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    -- and tipo.cd_documento = '7007'
    and doc.dt_juntada :: date between coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and (coalesce(:DATA_FINAL_OPCIONAL, current_date))::date
    and concluso.ds_texto_final_interno 
        ilike ANY (ARRAY[
                'Concluso%julgamento%proferir senten_a%',
                'Conclusos os autos para decis_o (gen_rica) a%'
        ])
    --  nao pode ter "Extinta a execução ou o cumprimento da sentença por ..." lancado junto com a sentenca
    and not exists 
        (
            select 1 from tb_processo_evento extinta_execucao
            where extinta_execucao.id_processo = doc.id_processo and 
            date(doc.dt_juntada) = date(extinta_execucao.dt_atualizacao)
            AND extinta_execucao.id_evento = 196
        )
)
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
         'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='
         ||cj.ds_classe_judicial_sigla||' '
         ||p.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade",
    ul.ds_nome AS "Magistrado",
    sentencas_conhecimento_proferidas.dt_juntada AS "Proferida em",
    pt.nm_tarefa as "Tarefa Atual",
    (select COALESCE(string_agg(prioridade.ds_prioridade::character varying, ', '), '-')
        from 
        tb_proc_prioridde_processo tabela_ligacao 
        inner join tb_prioridade_processo prioridade 
            on (tabela_ligacao.id_prioridade_processo = prioridade.id_prioridade_processo)
        where 
        tabela_ligacao.id_processo_trf = p.id_processo
    ) AS "Prioridades"
FROM sentencas_conhecimento_proferidas 
    INNER JOIN tb_usuario_login ul on (ul.id_usuario = sentencas_conhecimento_proferidas.id_pessoa)
    INNER JOIN tb_processo p ON (p.id_processo = sentencas_conhecimento_proferidas.id_processo)
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
    inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
WHERE
    CASE
        -- Só Sentenças
        WHEN (:SENTENCA_OU_ACORDO = 1)
        THEN 
            sentencas_conhecimento_proferidas.id_tipo_processo_documento = 62
            AND NOT EXISTS (
                SELECT 1 FROM tb_processo_evento acordo
                WHERE acordo.id_processo = sentencas_conhecimento_proferidas.id_processo
                  AND acordo.dt_atualizacao::date = sentencas_conhecimento_proferidas.dt_juntada::date
                  -- 377, Homologado o acordo em execução ou em cumprimento de sentença (valor do acordo: 1000,00)
                  -- 466, Homologada a transação
                  AND acordo.id_evento IN (377, 466)
            )
        -- Só Acordos
        WHEN (:SENTENCA_OU_ACORDO = 2)
        THEN EXISTS (
                SELECT 1 FROM tb_processo_evento acordo
                WHERE acordo.id_processo = sentencas_conhecimento_proferidas.id_processo
                  AND acordo.dt_atualizacao::date = sentencas_conhecimento_proferidas.dt_juntada::date
                  -- 377, Homologado o acordo em execução ou em cumprimento de sentença (valor do acordo: 1000,00)
                  -- 466, Homologada a transação
                  AND acordo.id_evento IN (377, 466)
            )
        -- Todos
        ELSE FALSE
    END
ORDER BY ul.ds_nome, sentencas_conhecimento_proferidas.dt_juntada
