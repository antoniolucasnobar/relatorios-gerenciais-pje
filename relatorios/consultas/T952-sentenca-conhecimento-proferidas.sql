-- R136873 - Relatório SAO - SENTENÇAS DE CONHECIMENTO PROFERIDAS.

WITH sentencas_conhecimento_proferidas AS (
select 
    assin.id_pessoa, 
    doc.dt_juntada,
    doc.id_processo
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
                -- AND pen.ds_texto_final_interno ilike 'Concluso%proferir senten_a%')
            )
        where pen.dt_atualizacao < doc.dt_juntada 
        order by pen.dt_atualizacao desc 
        limit 1
    ) concluso on TRUE
    where doc.in_ativo = 'S'
    AND doc.id_tipo_processo_documento = 62
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    -- and tipo.cd_documento = '7007'
    and doc.dt_juntada :: date between coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and (coalesce(:DATA_FINAL_OPCIONAL, current_date))::date
    and concluso.ds_texto_final_interno ilike 'Concluso%proferir senten_a%'
    --  nao pode ter "Extinta a execução ou o cumprimento da sentença por ..." lancado junto com a sentenca
    and not exists (
                        select 1 from tb_processo_evento extinta_execucao
                        where extinta_execucao.id_processo = doc.id_processo and 
                        date(doc.dt_juntada) = date(extinta_execucao.dt_atualizacao)
                        AND extinta_execucao.id_evento = 196
 				)
)
SELECT ul.ds_nome AS "Magistrado", 
    sentencas_conhecimento.proferidas_sentenca AS "Proferidas"
    ,
    '$URL/execucao/T953?MAGISTRADO='||sentencas_conhecimento.id_pessoa
    ||'&DATA_INICIAL_OPCIONAL='||to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date,'mm/dd/yyyy')
    ||'&DATA_FINAL_OPCIONAL='||to_char(coalesce(:DATA_FINAL_OPCIONAL, current_date)::date,'mm/dd/yyyy')
    ||'&texto='||sentencas_conhecimento.proferidas_sentenca as "Ver Proferidas"
FROM  (
    SELECT  sentencas_conhecimento_proferidas.id_pessoa, 
        COUNT(sentencas_conhecimento_proferidas.id_pessoa) AS proferidas_sentenca
    FROM sentencas_conhecimento_proferidas
    GROUP BY sentencas_conhecimento_proferidas.id_pessoa
) sentencas_conhecimento  
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = sentencas_conhecimento.id_pessoa)
ORDER BY ul.ds_nome
