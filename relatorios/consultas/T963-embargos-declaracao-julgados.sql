-- [R136875][T963] - EMBARGOS DECLARATÓRIOS JULGADOS
-- 198 - Acolhidos os Embargos de Declaração de #{nome da parte}  
-- 871 - Acolhidos em parte os Embargos de Declaração de #{nome da parte}  
-- 200 - Não acolhidos os Embargos de Declaração de #{nome da parte}  
-- 235 - Não conhecido(s) o(s) #{nome do recurso} / #{nome do conflito} de #{nome da parte} / #{nome da pessoa} 
WITH
tipo_documento_sentenca AS (
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
        select pen.ds_texto_final_interno FROM 
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
    AND doc.id_tipo_processo_documento = (SELECT id_tipo_processo_documento FROM tipo_documento_sentenca)
    AND assin.id_pessoa = coalesce(:MAGISTRADO, assin.id_pessoa)
    and doc.dt_juntada :: date between coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date and (coalesce(:DATA_OPCIONAL_FINAL, current_date))::date
    and concluso.ds_texto_final_interno ilike 'Conclusos os autos para % dos Embargos de Declara__o%'
    AND EXISTS (
        SELECT 1 FROM 
            tb_processo_evento pen 
        WHERE 
            pen.id_processo = doc.id_processo 
            AND pen.id_processo_evento_excludente IS NULL
            and pen.id_evento IN (
                SELECT id_evento_processual FROM movimentos_embargos_declaracao_julgados
            )
            AND date(doc.dt_juntada) <= date(pen.dt_atualizacao)
            -- AND  pen.ds_texto_final_interno ilike '%Embargos de Declara__o%' 
    )
)
, embargo_declaracao_julgado AS (
    SELECT  embargos_declaracao_julgados.id_pessoa, 
        COUNT(embargos_declaracao_julgados.id_pessoa) AS quantidade_julgado
    FROM embargos_declaracao_julgados
    GROUP BY embargos_declaracao_julgados.id_pessoa
)
SELECT 
    'TOTAL' AS "Magistrado", 
    SUM(embargo_declaracao_julgado.quantidade_julgado) AS "EDs Julgados", 
    '-' as "Ver EDs Julgados"
FROM embargo_declaracao_julgado
UNION ALL
(
    SELECT ul.ds_nome AS "Magistrado", 
        embargo_declaracao_julgado.quantidade_julgado AS "EDs Julgados"
        ,
        '$URL/execucao/T961?MAGISTRADO='||embargo_declaracao_julgado.id_pessoa
        ||'&DATA_INICIAL_OPCIONAL='||to_char(coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('month', current_date))::date,'mm/dd/yyyy')
        ||'&DATA_OPCIONAL_FINAL='||to_char((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date,'mm/dd/yyyy')
        ||'&texto='||embargo_declaracao_julgado.quantidade_julgado as "Ver EDs Julgados"
    FROM embargo_declaracao_julgado  
    INNER JOIN tb_usuario_login ul ON (ul.id_usuario = embargo_declaracao_julgado.id_pessoa)
    ORDER BY ul.ds_nome
) 

