-- R136873 - Relatório SAO - SENTENÇAS DE CONHECIMENTO proferidas.

-- explain analyze
WITH proferidas AS (
    select 
    -- ul.ds_nome, 
    assin.id_pessoa, 
    doc.dt_juntada,
    doc.id_processo
    from tb_processo_documento doc 
    inner join tb_proc_doc_bin_pess_assin assin on (doc.id_processo_documento_bin = assin.id_processo_documento_bin)
    -- inner join tb_usuario_login ul on (ul.id_usuario = assin.id_pessoa)
    -- inner join pje.tb_tipo_processo_documento tipo using (id_tipo_processo_documento)
    inner join lateral (
        select concluso.*, pen.ds_texto_final_interno FROM 
        tb_conclusao_magistrado concluso
        INNER JOIN tb_processo_evento pen 
            ON (pen.id_processo_evento = concluso.id_processo_evento 
                and pen.id_processo = doc.id_processo 
                AND pen.id_processo_evento_excludente IS NULL
                and pen.id_evento = 51 -- esse é o codigo do movimento. se esse id mudar tem de ir na tb_evento_processual.cd_evento
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
    and doc.dt_juntada :: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
    and concluso.ds_texto_final_interno ilike 'Concluso%proferir senten_a%'
    --  nao pode ter "Extinta a execução ou o cumprimento da sentença por ..." lancado junto com a sentenca
    and not exists (
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
    proferidas.dt_juntada AS "Proferida em"

FROM proferidas 
    INNER JOIN tb_usuario_login ul on (ul.id_usuario = proferidas.id_pessoa)
    INNER JOIN tb_processo p ON (p.id_processo = proferidas.id_processo)
    inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
    inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
ORDER BY ul.ds_nome, proferidas.dt_juntada
