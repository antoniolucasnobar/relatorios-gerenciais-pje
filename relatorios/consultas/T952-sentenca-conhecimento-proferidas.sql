-- R136873 - Relatório SAO - SENTENÇAS DE CONHECIMENTO PROFERIDAS.
-- Conclusos os autos para julgamento Proferir sentença a MARCELE CRUZ LANOT ANTONIAZZI
-- codigo 51

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
SELECT ul.ds_nome AS "Magistrado", 
-- conclusos_por_magistrado.total,
    conclusos_por_magistrado.proferidas_sentenca AS "Proferidas"
    ,
    '$URL/execucao/T953?MAGISTRADO='||conclusos_por_magistrado.id_pessoa
    ||'&DATA_INICIAL='||to_char(:DATA_INICIAL::date,'mm/dd/yyyy')
    ||'&DATA_FINAL='||to_char(:DATA_FINAL::date,'mm/dd/yyyy')
    ||'&texto='||conclusos_por_magistrado.proferidas_sentenca as "Ver Proferidas"
FROM  (
    SELECT  proferidas.id_pessoa, 
        COUNT(proferidas.id_pessoa) AS proferidas_sentenca
    FROM proferidas
    GROUP BY proferidas.id_pessoa
) conclusos_por_magistrado  
INNER JOIN tb_usuario_login ul ON (ul.id_usuario = conclusos_por_magistrado.id_pessoa)
ORDER BY ul.ds_nome
